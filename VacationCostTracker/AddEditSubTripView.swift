import SwiftUI
import SwiftData

struct AddEditSubTripView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let trip: Trip
    var subTrip: SubTrip? // nil = create, non-nil = edit

    @State private var city = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var hasBudget = false
    @State private var budgetText = ""

    private var isEditing: Bool { subTrip != nil }

    private var isValid: Bool {
        !city.trimmingCharacters(in: .whitespaces).isEmpty
        && endDate >= startDate
        && (!hasBudget || (Double(budgetText) ?? 0) > 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Identity
                Section {
                    LocationPickerField(text: $city, placeholder: "City / Country")
                } header: {
                    Text("Destination")
                }

                // MARK: Dates
                Section {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date",   selection: $endDate,   in: startDate..., displayedComponents: .date)
                } header: {
                    Text("Dates")
                } footer: {
                    let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
                    Text("\(days) day\(days == 1 ? "" : "s") selected")
                }

                // MARK: Budget (optional)
                Section {
                    Toggle("Set a budget for this destination", isOn: $hasBudget.animation())
                    if hasBudget {
                        HStack {
                            Text("€")
                                .foregroundStyle(.secondary)
                            TextField("Budget (EUR)", text: $budgetText)
                                .keyboardType(.decimalPad)
                        }
                    }
                } header: {
                    Text("Budget (Optional)")
                }
            }
            .navigationTitle(isEditing ? "Edit Destination" : "New Destination")
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

    private func populateIfEditing() {
        guard let st = subTrip else { return }
        city = st.city.isEmpty ? st.name : st.city
        startDate = st.startDate
        endDate = st.endDate
        hasBudget = st.hasBudget
        budgetText = st.hasBudget ? st.budget.formattedAmount : ""
    }

    private func save() {
        HapticManager.success()
        let budget = Double(budgetText) ?? 0

        if let st = subTrip {
            st.name = city.trimmingCharacters(in: .whitespaces)
            st.city = city.trimmingCharacters(in: .whitespaces)
            st.startDate = startDate
            st.endDate = endDate
            st.hasBudget = hasBudget
            st.budget = hasBudget ? budget : 0
        } else {
            let trimmed = city.trimmingCharacters(in: .whitespaces)
            let st = SubTrip(
                name: trimmed,
                city: trimmed,
                startDate: startDate,
                endDate: endDate,
                budget: hasBudget ? budget : 0,
                hasBudget: hasBudget
            )
            modelContext.insert(st)
            trip.subTrips.append(st)
        }
        dismiss()
    }
}
