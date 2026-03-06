import AppIntents
import SwiftData
import SwiftUI

// MARK: - Log Expense Intent
//
// Exposes a "Log Trip Expense" action to Apple Shortcuts.
//
// Suggested Shortcuts automation:
//   1. Open the Shortcuts app
//   2. Tap Automation > New Automation
//   3. Choose "App" trigger > select Venmo / Cash App / Zelle
//   4. Add action: "Ask for Input" (type: Number, prompt: "How much did you spend?")
//   5. Add action: "Log Trip Expense" — set Amount to the Ask input
//   6. This fires every time you open Venmo, prompting for the amount
//
// You can also invoke it manually: "Hey Siri, log a trip expense"

struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Trip Expense"
    static var description = IntentDescription(
        "Quickly log an expense to your active vacation trip.",
        categoryName: "Vacation Tracker"
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Amount", description: "How much did you spend?")
    var amount: Double

    @Parameter(title: "Category", default: ExpenseCategoryAppEnum.other)
    var category: ExpenseCategoryAppEnum

    @Parameter(title: "Merchant / Description", requestValueDialog: "Where did you spend it? (optional)")
    var merchant: String?

    @Parameter(title: "Currency", default: CurrencyAppEnum.eur)
    var currency: CurrencyAppEnum

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainer(for: Trip.self, SubTrip.self, Expense.self, PlaidLinkedAccount.self)
        let context = container.mainContext

        var tripDescriptor = FetchDescriptor<Trip>()
        tripDescriptor.sortBy = [SortDescriptor(\.startDate)]
        let allTrips = (try? context.fetch(tripDescriptor)) ?? []
        let today = Date()
        guard let activeTrip = allTrips.first(where: { trip in
            today >= Calendar.current.startOfDay(for: trip.startDate) && today <= trip.endDate
        }) else {
            return .result(dialog: "No active trip found. Create a trip in VacationCostTracker first.")
        }

        let expense = Expense(
            amount: amount,
            originalCurrency: currency.toCurrency(),
            category: category.toExpenseCategory(),
            merchant: merchant ?? "",
            date: today,
            source: .shortcut
        )
        context.insert(expense)
        activeTrip.expenses.append(expense)
        try? context.save()

        let currencySymbol = currency == .eur ? "€" : "$"
        return .result(dialog: "Logged \(currencySymbol)\(String(format: "%.2f", amount)) to \(activeTrip.name).")
    }
}

// MARK: - Category Enum (AppIntents-compatible)

enum ExpenseCategoryAppEnum: String, AppEnum {
    case transportation, food, accommodation, events, shopping, other

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Expense Category"
    static var caseDisplayRepresentations: [ExpenseCategoryAppEnum: DisplayRepresentation] = [
        .transportation: DisplayRepresentation(title: "Transportation",       image: .init(systemName: "car.fill")),
        .food:           DisplayRepresentation(title: "Food & Drink",         image: .init(systemName: "fork.knife")),
        .accommodation:  DisplayRepresentation(title: "Accommodation",        image: .init(systemName: "bed.double.fill")),
        .events:         DisplayRepresentation(title: "Events & Activities",  image: .init(systemName: "theatermasks.fill")),
        .shopping:       DisplayRepresentation(title: "Shopping",             image: .init(systemName: "bag.fill")),
        .other:          DisplayRepresentation(title: "Other",                image: .init(systemName: "ellipsis.circle.fill")),
    ]

    func toExpenseCategory() -> ExpenseCategory {
        ExpenseCategory(rawValue: rawValue) ?? .other
    }
}

// MARK: - Currency Enum (AppIntents-compatible)

enum CurrencyAppEnum: String, AppEnum {
    case eur = "EUR"
    case usd = "USD"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Currency"
    static var caseDisplayRepresentations: [CurrencyAppEnum: DisplayRepresentation] = [
        .eur: DisplayRepresentation(title: "EUR (€)"),
        .usd: DisplayRepresentation(title: "USD ($)"),
    ]

    func toCurrency() -> Currency {
        Currency(rawValue: rawValue) ?? .eur
    }
}

// MARK: - App Shortcuts Provider
//
// Registers the intent with Siri so users can say "Log a trip expense".

struct VacationTrackerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: [
                "Log a trip expense in \(.applicationName)",
                "Add a vacation expense in \(.applicationName)",
                "Track a travel expense with \(.applicationName)",
            ],
            shortTitle: "Log Trip Expense",
            systemImageName: "dollarsign.circle.fill"
        )
    }
}
