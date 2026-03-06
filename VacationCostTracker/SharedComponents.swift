import SwiftUI
import UIKit

// MARK: - Haptics

struct HapticManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

// MARK: - Animated Progress Bar

struct AnimatedProgressBar: View {
    let progress: Double   // 0.0 – 1.0
    var height: CGFloat = 8
    var fillColor: Color? = nil       // nil = auto green/yellow/red
    var trackColor: Color = Color(.systemFill)

    @State private var animated: Double = 0

    private var barColor: Color {
        if let fillColor { return fillColor }
        if progress < 0.70 { return .green }
        if progress < 0.90 { return .yellow }
        return .red
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(trackColor)
                    .frame(height: height)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(barColor.gradient)
                    .frame(width: geo.size.width * min(max(animated, 0), 1), height: height)
                    .animation(.spring(duration: 0.75, bounce: 0.2), value: animated)
            }
        }
        .frame(height: height)
        .onAppear { animated = progress }
        .onChange(of: progress) { animated = progress }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionLabel: String = ""
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color(.quaternarySystemFill))
                    .frame(width: 90, height: 90)
                Image(systemName: icon)
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.bold())
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let action, !actionLabel.isEmpty {
                Button(actionLabel, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 4)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - FAB Button

struct FABButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.impact(.medium)
            action()
        } label: {
            Image(systemName: icon)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Color.accentColor.gradient, in: Circle())
                .shadow(color: .accentColor.opacity(0.40), radius: 10, y: 4)
        }
    }
}

// MARK: - Currency Toggle Bar Button

struct CurrencyToggleBarButton: View {
    @Environment(CurrencyManager.self) private var currency

    var body: some View {
        Button {
            currency.toggle()
        } label: {
            HStack(spacing: 3) {
                Text(currency.displayCurrency.flag)
                Text(currency.displayCurrency.rawValue)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.3), value: currency.displayCurrency)
    }
}

// MARK: - Budget Stat Row

struct StatRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(valueColor)
        }
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        h = h.hasPrefix("#") ? String(h.dropFirst()) : h
        guard h.count == 6 else { return nil }
        var rgb: UInt64 = 0
        guard Scanner(string: h).scanHexInt64(&rgb) else { return nil }
        self.init(
            red:   Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >>  8) / 255.0,
            blue:  Double( rgb & 0x0000FF        ) / 255.0
        )
    }
}

// MARK: - Date Extensions

extension Date {
    var dayMonthString: String {
        formatted(.dateTime.month(.abbreviated).day())
    }
    var shortDateString: String {
        formatted(date: .abbreviated, time: .omitted)
    }
    var fullDateString: String {
        formatted(date: .long, time: .omitted)
    }
    var monthYearString: String {
        formatted(.dateTime.month(.wide).year())
    }
    var weekdayDayMonthString: String {
        formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

// MARK: - Double Extension

extension Double {
    var formattedAmount: String {
        String(format: "%.2f", self)
    }
}

// MARK: - Trip Computed Helpers (extension — not stored, avoids SwiftData conflicts)

extension Trip {
    var totalSpentCalc: Double {
        let tripLevel = expenses.reduce(0) { $0 + $1.amountInEur }
        let subLevel  = subTrips.flatMap(\.expenses).reduce(0) { $0 + $1.amountInEur }
        return tripLevel + subLevel
    }

    /// All expenses (trip-level + all sub-trips) grouped by category, sorted by total desc.
    var allCategoryTotals: [(ExpenseCategory, Double)] {
        var totals: [ExpenseCategory: Double] = [:]
        for e in expenses { totals[e.category, default: 0] += e.amountInEur }
        for e in subTrips.flatMap(\.expenses) { totals[e.category, default: 0] += e.amountInEur }
        return totals.sorted { $0.value > $1.value }
    }

    var progressCalc: Double {
        guard budget > 0 else { return 0 }
        return min(totalSpentCalc / budget, 1.0)
    }

    var daysTotal: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }

    var daysRemaining: Int {
        let now = Date()
        guard now <= endDate else { return 0 }          // trip ended
        guard now >= startDate else { return daysTotal } // trip not started — show full duration
        return max(Calendar.current.dateComponents([.day], from: now, to: endDate).day ?? 0, 0)
    }

    /// Days elapsed within the trip window (0 before trip starts, capped at daysTotal after it ends).
    var daysElapsed: Int {
        let now = Date()
        if now <= startDate { return 1 }
        if now >= endDate   { return max(daysTotal, 1) }
        return max(Calendar.current.dateComponents([.day], from: startDate, to: now).day ?? 1, 1)
    }

    /// Daily burn rate uses only in-trip (sub-trip) expenses — pre-trip lump sums (flights, insurance)
    /// are excluded so they don't distort the per-day figure.
    var dailyAverage: Double {
        let inTripSpend = subTrips.flatMap(\.expenses).reduce(0) { $0 + $1.amountInEur }
        guard daysElapsed > 0 else { return 0 }
        return inTripSpend / Double(daysElapsed)
    }

    /// Pre-trip fixed costs + projected daily burn over the full trip duration.
    var projectedTotal: Double {
        let preTripSpend = expenses.reduce(0) { $0 + $1.amountInEur }
        guard daysTotal > 0 else { return totalSpentCalc }
        return preTripSpend + dailyAverage * Double(daysTotal)
    }

    var accentColor: Color {
        Color(hex: colorHex) ?? .accentColor
    }

    var dateRangeString: String {
        "\(startDate.dayMonthString) – \(endDate.dayMonthString)"
    }

    var isCurrent: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
}

extension SubTrip {
    var totalSpentCalc: Double {
        expenses.reduce(0) { $0 + $1.amountInEur }
    }

    var progressCalc: Double {
        guard hasBudget && budget > 0 else { return 0 }
        return min(totalSpentCalc / budget, 1.0)
    }

    var durationDays: Int {
        max(Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0, 1)
    }

    var dateRangeString: String {
        "\(startDate.dayMonthString) – \(endDate.dayMonthString)"
    }

    var expensesByDate: [(Date, [Expense])] {
        let sorted = expenses.sorted { $0.date > $1.date }
        let grouped = Dictionary(grouping: sorted) {
            Calendar.current.startOfDay(for: $0.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var categoryTotals: [(ExpenseCategory, Double)] {
        var totals: [ExpenseCategory: Double] = [:]
        for e in expenses { totals[e.category, default: 0] += e.amountInEur }
        return totals.sorted { $0.value > $1.value }
    }

    var topCategory: ExpenseCategory? { categoryTotals.first?.0 }
}
