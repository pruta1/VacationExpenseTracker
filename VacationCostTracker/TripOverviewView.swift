import SwiftUI

struct TripOverviewView: View {
    let trip: Trip
    @Environment(CurrencyManager.self) private var currency

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                tripHeaderCard
                    .padding(.horizontal)
                    .padding(.top, 12)

                if !trip.expenses.isEmpty {
                    expenseSection(
                        title: "Pre-Trip & General",
                        expenses: trip.expenses.sorted { $0.date < $1.date }
                    )
                    .padding(.horizontal)
                }

                ForEach(trip.subTrips.sorted { $0.startDate < $1.startDate }) { st in
                    destinationSection(st)
                        .padding(.horizontal)
                }

                if !trip.allCategoryTotals.isEmpty {
                    categoryBreakdownCard
                        .padding(.horizontal)
                }

                grandTotalCard
                    .padding(.horizontal)

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Trip Overview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                CurrencyToggleBarButton()
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Trip Header

    private var tripHeaderCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [trip.accentColor, trip.accentColor.opacity(0.7)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    Image(systemName: trip.emoji)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(trip.name)
                        .font(.title3.bold())
                    if !trip.destination.isEmpty {
                        Text(trip.destination)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(trip.dateRangeString + " · \(trip.daysTotal) days")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }

            Divider()

            VStack(spacing: 8) {
                HStack {
                    Text("Total Budget")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(currency.format(trip.budget))
                        .font(.subheadline.bold())
                }
                HStack {
                    Text("Total Spent")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(currency.format(trip.totalSpentCalc))
                        .font(.subheadline.bold())
                        .foregroundStyle(trip.totalSpentCalc > trip.budget ? .red : .primary)
                }
                AnimatedProgressBar(progress: trip.progressCalc, height: 8)
                HStack {
                    let rem = trip.budget - trip.totalSpentCalc
                    Text(rem >= 0 ? "\(currency.format(rem)) remaining" : "\(currency.format(-rem)) over budget")
                        .font(.caption)
                        .foregroundStyle(rem >= 0 ? Color.secondary : Color.red)
                    Spacer()
                    Text("\(Int(trip.progressCalc * 100))%")
                        .font(.caption.bold())
                        .foregroundStyle(trip.progressCalc >= 0.9 ? Color.red : Color.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Expense Section (Pre-trip or per-destination)

    private func expenseSection(title: String, expenses: [Expense]) -> some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text(title)
                    .font(.caption.uppercaseSmallCaps())
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(currency.format(expenses.reduce(0) { $0 + $1.amountInEur }))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Expense rows
            VStack(spacing: 0) {
                ForEach(expenses) { expense in
                    overviewExpenseRow(expense)
                    if expense.id != expenses.last?.id {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.top, 4)
        }
    }

    private func overviewExpenseRow(_ expense: Expense) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(expense.category.color.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: expense.category.symbolName)
                    .font(.caption.bold())
                    .foregroundStyle(expense.category.color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(expense.merchant.isEmpty ? expense.category.displayName : expense.merchant)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(expense.date.shortDateString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(currency.formatExpense(expense))
                    .font(.subheadline.bold())
                if expense.originalCurrency != currency.displayCurrency {
                    Text(currency.formatOriginal(expense))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    // MARK: - Destination Section

    private func destinationSection(_ st: SubTrip) -> some View {
        VStack(spacing: 4) {
            // Destination header
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(st.name)
                        .font(.caption.uppercaseSmallCaps())
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    if !st.city.isEmpty {
                        Text(st.city)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Text(currency.format(st.totalSpentCalc))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if st.expenses.isEmpty {
                Text("No expenses")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            } else {
                let sorted = st.expenses.sorted { $0.date < $1.date }
                VStack(spacing: 0) {
                    ForEach(sorted) { expense in
                        overviewExpenseRow(expense)
                        if expense.id != sorted.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Category Breakdown

    private var categoryBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("By Category")
                .font(.caption.uppercaseSmallCaps())
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(trip.allCategoryTotals, id: \.0) { cat, total in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(cat.color.opacity(0.15))
                                .frame(width: 30, height: 30)
                            Image(systemName: cat.symbolName)
                                .font(.caption.bold())
                                .foregroundStyle(cat.color)
                        }
                        Text(cat.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(currency.format(total))
                            .font(.subheadline.bold())
                        let pct = trip.totalSpentCalc > 0 ? Int((total / trip.totalSpentCalc) * 100) : 0
                        Text("(\(pct)%)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Grand Total

    private var grandTotalCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("GRAND TOTAL")
                    .font(.caption.uppercaseSmallCaps())
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                Text("\(trip.subTrips.count) destination\(trip.subTrips.count == 1 ? "" : "s") · \(totalExpenseCount) expense\(totalExpenseCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text(currency.format(trip.totalSpentCalc))
                .font(.title2.bold())
                .foregroundStyle(trip.totalSpentCalc > trip.budget ? Color.red : trip.accentColor)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(trip.accentColor.opacity(0.35), lineWidth: 1.5)
                )
        )
    }

    private var totalExpenseCount: Int {
        trip.expenses.count + trip.subTrips.reduce(0) { $0 + $1.expenses.count }
    }
}
