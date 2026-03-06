import SwiftUI
import SwiftData

struct SubTripDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CurrencyManager.self) private var currency

    let subTrip: SubTrip

    @State private var showAddExpense = false
    @State private var expenseToEdit: Expense?
    @State private var selectedTab: SubTripTab = .timeline

    enum SubTripTab: String, CaseIterable {
        case timeline = "Timeline"
        case categories = "Categories"
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Header stats
                headerCard
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                // Tab switcher
                Picker("View", selection: $selectedTab) {
                    ForEach(SubTripTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                // Content
                if subTrip.expenses.isEmpty {
                    EmptyStateView(
                        icon: "fork.knife",
                        title: "No expenses yet",
                        message: "Tap + to add your first expense in \(subTrip.name)"
                    )
                } else {
                    switch selectedTab {
                    case .timeline: timelineView
                    case .categories: categoriesView
                    }
                }
            }

            // FAB
            FABButton(icon: "plus") {
                showAddExpense = true
            }
            .padding(20)
        }
        .navigationTitle(subTrip.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                CurrencyToggleBarButton()
            }
        }
        .sheet(isPresented: $showAddExpense) {
            AddEditExpenseView(context: .subTrip(subTrip))
        }
        .sheet(item: $expenseToEdit) { e in
            AddEditExpenseView(context: .subTrip(subTrip), expense: e)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subTrip.dateRangeString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(subTrip.durationDays) day\(subTrip.durationDays == 1 ? "" : "s") · \(subTrip.expenses.count) expense\(subTrip.expenses.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(currency.format(subTrip.totalSpentCalc))
                        .font(.title2.bold())
                        .foregroundStyle(subTrip.hasBudget && subTrip.progressCalc >= 1.0 ? .red : .primary)
                    if subTrip.hasBudget {
                        Text("of \(currency.format(subTrip.budget))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if subTrip.hasBudget {
                AnimatedProgressBar(progress: subTrip.progressCalc, height: 8)
                HStack {
                    let remaining = subTrip.budget - subTrip.totalSpentCalc
                    Text(remaining >= 0 ? "\(currency.format(remaining)) remaining" : "\(currency.format(-remaining)) over budget")
                        .font(.caption)
                        .foregroundStyle(remaining >= 0 ? Color.secondary : Color.red)
                    Spacer()
                    Text("\(Int(subTrip.progressCalc * 100))%")
                        .font(.caption.bold())
                        .foregroundStyle(subTrip.progressCalc >= 0.9 ? Color.red : Color.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Timeline View

    private var timelineView: some View {
        List {
            ForEach(subTrip.expensesByDate, id: \.0) { date, expenses in
                Section {
                    ForEach(expenses) { expense in
                        expenseRow(expense)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color(.secondarySystemGroupedBackground))
                    }
                } header: {
                    dateHeader(date: date, expenses: expenses)
                }
            }
            // Bottom padding so FAB doesn't obscure last row
            Color.clear.frame(height: 80).listRowBackground(Color.clear).listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func dateHeader(date: Date, expenses: [Expense]) -> some View {
        let dailyTotal = expenses.reduce(0) { $0 + $1.amountInEur }
        return HStack {
            Text(date.weekdayDayMonthString)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Spacer()
            Text(currency.format(dailyTotal))
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }

    // MARK: - Categories View

    private var categoriesView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(subTrip.categoryTotals, id: \.0) { cat, total in
                    CategoryExpenseGroup(
                        category: cat,
                        total: total,
                        expenses: subTrip.expenses.filter { $0.category == cat }.sorted { $0.date > $1.date },
                        currency: currency,
                        onEdit: { expenseToEdit = $0 },
                        onDelete: deleteExpense
                    )
                }
                Spacer(minLength: 100)
            }
            .padding(.horizontal)
            .padding(.top, 6)
        }
    }

    // MARK: - Expense Row

    private func expenseRow(_ expense: Expense) -> some View {
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

            VStack(alignment: .trailing, spacing: 2) {
                Text(currency.formatExpense(expense))
                    .font(.subheadline.bold())
                if expense.originalCurrency != currency.displayCurrency {
                    Text(currency.formatOriginal(expense))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { expenseToEdit = expense }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                deleteExpense(expense)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                expenseToEdit = expense
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }

    // MARK: - Delete

    private func deleteExpense(_ expense: Expense) {
        HapticManager.impact(.light)
        withAnimation {
            subTrip.expenses.removeAll { $0.id == expense.id }
            modelContext.delete(expense)
        }
    }
}

// MARK: - Category Expense Group (expandable)

private struct CategoryExpenseGroup: View {
    let category: ExpenseCategory
    let total: Double
    let expenses: [Expense]
    let currency: CurrencyManager
    let onEdit: (Expense) -> Void
    let onDelete: (Expense) -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Category header row (tap to expand)
            Button {
                withAnimation(.spring(duration: 0.3)) { isExpanded.toggle() }
                HapticManager.impact(.soft)
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(category.color.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: category.symbolName)
                            .font(.body)
                            .foregroundStyle(category.color)
                    }
                    Text(category.displayName)
                        .font(.subheadline.bold())
                    Spacer()
                    Text(currency.format(total))
                        .font(.subheadline.bold())
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            // Expanded expenses
            if isExpanded {
                Divider().padding(.leading, 66)
                ForEach(expenses) { e in
                    HStack(spacing: 12) {
                        Spacer().frame(width: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.merchant.isEmpty ? e.date.shortDateString : e.merchant)
                                .font(.subheadline)
                                .lineLimit(1)
                            Text(e.date.shortDateString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(currency.formatExpense(e))
                                .font(.subheadline.bold())
                            if e.originalCurrency != currency.displayCurrency {
                                Text(currency.formatOriginal(e))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture { onEdit(e) }
                    .contextMenu {
                        Button("Edit") { onEdit(e) }
                        Button("Delete", role: .destructive) { onDelete(e) }
                    }
                    if e.id != expenses.last?.id {
                        Divider().padding(.leading, 66)
                    }
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
