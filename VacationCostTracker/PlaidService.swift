import Foundation
import SwiftData

// MARK: - Plaid Transaction DTO

struct PlaidTransaction: Decodable {
    let transactionId: String
    let merchantName: String?
    let name: String
    let amount: Double
    let isoCurrencyCode: String?
    let date: String            // "YYYY-MM-DD" from Plaid
    let personalFinanceCategory: PersonalFinanceCategory?
    let location: Location?
    let institutionName: String?

    struct PersonalFinanceCategory: Decodable {
        let primary: String?
        let detailed: String?
    }

    struct Location: Decodable {
        let city: String?
        let region: String?
        let country: String?
    }

    enum CodingKeys: String, CodingKey {
        case transactionId           = "transaction_id"
        case merchantName            = "merchant_name"
        case name
        case amount
        case isoCurrencyCode         = "iso_currency_code"
        case date
        case personalFinanceCategory = "personal_finance_category"
        case location
        case institutionName         = "institution_name"
    }
}

// MARK: - Plaid Service

/// Communicates with the VacationTracker backend (which proxies Plaid).
/// The access token never touches the iOS app — it's stored server-side only.
@Observable
final class PlaidService {

    // ── Configuration ──────────────────────────────────────────────────────────
    /// Change this to your server URL before building for production.
    /// For local development, make sure the backend is running: `cd backend && npm start`
    static let backendURL = "https://deandrea-unplotting-pithily.ngrok-free.dev"

    // ── State ──────────────────────────────────────────────────────────────────
    var isSyncing = false
    var lastSyncDate: Date? = UserDefaults.standard.object(forKey: "plaidLastSync") as? Date
    var syncError: String?

