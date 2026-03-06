import SwiftUI
import SwiftData

struct AddEditTripView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var trip: Trip?

    @State private var name = ""
    @State private var destination = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var budgetText = ""
    @State private var selectedSymbol = "airplane"
    @State private var selectedColorHex = "4A90D9"

    private var isEditing: Bool { trip != nil }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && endDate >= startDate
        && (Double(budgetText) ?? 0) > 0
    }

    private let columns = Array(repeating: GridItem(.flexible()), count: 5)

    var body: some View {
        NavigationStack {
            Form {
                iconSection
                identitySection
                datesSection
                budgetSection
                colorSection
            }
            .navigationTitle(isEditing ? "Edit Trip" : "New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    // MARK: - Sections

    private var iconSection: some View {
        Section {
            // Preview of selected icon
            HStack {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: selectedColorHex) ?? .accentColor,
                                         (Color(hex: selectedColorHex) ?? .accentColor).opacity(0.7)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    Image(systemName: selectedSymbol)
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.clear)

            // Symbol grid
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(TripCoverOption.symbols, id: \.self) { sym in
                    Button {
                        withAnimation(.spring(duration: 0.2)) { selectedSymbol = sym }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedSymbol == sym
                                      ? (Color(hex: selectedColorHex) ?? .accentColor).opacity(0.2)
                                      : Color(.systemFill))
                                .frame(height: 48)
                            Image(systemName: sym)
                                .font(.title3)
                                .foregroundStyle(selectedSymbol == sym
                                                 ? (Color(hex: selectedColorHex) ?? .accentColor)
                                                 : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Icon")
        }
    }

    private var identitySection: some View {
        Section {
            TextField("Trip Name  (e.g. Europe Summer 2025)", text: $name)
            LocationPickerField(text: $destination, placeholder: "Destination (optional)")
        } header: {
            Text("Details")
        }
    }

    private var datesSection: some View {
        Section {
            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
            DatePicker("End Date",   selection: $endDate,   in: startDate..., displayedComponents: .date)
        } header: {
            Text("Dates")
        }
    }

    private var budgetSection: some View {
        Section {
            HStack {
                Text("€").foregroundStyle(.secondary)
                TextField("Total Budget (EUR)", text: $budgetText)
                    .keyboardType(.decimalPad)
            }
        } header: {
            Text("Budget")
        } footer: {
            Text("Enter your overall budget in EUR.")
                .font(.caption)
        }
    }

    private var colorSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(TripCoverOption.colorHexes, id: \.hex) { option in
                        Button {
                            withAnimation(.spring(duration: 0.2)) {
                                selectedColorHex = option.hex
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: option.hex) ?? .blue)
                                    .frame(width: 34, height: 34)
                                if selectedColorHex == option.hex {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Colour")
        }
    }

    // MARK: - Actions

    private func populateIfEditing() {
        guard let trip else { return }
        name = trip.name
        destination = trip.destination
        startDate = trip.startDate
        endDate = trip.endDate
        budgetText = trip.budget.formattedAmount
        selectedSymbol = trip.emoji
        selectedColorHex = trip.colorHex
    }

    private func save() {
        guard let budget = Double(budgetText) else { return }
        HapticManager.success()

        if let trip {
            trip.name = name.trimmingCharacters(in: .whitespaces)
            trip.destination = destination
            trip.startDate = startDate
            trip.endDate = endDate
            trip.budget = budget
            trip.emoji = selectedSymbol
            trip.colorHex = selectedColorHex
        } else {
            let newTrip = Trip(
                name: name.trimmingCharacters(in: .whitespaces),
                destination: destination,
                startDate: startDate,
                endDate: endDate,
                budget: budget,
                emoji: selectedSymbol,
                colorHex: selectedColorHex
            )
            modelContext.insert(newTrip)
        }
        dismiss()
    }
}
