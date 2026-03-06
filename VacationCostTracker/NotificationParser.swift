import Foundation
import SwiftData
import UserNotifications

// MARK: - Parsed Transaction

struct ParsedTransaction {
    let merchant: String
    let amount: Double
    let currency: Currency
}

// MARK: - Notification Parser

/// Parses bank push notification bodies to extract merchant + amount.
/// Works entirely on-device — no network required.
///
/// To enable automatic expense logging from bank notifications:
///   1. Enable push notification permissions at app launch (already handled in VacationCostTrackerApp)
///   2. The user must allow notifications from their banking apps
///   3. For fully automatic interception (before the notification appears), a
///      UNNotificationServiceExtension target is needed — see setup notes below.
///
/// Without the extension, this parser runs when the app is foregrounded and the
/// user taps a bank notification — still very useful for manual review.
///
/// == UNNotificationServiceExtension Setup (one-time, optional) ==
/// 1. In Xcode: File > New > Target > Notification Service Extension
/// 2. Name it "NotificationExtension"
/// 3. In the extension's NotificationService.swift, call NotificationParser.parse()
/// 4. Add App Groups capability to both targets (group.com.yourname.VacationCostTracker)
/// 5. Use UserDefaults(suiteName:) to share parsed transactions back to the main app

enum NotificationParser {

    // ── Regex patterns ────────────────────────────────────────────────────────
    // Each pattern captures (amount, merchant) or (merchant, amount).
    // Group indices are 1-based.

    private struct Pattern {
        let regex: String
        let amountGroup: Int
        let merchantGroup: Int
        let currencyHint: Currency?  // nil = infer from symbol
    }

    private static let patterns: [Pattern] = [
        // Chase: "A charge of $4.50 was made at Blue Bottle Coffee"
        Pattern(regex: #"charge of \$([0-9,]+\.?\d*) was made at (.+?)(?:\.|$)"#, amountGroup: 1, merchantGroup: 2, currencyHint: .usd),
        // Apple Card: "You spent $4.50 at Blue Bottle Coffee"
        Pattern(regex: #"You spent \$([0-9,]+\.?\d*) at (.+?)(?:\.|$)"#, amountGroup: 1, merchantGroup: 2, currencyHint: .usd),
        // Apple Card EUR: "You spent €4.50 at Blue Bottle Coffee"
        Pattern(regex: #"You spent €([0-9,]+\.?\d*) at (.+?)(?:\.|$)"#, amountGroup: 1, merchantGroup: 2, currencyHint: .eur),
        // Bank of America: "BofA: $4.50 at Blue Bottle Coffee"
        Pattern(regex: #"BofA[^:]*: \$([0-9,]+\.?\d*) at (.+?)(?:\.|$)"#, amountGroup: 1, merchantGroup: 2, currencyHint: .usd),
        // Amex: "was used for $4.50 at Blue Bottle Coffee"
        Pattern(regex: #"was used for \$([0-9,]+\.?\d*) at (.+?)(?:\.|$)"#, amountGroup: 1, merchantGroup: 2, currencyHint: .usd),
        // Citi: "Transaction of $4.50 at Blue Bottle Coffee"
        Pattern(regex: #"Transaction of \$([0-9,]+\.?\d*) at (.+?)(?:\.|$)"#, amountGroup: 1, merchantGroup: 2, currencyHint: .usd),
        // Revolut: "You paid €4.50 at Blue Bottle Coffee"
        Pattern(regex: #"You paid €([0-9,]+\.?\d*) at (.+?)(?:\.|$)"#, amountGroup: 1, merchantGroup: 2, currencyHint: .eur),
        // Monzo / Starling: "You spent £4.50 at Blue Bottle Coffee"
        Pattern(regex: #"You spent £([0-9,]+\.?\d*) at (.+?)(?:\.|$)"#, amountGroup: 1, merchantGroup: 2, currencyHint: .usd),
        // N26 / European: "Payment of €4.50 to Blue Bottle Coffee"
        Pattern(regex: #"Payment of €([0-9,]+\.?\d*) to (.+?)(?:\.|$)"#, amountGroup: 1, merchantGroup: 2, currencyHint: .eur),
        // Wise: "You sent €4.50 to Blue Bottle Coffee"
        Pattern(regex: #"You sent €([0-9,]+\.?\d*) to (.+?)(?:\.|$)"#, amountGroup: 1, merchantGroup: 2, currencyHint: .eur),
        // Generic USD fallback: "$X.XX at Merchant"
        Pattern(regex: #"\$([0-9,]+\.?\d*) at (.+?)(?:\.|$)"#, amountGroup: 1, merchantGroup: 2, currencyHint: .usd),
        // Generic EUR fallback: "€X.XX at Merchant"
        Pattern(regex: #"€([0-9,]+\.?\d*) at (.+?)(?:\.|$)"#, amountGroup: 1, merchantGroup: 2, currencyHint: .eur),
    ]

    // ── Parse ─────────────────────────────────────────────────────────────────

    /// Attempts to extract a merchant name and amount from a bank notification body.
    /// Returns nil if no pattern matches.
    static func parse(_ body: String) -> ParsedTransaction? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(
                pattern: pattern.regex,
                options: [.caseInsensitive]
            ) else { continue }

            let ns = body as NSString
            let range = NSRange(location: 0, length: ns.length)
            guard let match = regex.firstMatch(in: body, range: range) else { continue }

            let amountRange   = Range(match.range(at: pattern.amountGroup),   in: body)
            let merchantRange = Range(match.range(at: pattern.merchantGroup), in: body)
            guard let amountRange, let merchantRange else { continue }

            let amountStr = String(body[amountRange])
                .replacingOccurrences(of: ",", with: "")
                .trimmingCharacters(in: .whitespaces)
            guard let amount = Double(amountStr), amount > 0 else { continue }

            let merchant = String(body[merchantRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !merchant.isEmpty else { continue }

            let currency = pattern.currencyHint ?? .usd
            return ParsedTransaction(merchant: merchant, amount: amount, currency: currency)
        }
        return nil
    }

    // ── Attempt auto-log ──────────────────────────────────────────────────────

    /// Parses a notification and, if it matches an active trip, saves it as an Expense.
    /// Returns true if an expense was created.
    @discardableResult
    @MainActor
    static func tryLog(
        notificationBody: String,
        modelContext: ModelContext
    ) -> Bool {
        guard let parsed = parse(notificationBody) else { return false }

        let allTrips = (try? modelContext.fetch(FetchDescriptor<Trip>())) ?? []
        let today = Date()
        guard let matchingTrip = allTrips.first(where: { trip in
            today >= Calendar.current.startOfDay(for: trip.startDate) && today <= trip.endDate
        }) else { return false }

        // Deduplicate: same merchant + amount within the last 10 minutes
        let tenMinutesAgo = today.addingTimeInterval(-600)
        let allExpenses = (try? modelContext.fetch(FetchDescriptor<Expense>())) ?? []
        let isDuplicate = allExpenses.contains {
            $0.merchant == parsed.merchant &&
            abs($0.amount - parsed.amount) < 0.01 &&
            $0.createdAt >= tenMinutesAgo
        }
        guard !isDuplicate else { return false }

        let expense = Expense(
            amount: parsed.amount,
            originalCurrency: parsed.currency,
            category: ReceiptProcessor.detectCategory(from: [parsed.merchant]),
            merchant: parsed.merchant,
            date: today,
            source: .notification
        )
        modelContext.insert(expense)
        matchingTrip.expenses.append(expense)
        try? modelContext.save()
        HapticManager.success()
        return true
    }
}
