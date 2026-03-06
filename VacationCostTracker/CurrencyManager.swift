import SwiftUI
import UIKit

// MARK: - Currency Manager
// Injected via .environment(currencyManager) at the root.
// Access in any view with: @Environment(CurrencyManager.self) private var currencyManager

@Observable
final class CurrencyManager {
    var displayCurrency: Currency = .eur

    var symbol: String { displayCurrency.symbol }

    func toggle() {
        withAnimation(.spring(duration: 0.3)) {
            displayCurrency = displayCurrency == .eur ? .usd : .eur
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Format a EUR-base amount into the display currency string.
    func format(_ amountInEur: Double) -> String {
        let value = convertedValue(amountInEur)
        return "\(displayCurrency.symbol)\(String(format: "%.2f", value))"
    }

    /// Return the numeric value of a EUR-base amount in the display currency.
    func convertedValue(_ amountInEur: Double) -> Double {
        switch displayCurrency {
        case .eur: return amountInEur
        case .usd: return amountInEur * Constants.eurToUsdRate
        }
    }

    /// Primary formatted string for an expense (converted to display currency).
    func formatExpense(_ expense: Expense) -> String {
        format(expense.amountInEur)
    }

    /// Original amount string as logged, e.g. "$42.00".
    func formatOriginal(_ expense: Expense) -> String {
        "\(expense.originalCurrency.symbol)\(String(format: "%.2f", expense.amount))"
    }

    /// Shows both display and original if they differ, e.g. "€38.89 (was $42.00)".
    func formatWithOriginal(_ expense: Expense) -> String {
        let primary = formatExpense(expense)
        let original = formatOriginal(expense)
        if expense.originalCurrency == displayCurrency {
            return primary
        }
        return "\(primary)  ·  \(original)"
    }
}
