import SwiftUI
import SwiftData

struct TripDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CurrencyManager.self) private var currency

    let trip: Trip

    @State private var showAddSubTrip = false
    @State private var subTripToEdit: SubTrip?
    @State private var destinationSubTrip: SubTrip?
    @State private var showAnalytics = false
    @State private var showOverview = false
    @State private var showAddTripExpense = false
    @State private var tripExpenseToEdit: Expense?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            List {
                // Summary card
                overallSummaryCard
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                // Pre-Trip & General section
                Section {
                    if trip.expenses.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle").foregroundStyle(.secondary)
                            Text("No trip-level expenses yet — add flights, insurance, etc.")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    } else {
                        ForEach(trip.expenses.sorted { $0.date > $1.date }) { expense in
                            tripExpenseRow(expense)
                                .listRowInsets(EdgeInsets())
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) { deleteTripExpense(expense) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button { tripExpenseToEdit = expense } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                } header: {
                    HStack {
                        Text("Pre-Trip & General").textCase(nil)
                        Spacer()
                        Button { showAddTripExpense = true } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentColor)
                                .font(.body)
                        }
                    }
                } footer: {
                    if !trip.expenses.isEmpty {
                        HStack {
                            Text("Fixed costs total")
                            Spacer()
                            Text(currency.format(trip.expenses.reduce(0) { $0 + $1.amountInEur }))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                // Destinations section
                if trip.subTrips.isEmpty {
                    EmptyStateView(
                        icon: "mappin.and.ellipse",
                        title: "No destinations yet",
                        message: "Add cities or regions to \(trip.name)",
                        actionLabel: "Add Destination",
                        action: { showAddSubTrip = true }
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    Section {
                        ForEach(trip.subTrips.sorted { $0.startDate < $1.startDate }) { st in
                            Button { destinationSubTrip = st } label: {
                                SubTripCardView(subTrip: st)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { deleteSubTrip(st) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button { subTripToEdit = st } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    } header: {
                        Text("Destinations").textCase(nil)
                    } footer: {
                        Color.clear.frame(height: 80)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            FABButton(icon: "plus") {
                showAddSubTrip = true
            }
            .padding(20)
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 4) {
                    Menu {
                        Button { showOverview = true } label: {
                            Label("Overview", systemImage: "doc.text.fill")
                        }
                        Button { showAnalytics = true } label: {
                            Label("Analytics", systemImage: "chart.bar.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    CurrencyToggleBarButton()
                }
            }
        }
        .sheet(isPresented: $showAddSubTrip) {
            AddEditSubTripView(trip: trip)
        }
        .sheet(item: $subTripToEdit) { st in
            AddEditSubTripView(trip: trip, subTrip: st)
        }
        .sheet(isPresented: $showAddTripExpense) {
            AddEditExpenseView(context: .trip(trip))
        }
        .sheet(item: $tripExpenseToEdit) { e in
            AddEditExpenseView(context: .trip(trip), expense: e)
        }
        .navigationDestination(item: $destinationSubTrip) { st in
            SubTripDetailView(subTrip: st)
        }
        .navigationDestination(isPresented: $showAnalytics) {
            TripAnalyticsView(trip: trip)
        }
        .navigationDestination(isPresented: $showOverview) {
            TripOverviewView(trip: trip)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Overall Summary Card

    private var overallSummaryCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.destination)
                        .font(.subheadline.bold())
                    Text(trip.dateRangeString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if trip.isCurrent {
                        Label("Ongoing", systemImage: "location.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(.green)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(currency.format(trip.totalSpentCalc))
                        .font(.title.bold())
                        .foregroundStyle(trip.progressCalc >= 1.0 ? .red : .primary)
                    Text("of \(currency.format(trip.budget))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            AnimatedProgressBar(progress: trip.progressCalc, height: 10)

            HStack(spacing: 0) {
                let remaining = trip.budget - trip.totalSpentCalc
                summaryChip(
                    label: "Remaining",
                    value: currency.format(max(remaining, 0)),
                    color: remaining >= 0 ? trip.accentColor : .red
                )
                Divider().frame(height: 32)
                summaryChip(
                    label: "Daily Avg",
                    value: currency.format(trip.dailyAverage),
                    color: .secondary
                )
                Divider().frame(height: 32)
                summaryChip(
                    label: Date() > trip.endDate ? "Ended" : (Date() < trip.startDate ? "Duration" : "Days Left"),
                    value: Date() > trip.endDate ? "—" : "\(trip.daysRemaining)",
                    color: .secondary
                )
            }
            .padding(.vertical, 4)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(trip.accentColor.opacity(0.4), lineWidth: 1.5)
                )
        )
    }

    private func summaryChip(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Trip Expense Row

    private func tripExpenseRow(_ expense: Expense) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(expense.category.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: expense.category.symbolName)
                    .font(.body)
                    .foregroundStyle(expense.category.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.merchant.isEmpty ? expense.category.displayName : expense.merchant)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                if let city = expense.purchaseCity, !city.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption2)
                        Text(city)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                } else if !expense.notes.isEmpty {
                    Text(expense.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(currency.formatExpense(expense))
                .font(.subheadline.bold())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { tripExpenseToEdit = expense }
    }

    // MARK: - Delete

    private func deleteSubTrip(_ st: SubTrip) {
        HapticManager.impact(.medium)
        withAnimation {
            trip.subTrips.removeAll { $0.id == st.id }
            modelContext.delete(st)
        }
    }

    private func deleteTripExpense(_ expense: Expense) {
        HapticManager.impact(.light)
        withAnimation {
            trip.expenses.removeAll { $0.id == expense.id }
            modelContext.delete(expense)
        }
    }
}

// MARK: - Sub-trip Card

struct SubTripCardView: View {
    @Environment(CurrencyManager.self) private var currency
    let subTrip: SubTrip

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subTrip.name)
                        .font(.headline.bold())
                    Text(subTrip.dateRangeString + " · \(subTrip.durationDays)d")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(currency.format(subTrip.totalSpentCalc))
                        .font(.headline.bold())
                        .foregroundStyle(subTrip.hasBudget && subTrip.progressCalc >= 1.0 ? .red : .primary)
                    if subTrip.hasBudget {
                        Text("of \(currency.format(subTrip.budget))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(subTrip.expenses.count) expense\(subTrip.expenses.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if subTrip.hasBudget {
                AnimatedProgressBar(progress: subTrip.progressCalc, height: 6)
            }

            // Top category chip
            if let topCat = subTrip.topCategory {
                HStack(spacing: 4) {
                    Image(systemName: topCat.symbolName)
                        .font(.caption)
                    Text(topCat.displayName)
                        .font(.caption)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(topCat.color.opacity(0.12), in: Capsule())
                .foregroundStyle(topCat.color)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
