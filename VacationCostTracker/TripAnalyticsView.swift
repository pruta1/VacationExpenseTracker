import SwiftUI
import Charts

// MARK: - Trip Analytics View
// Shown from TripDetailView. Displays spend breakdown and projections.

struct TripAnalyticsView: View {
    let trip: Trip
    @Environment(CurrencyManager.self) private var currency

    // Aggregate category totals across trip-level and all sub-trips
    private var categoryData: [(category: ExpenseCategory, total: Double)] {
        trip.allCategoryTotals.map { (category: $0.0, total: $0.1) }
    }

    private var totalSpent: Double { trip.totalSpentCalc }
    private var topCategory: (category: ExpenseCategory, total: Double)? { categoryData.first }

    private var todaySpent: Double {
        let cal = Calendar.current
        let allExpenses = trip.expenses + trip.subTrips.flatMap { $0.expenses }
        return allExpenses
            .filter { cal.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.amountInEur }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                overviewGrid
                    .padding(.horizontal)

                todaySpendingCard
                    .padding(.horizontal)

                if totalSpent > 0 {
                    categoryChartCard
                        .padding(.horizontal)
                }

                if trip.daysTotal > 0 && !trip.isArchived {
                    projectionCard
                        .padding(.horizontal)
                }

                subTripBreakdownCard
                    .padding(.horizontal)

                Spacer(minLength: 40)
            }
            .padding(.top, 12)
        }
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                CurrencyToggleBarButton()
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Overview Stats Grid

    private var overviewGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(label: "Total Spent",    value: currency.format(totalSpent),              accent: .blue)
            statCard(label: "Daily Average",  value: currency.format(trip.dailyAverage),       accent: .teal)
            statCard(label: "Days Remaining", value: "\(trip.daysRemaining)",                  accent: trip.daysRemaining <= 2 ? .orange : .green)
            statCard(label: "Top Category",   value: topCategory?.category.displayName ?? "—", accent: topCategory?.category.color ?? .secondary)
        }
    }

    private func statCard(label: String, value: String, accent: Color = .accentColor) -> some View {
        HStack(spacing: 12) {
            Capsule()
                .fill(accent)
                .frame(width: 3, height: 28)
            VStack(alignment: .leading, spacing: 6) {
                Text(value)
                    .font(.title3.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Today's Spending Card

    private var todaySpendingCard: some View {
        HStack(spacing: 14) {
            Capsule()
                .fill(Color.accentColor)
                .frame(width: 3, height: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's Spending")
                    .font(.headline)
                Text("Based on expense date · resets at midnight")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(currency.format(todaySpent))
                .font(.title2.bold())
                .foregroundStyle(todaySpent > 0 ? Color.primary : Color.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Category Chart

    private var categoryChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Spending by Category")
                .font(.headline)

            Chart(categoryData, id: \.category) { item in
                BarMark(
                    x: .value("Amount", currency.convertedValue(item.total)),
                    y: .value("Category", item.category.displayName)
                )
                .foregroundStyle(item.category.color.gradient)
                .cornerRadius(4)
                .annotation(position: .trailing, alignment: .leading) {
                    Text(currency.format(item.total))
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxis(.hidden)
            .frame(height: CGFloat(max(categoryData.count, 1)) * 40)

            if totalSpent > 0 {
                Divider()
                // Percentage breakdown list
                ForEach(categoryData, id: \.category) { item in
                    HStack(spacing: 10) {
                        Image(systemName: item.category.symbolName)
                            .font(.body)
                            .foregroundStyle(item.category.color)
                            .frame(width: 24)
                        Text(item.category.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(currency.format(item.total))
                            .font(.subheadline.bold())
                        Text("(\(Int((item.total / totalSpent) * 100))%)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Projection Card

    private var projectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Burn Rate Projection")
                .font(.headline)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Projected Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(currency.format(trip.projectedTotal))
                        .font(.title3.bold())
                        .foregroundStyle(trip.projectedTotal > trip.budget ? .red : .green)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Budget")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(currency.format(trip.budget))
                        .font(.title3.bold())
                }
            }

            AnimatedProgressBar(progress: trip.projectedTotal / max(trip.budget, 1), height: 10)

            let diff = trip.projectedTotal - trip.budget
            if diff > 0 {
                Label(
                    "\(currency.format(diff)) over budget at current pace",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.red)
            } else {
                Label(
                    "\(currency.format(-diff)) under budget at current pace",
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(.green)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Sub-trip Breakdown

    private var subTripBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("By Destination")
                .font(.headline)

            if trip.subTrips.isEmpty {
                Text("No destinations added yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(trip.subTrips) { st in
                    VStack(spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(st.name)
                                    .font(.subheadline.bold())
                                Text("\(st.durationDays) day\(st.durationDays == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(currency.format(st.totalSpentCalc))
                                    .font(.subheadline.bold())
                                if totalSpent > 0 {
                                    Text("\(Int((st.totalSpentCalc / totalSpent) * 100))%")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        if totalSpent > 0 {
                            AnimatedProgressBar(
                                progress: st.totalSpentCalc / totalSpent,
                                height: 4
                            )
                        }
                    }
                    if st.id != trip.subTrips.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