    // ── Shared session with 10-second timeout ─────────────────────────────────
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 10
        config.timeoutIntervalForResource = 10
        return URLSession(configuration: config)
    }()

    // ── Shared request builder (adds ngrok bypass header) ─────────────────────
    private static func makeRequest(_ url: URL, method: String = "GET") -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        return req
    }

    // ── Link token ─────────────────────────────────────────────────────────────
    func createLinkToken() async throws -> String {
        let url = URL(string: "\(Self.backendURL)/plaid/create-link-token")!
        var req = Self.makeRequest(url, method: "POST")

        print("PlaidService: fetching link token from \(url)")
        let (data, response) = try await Self.session.data(for: req)
        print("PlaidService: got response \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw PlaidError.serverError("create-link-token failed")
        }
        let body = try JSONDecoder().decode([String: String].self, from: data)
        guard let token = body["link_token"] else {
            throw PlaidError.serverError("No link_token in response")
        }
        return token
    }

    // ── Token exchange ─────────────────────────────────────────────────────────
    func exchangeToken(_ publicToken: String, institutionName: String) async throws -> (itemId: String, name: String) {
        let url = URL(string: "\(Self.backendURL)/plaid/exchange-token")!
        var req = Self.makeRequest(url, method: "POST")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "public_token": publicToken,
            "institution_name": institutionName,
        ])

        let (data, response) = try await Self.session.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw PlaidError.serverError("exchange-token failed")
        }
        struct ExchangeResponse: Decodable {
            let itemId: String
            let institutionName: String?
            enum CodingKeys: String, CodingKey {
                case itemId = "item_id"
                case institutionName = "institution_name"
            }
        }
        let body = try JSONDecoder().decode(ExchangeResponse.self, from: data)
        return (body.itemId, body.institutionName ?? institutionName)
    }

    // ── Remove linked bank ─────────────────────────────────────────────────────
    func removeItem(_ itemId: String) async throws {
        let url = URL(string: "\(Self.backendURL)/plaid/items/\(itemId)")!
        let req = Self.makeRequest(url, method: "DELETE")
        let (_, response) = try await Self.session.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw PlaidError.serverError("remove item failed")
        }
    }

    // ── Sync & import transactions ─────────────────────────────────────────────
    /// Fetches new transactions from the backend and saves them to SwiftData.
    /// Automatically matches each transaction to a trip by date range.
    @MainActor
    func sync(modelContext: ModelContext) async {
        guard !isSyncing else { return }
        isSyncing = true
        syncError = nil
        defer { isSyncing = false }

        do {
            let url = URL(string: "\(Self.backendURL)/plaid/sync")!
            let (data, response) = try await Self.session.data(for: Self.makeRequest(url))
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw PlaidError.serverError("sync failed")
            }

            struct SyncResponse: Decodable {
                let transactions: [PlaidTransaction]
            }
            let decoded = try JSONDecoder().decode(SyncResponse.self, from: data)
            let imported = importTransactions(decoded.transactions, into: modelContext)

            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "plaidLastSync")
            if imported > 0 {
                print("PlaidService: imported \(imported) new expense(s)")
            }
        } catch {
            syncError = error.localizedDescription
            print("PlaidService sync error: \(error)")
        }
    }

    // ── Register device token ──────────────────────────────────────────────────
    func registerDeviceToken(_ tokenData: Data) {
        let tokenString = tokenData.map { String(format: "%02x", $0) }.joined()
        let url = URL(string: "\(Self.backendURL)/device-token")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["token": tokenString])
        URLSession.shared.dataTask(with: req).resume()
    }

    // MARK: - Private helpers

    private func importTransactions(_ transactions: [PlaidTransaction], into context: ModelContext) -> Int {
        // Fetch existing data
        let allTrips    = (try? context.fetch(FetchDescriptor<Trip>())) ?? []
        let allExpenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        let existingPlaidIds = Set(allExpenses.compactMap(\.plaidTransactionId))

        let dateParser = DateFormatter()
        dateParser.dateFormat = "yyyy-MM-dd"
        dateParser.locale = Locale(identifier: "en_US_POSIX")

        var importCount = 0

        for tx in transactions {
            // Skip duplicates
            guard !existingPlaidIds.contains(tx.transactionId) else { continue }

            // Parse date
            guard let txDate = dateParser.date(from: tx.date) else { continue }

            // Match to a trip by date range
            guard let matchingTrip = allTrips.first(where: { trip in
                txDate >= Calendar.current.startOfDay(for: trip.startDate) &&
                txDate <= trip.endDate
            }) else { continue }

            // Build expense
            let currency: Currency = (tx.isoCurrencyCode?.uppercased() == "EUR") ? .eur : .usd
            let expense = Expense(
                amount: abs(tx.amount),
                originalCurrency: currency,
                category: ExpenseCategory.infer(from: tx.merchantName ?? tx.name),
                merchant: tx.merchantName ?? tx.name,
                notes: "",
                date: txDate,
                source: .plaid,
                plaidTransactionId: tx.transactionId,
                purchaseCity: tx.location?.city,
                purchaseCountry: tx.location?.country
            )
            context.insert(expense)

            // Try to place in the most specific sub-trip destination first.
            // Falls back to the parent trip (pre-trip / general) if no sub-trip matches.
            if let subTrip = bestSubTrip(for: txDate, city: tx.location?.city, within: matchingTrip) {
                subTrip.expenses.append(expense)
            } else {
                matchingTrip.expenses.append(expense)
            }
            importCount += 1
        }

        if importCount > 0 {
            try? context.save()
        }
        return importCount
    }

    /// Returns the best sub-trip destination for a transaction, or nil to use the parent trip.
    ///
    /// Priority:
    ///   1. Sub-trips whose city name matches the Plaid transaction city (if provided)
    ///      — if Plaid gives us a city but NO destination matches, returns nil (→ Pre-Trip)
    ///        so a home purchase during a trip's date range is never forced into a foreign city.
    ///   2. When Plaid has no city data, pick the shortest-duration sub-trip by date range
    ///      (shortest = most specific destination).
    private func bestSubTrip(for txDate: Date, city txCity: String?, within trip: Trip) -> SubTrip? {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: txDate)

        // All sub-trips whose date window contains this transaction
        let candidates = trip.subTrips.filter { sub in
            dayStart >= cal.startOfDay(for: sub.startDate) && txDate <= sub.endDate
        }
        guard !candidates.isEmpty else { return nil }

        // If Plaid gave us a city, only assign to a destination whose city matches.
        // A city mismatch (e.g. bought in San Francisco while trip destination is Paris)
        // returns nil so the expense lands in Pre-Trip & General instead.
        if let rawCity = txCity, !rawCity.isEmpty {
            let txCityLower = rawCity.lowercased()
            return candidates.first(where: { sub in
                let subCity = sub.city.lowercased()
                return subCity.contains(txCityLower) || txCityLower.contains(subCity)
            })
        }

        // No location signal from Plaid — pick the shortest-duration overlapping sub-trip
        return candidates.min {
            $0.endDate.timeIntervalSince($0.startDate) < $1.endDate.timeIntervalSince($1.startDate)
        }
    }

}

// MARK: - Errors

enum PlaidError: LocalizedError {
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .serverError(let msg): return "Server error: \(msg)"
        }
    }
}
