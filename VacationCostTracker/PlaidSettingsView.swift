import SwiftUI
import SwiftData

struct PlaidSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlaidLinkedAccount.linkedAt, order: .reverse) private var linkedAccounts: [PlaidLinkedAccount]

    let plaidService: PlaidService

    @State private var showPlaidLink = false
    @State private var itemToDelete: PlaidLinkedAccount?
    @State private var showDeleteConfirm = false
    @State private var linkError: String?
    @State private var showLinkError = false

    var body: some View {
        List {
            // ── Connected Banks ───────────────────────────────────────────────
            Section {
                if linkedAccounts.isEmpty {
                    emptyBanksRow
                } else {
                    ForEach(linkedAccounts) { account in
                        bankRow(account)
                    }
                }
            } header: {
                Text("Connected Banks")
            } footer: {
                Text("Connect a bank so transactions are imported automatically whenever Plaid detects a new purchase.")
                    .font(.caption)
            }

            // ── Add Bank ──────────────────────────────────────────────────────
            Section {
                Button {
                    showPlaidLink = true
                } label: {
                    Label("Connect a Bank", systemImage: "plus.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }

            // ── Manual Sync ───────────────────────────────────────────────────
            if !linkedAccounts.isEmpty {
                Section {
                    Button {
                        Task { await plaidService.sync(modelContext: modelContext) }
                    } label: {
                        HStack {
                            Label("Sync Now", systemImage: "arrow.clockwise")
                                .foregroundStyle(Color.accentColor)
                            Spacer()
                            if plaidService.isSyncing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(plaidService.isSyncing)

                    if let last = plaidService.lastSyncDate {
                        HStack {
                            Text("Last synced")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(last, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let err = plaidService.syncError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Sync")
                } footer: {
                    Text("Transactions are auto-synced when Plaid sends a webhook. Tap \"Sync Now\" to pull the latest manually.")
                        .font(.caption)
                }
            }

            // ── How it works ──────────────────────────────────────────────────
            Section("How It Works") {
                infoRow(
                    icon: "building.columns.fill",
                    color: .blue,
                    title: "Bank Connection",
                    detail: "Plaid securely connects to your bank. Your credentials are never stored in this app or its server."
                )
                infoRow(
                    icon: "arrow.down.circle.fill",
                    color: .green,
                    title: "Auto Import",
                    detail: "New card purchases are detected within minutes and automatically matched to your active trip."
                )
                infoRow(
                    icon: "calendar.badge.checkmark",
                    color: .orange,
                    title: "Date Matching",
                    detail: "Each transaction is matched to a trip by its date. Only purchases within a trip's date range are imported."
                )
            }
        }
        .navigationTitle("Bank Connection")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPlaidLink) {
            PlaidLinkContainer(
                plaidService: plaidService,
                onSuccess: { publicToken, institutionName in
                    showPlaidLink = false
                    Task { await handleLinkSuccess(publicToken: publicToken, institutionName: institutionName) }
                },
                onExit: {
                    showPlaidLink = false
                }
            )
        }
        .confirmationDialog(
            "Remove \(itemToDelete?.institutionName ?? "bank")?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let account = itemToDelete { removeAccount(account) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Future transactions from this bank will no longer be imported.")
        }
        .alert("Bank Connection Failed", isPresented: $showLinkError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(linkError ?? "Unknown error")
        }
    }

    // MARK: - Sub-views

    private var emptyBanksRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "building.columns")
                    .foregroundStyle(.secondary)
                Text("No banks connected")
                    .foregroundStyle(.secondary)
            }
            Text("Connect a bank to start auto-importing expenses.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func bankRow(_ account: PlaidLinkedAccount) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.blue)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(account.institutionName)
                    .font(.subheadline.weight(.medium))
                Text("Connected \(account.linkedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                itemToDelete = account
                showDeleteConfirm = true
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private func infoRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
            }
            .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func handleLinkSuccess(publicToken: String, institutionName: String) async {
        print("PlaidSettingsView: onSuccess called — institution=\(institutionName) token prefix=\(publicToken.prefix(12))")
        do {
            let (itemId, name) = try await plaidService.exchangeToken(publicToken, institutionName: institutionName)
            let account = PlaidLinkedAccount(itemId: itemId, institutionName: name)
            modelContext.insert(account)
            try? modelContext.save()
            HapticManager.success()
            await plaidService.sync(modelContext: modelContext)
        } catch {
            print("PlaidSettingsView: token exchange failed — \(error)")
            linkError = error.localizedDescription
            // Short delay lets the Plaid sheet finish dismissing before we present the alert
            try? await Task.sleep(for: .milliseconds(400))
            showLinkError = true
        }
    }

    private func removeAccount(_ account: PlaidLinkedAccount) {
        Task {
            try? await plaidService.removeItem(account.itemId)
            modelContext.delete(account)
            try? modelContext.save()
        }
    }
}
