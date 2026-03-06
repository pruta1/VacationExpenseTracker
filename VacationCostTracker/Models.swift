import Foundation
import SwiftData
import SwiftUI

// MARK: - Expense Source

enum ExpenseSource: String, CaseIterable, Codable {
    case manual         = "manual"          // Added by hand in the app
    case plaid          = "plaid"           // Auto-imported via Plaid bank connection
    case receiptScan    = "receipt_scan"    // Captured via receipt photo scanner
    case notification   = "notification"   // Parsed from a bank push notification
    case shortcut       = "shortcut"        // Logged via Apple Shortcuts

    var displayName: String {
        switch self {
        case .manual:       return "Manual"
        case .plaid:        return "Bank (Auto)"
        case .receiptScan:  return "Receipt Scan"
        case .notification: return "Notification"
        case .shortcut:     return "Shortcut"
        }
    }

    var symbolName: String {
        switch self {
        case .manual:       return "pencil"
        case .plaid:        return "building.columns.fill"
        case .receiptScan:  return "doc.viewfinder.fill"
        case .notification: return "bell.fill"
        case .shortcut:     return "shortcuts"
        }
    }
}

// MARK: - Expense Category

enum ExpenseCategory: String, CaseIterable, Codable, Identifiable {
    case transportation
    case food
    case accommodation
    case events
    case shopping
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .transportation:   return "Transportation"
        case .food:             return "Food & Drink"
        case .accommodation:    return "Accommodation"
        case .events:           return "Events & Activities"
        case .shopping:         return "Shopping"
        case .other:            return "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .transportation:   return "car.fill"
        case .food:             return "fork.knife"
        case .accommodation:    return "bed.double.fill"
        case .events:           return "theatermasks.fill"
        case .shopping:         return "bag.fill"
        case .other:            return "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .transportation:   return .blue
        case .food:             return .orange
        case .accommodation:    return .purple
        case .events:           return .teal
        case .shopping:         return .pink
        case .other:            return Color(.systemGray2)
        }
    }

    /// Infer a category from a merchant/payee name.
    /// Used for Plaid imports, receipt scans, and manual entry auto-suggest.
    static func infer(from merchant: String) -> ExpenseCategory {
        let m = merchant.lowercased()

        let transportTerms = [
            "uber", "lyft", "taxi", "cab ", "rideshare",
            "airline", "airways", "air ", "delta", "united", "american air",
            "southwest", "jetblue", "ryanair", "easyjet", "lufthansa", "emirates",
            "british airways", "frontier", "spirit air",
            "airport", "flight", "amtrak", "train", "subway", "metro",
            "bus ", "transit", "transport", "greyhound",
            "car rental", "enterprise", "hertz", "avis", "sixt", "budget rent",
            "ferry", "cruise", "parking", "toll ",
            "shell", "bp ", "chevron", "exxon", "mobil", "petrol", "gasoline",
        ]
        let foodTerms = [
            "mcdonald", "starbucks", "kfc", "burger king", "burger", "pizza",
            "chipotle", "taco bell", "taco ", "domino", "wendy's", "wendy",
            "dunkin", "shake shack", "five guys", "popeyes", "sonic drive",
            "dairy queen", "panera", "chick-fil", "in-n-out", "whataburger",
            "restaurant", "cafe", "café", "coffee", "bistro",
            "bar ", " bar", "pub ", " pub", "tavern", "grill", "eatery",
            "diner", "brasserie", "kitchen", "bakery",
            "sushi", "ramen", "noodle", "steakhouse", "seafood",
            "doordash", "grubhub", "uber eats", "ubereats", "deliveroo",
            "whole foods", "trader joe", "safeway", "kroger", "grocery",
            "supermarket", "food", "snack",
        ]
        let accommodationTerms = [
            "airbnb", "vrbo", "hotel", "marriott", "hilton", "hyatt", "sheraton",
            "westin", "ritz", "holiday inn", "best western", "motel",
            "inn ", "resort", "hostel", "lodging", "accommodation", "suites",
            "booking.com", "expedia",
        ]
        let eventTerms = [
            "museum", "theater", "theatre", "cinema", "concert", "festival",
            "disneyland", "disney", "universal studio", "theme park",
            "zoo", "aquarium", "gallery", "exhibition", "tour", "tours",
            "ticket", "ticketmaster", "attraction", "adventure",
            "bowling", "escape room", "spa", "gym", "fitness",
        ]
        let shoppingTerms = [
            "amazon", "walmart", "target", "costco", "ikea", "best buy",
            "apple store", "h&m", "zara", "uniqlo", "gap ", "nike", "adidas",
            "shopping", "mall", "boutique", "outlet", "souvenir",
            "market", "duty free", "pharmacy", "cvs", "walgreens", "boots",
        ]

        for t in transportTerms    where m.contains(t) { return .transportation }
        for t in foodTerms         where m.contains(t) { return .food }
        for t in accommodationTerms where m.contains(t) { return .accommodation }
        for t in eventTerms        where m.contains(t) { return .events }
        for t in shoppingTerms     where m.contains(t) { return .shopping }
        return .other
    }
}

