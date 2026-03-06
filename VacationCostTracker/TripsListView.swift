import SwiftUI
import SwiftData

struct TripsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CurrencyManager.self) private var currency
    @Environment(PlaidService.self) private var plaidService

    @Query(sort: \Trip.createdAt, order: .reverse) private var allTrips: [Trip]

    @State private var showAddTrip = false
    @State private var tripToEdit: Trip?
    @State private var showArchived = false
    @State private var showPast = false
    @State private var showBankSettings = false

    private var today: Date { Calendar.current.startOfDay(for: Date()) }
    private var activeTrips: [Trip]  { allTrips.filter { !$0.isArchived && $0.endDate >= today } }
    private var pastTrips: [Trip]    { allTrips.filter { !$0.isArchived && $0.endDate < today } }
    private var archivedTrips: [Trip] { allTrips.filter { $0.isArchived } }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if allTrips.isEmpty {
                        EmptyStateView(
                            icon: "airplane",
                            title: "No trips yet",
                            message: "Plan your first adventure and start tracking every euro.",
                            actionLabel: "New Trip",
                            action: { showAddTrip = true }
                        )
                    } else {
                        tripList
                    }
                }

                FABButton(icon: "plus") {
                    showAddTrip = true
                }
                .padding(20)
            }
            .navigationTitle("My Trips")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showBankSettings = true
                    } label: {
                        Image(systemName: "building.columns.fill")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    CurrencyToggleBarButton()
                }
            }
            .sheet(isPresented: $showAddTrip) {
                AddEditTripView()
            }
            .sheet(item: $tripToEdit) { t in
                AddEditTripView(trip: t)
            }
            .sheet(isPresented: $showBankSettings) {
                NavigationStack {
                    PlaidSettingsView(plaidService: plaidService)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showBankSettings = false }
                            }
                        }
                }
            }
            .background(Color(.systemGroupedBackground))
            .onAppear {
                // Sync Plaid transactions whenever the trips list comes into view
                Task { await plaidService.sync(modelContext: modelContext) }
            }
        }
    }

    // MARK: - Trip List

    private var tripList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {

                if !activeTrips.isEmpty {
                    sectionLabel("Active")
                        .padding(.horizontal)
                    ForEach(activeTrips) { trip in
                        tripRow(trip)
                    }
                }

                if !pastTrips.isEmpty {
                    Button {
                        withAnimation(.spring(duration: 0.4)) { showPast.toggle() }
                    } label: {
                        HStack {
                            sectionLabel("Past (\(pastTrips.count))")
                            Spacer()
                            Image(systemName: showPast ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)

                    if showPast {
                        ForEach(pastTrips) { trip in
                            tripRow(trip)
                                .opacity(0.85)
                        }
                    }
                }

                if !archivedTrips.isEmpty {
                    Button {
                        withAnimation(.spring(duration: 0.4)) {
                            showArchived.toggle()
                        }
                    } label: {
                        HStack {
                            sectionLabel("Archived (\(archivedTrips.count))")
                            Spacer()
                            Image(systemName: showArchived ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)

                    if showArchived {
                        ForEach(archivedTrips) { trip in
                            tripRow(trip)
                                .opacity(0.75)
                        }
                    }
                }

                Spacer(minLength: 100)
            }
            .padding(.top, 8)
            .animation(.spring(duration: 0.4), value: showArchived)
            .animation(.spring(duration: 0.4), value: showPast)
        }
        .refreshable {
            await plaidService.sync(modelContext: modelContext)
        }
    }

    private func tripRow(_ trip: Trip) -> some View {
        NavigationLink(destination: TripDetailView(trip: trip)) {
            TripCardView(trip: trip)
                .padding(.horizontal)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit") { tripToEdit = trip }
            Button(trip.isArchived ? "Unarchive" : "Archive") {
                HapticManager.impact(.light)
                withAnimation { trip.isArchived.toggle() }
            }
            Divider()
            Button("Delete", role: .destructive) { deleteTrip(trip) }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                deleteTrip(trip)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                tripToEdit = trip
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading) {
            Button {
                HapticManager.impact(.light)
                withAnimation { trip.isArchived.toggle() }
            } label: {
                Label(
                    trip.isArchived ? "Unarchive" : "Archive",
                    systemImage: trip.isArchived ? "tray.and.arrow.up" : "archivebox"
                )
            }
            .tint(.orange)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.uppercaseSmallCaps())
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Delete

    private func deleteTrip(_ trip: Trip) {
        HapticManager.impact(.medium)
        withAnimation {
            modelContext.delete(trip)
        }
    }
}

// MARK: - Trip Card View

struct TripCardView: View {
    @Environment(CurrencyManager.self) private var currency
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: icon + name + dates + live badge
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.22))
                        .frame(width: 50, height: 50)
                    Image(systemName: trip.emoji)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(trip.name)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                    if !trip.destination.isEmpty {
                        Text(trip.destination)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 5) {
                    if trip.isCurrent {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(.green)
                                .frame(width: 7, height: 7)
                            Text("Live")
                                .font(.caption2.bold())
                        }
                        .foregroundStyle(.white)
                    }
                    Text(trip.dateRangeString)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.72))
                }
            }

            Spacer(minLength: 22)

            // Spending amounts
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(currency.format(trip.totalSpentCalc))
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("of \(currency.format(trip.budget))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.70))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(currency.format(max(trip.budget - trip.totalSpentCalc, 0)))
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Text("remaining")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.70))
                }
            }

            AnimatedProgressBar(
                progress: trip.progressCalc,
                height: 5,
                fillColor: .white,
                trackColor: .white.opacity(0.25)
            )
            .padding(.top, 10)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [trip.accentColor, trip.accentColor.opacity(0.68)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: trip.accentColor.opacity(0.30), radius: 14, x: 0, y: 5)
    }
}