// MARK: - Trip

@Model
final class Trip {
    var id: UUID
    var name: String
    var destination: String
    var startDate: Date
    var endDate: Date
    var budget: Double
    var emoji: String
    var colorHex: String
    var isArchived: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var subTrips: [SubTrip] = []

    @Relationship(deleteRule: .cascade)
    var expenses: [Expense] = []

    init(
        name: String,
        destination: String,
        startDate: Date,
        endDate: Date,
        budget: Double,
        emoji: String = "airplane",
        colorHex: String = "4A90D9"
    ) {
        self.id = UUID()
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.budget = budget
        self.emoji = emoji
        self.colorHex = colorHex
        self.isArchived = false
        self.createdAt = Date()
    }
}

// MARK: - SubTrip

@Model
final class SubTrip {
    var id: UUID
    var name: String
    var city: String
    var startDate: Date
    var endDate: Date
    var budget: Double
    var hasBudget: Bool
    var createdAt: Date

    var trip: Trip?

    @Relationship(deleteRule: .cascade)
    var expenses: [Expense] = []

    init(
        name: String,
        city: String,
        startDate: Date,
        endDate: Date,
        budget: Double = 0,
        hasBudget: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.city = city
        self.startDate = startDate
        self.endDate = endDate
        self.budget = budget
        self.hasBudget = hasBudget
        self.createdAt = Date()
    }
}

// MARK: - Expense

@Model
final class Expense {
    var id: UUID
    var amount: Double
    var originalCurrencyRaw: String
    var categoryRaw: String
    var merchant: String
    var notes: String
    var date: Date
    var createdAt: Date

    /// Plaid transaction ID — nil for manually entered expenses
    var plaidTransactionId: String?
    /// Raw string for the ExpenseSource enum
    var sourceRaw: String
    /// City where the purchase was made (from Plaid location data or manual entry)
    var purchaseCity: String?
    /// Country where the purchase was made
    var purchaseCountry: String?

    var subTrip: SubTrip?
    var trip: Trip?

    init(
        amount: Double,
        originalCurrency: Currency = .eur,
        category: ExpenseCategory = .other,
        merchant: String = "",
        notes: String = "",
        date: Date = Date(),
        source: ExpenseSource = .manual,
        plaidTransactionId: String? = nil,
        purchaseCity: String? = nil,
        purchaseCountry: String? = nil
    ) {
        self.id = UUID()
        self.amount = amount
        self.originalCurrencyRaw = originalCurrency.rawValue
        self.categoryRaw = category.rawValue
        self.merchant = merchant
        self.notes = notes
        self.date = date
        self.createdAt = Date()
        self.sourceRaw = source.rawValue
        self.plaidTransactionId = plaidTransactionId
        self.purchaseCity = purchaseCity
        self.purchaseCountry = purchaseCountry
    }

    var originalCurrency: Currency {
        get { Currency(rawValue: originalCurrencyRaw) ?? .eur }
        set { originalCurrencyRaw = newValue.rawValue }
    }

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var source: ExpenseSource {
        get { ExpenseSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var amountInEur: Double {
        switch originalCurrency {
        case .eur: return amount
        case .usd: return amount * Constants.usdToEurRate
        }
    }

    var amountInUsd: Double {
        switch originalCurrency {
        case .eur: return amount * Constants.eurToUsdRate
        case .usd: return amount
        }
    }

    func displayAmount(in currency: Currency) -> Double {
        switch currency {
        case .eur: return amountInEur
        case .usd: return amountInUsd
        }
    }
}

// MARK: - Plaid Linked Account

/// Represents a bank linked via Plaid.
/// The access token lives server-side only; we store just the display info + item_id.
@Model
final class PlaidLinkedAccount {
    var id: UUID
    var itemId: String          // Plaid item_id (used to identify/remove the item)
    var institutionName: String
    var linkedAt: Date

    init(itemId: String, institutionName: String) {
        self.id = UUID()
        self.itemId = itemId
        self.institutionName = institutionName
        self.linkedAt = Date()
    }
}
