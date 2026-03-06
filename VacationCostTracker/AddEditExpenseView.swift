import SwiftUI
import SwiftData
import VisionKit
import PhotosUI

enum ExpenseContext {
    case trip(Trip)
    case subTrip(SubTrip)
}

struct AddEditExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CurrencyManager.self) private var currencyManager

    let context: ExpenseContext
    var expense: Expense? // nil = create, non-nil = edit

    @State private var amountText = ""
    @State private var currency: Currency = .eur
    @State private var category: ExpenseCategory = .other
    @State private var merchant = ""
    @State private var notes = ""
    @State private var date = Date()
    @State private var purchaseCity = ""
    @State private var showScanner = false
    @State private var scannerUnavailableAlert = false
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var isProcessingPhoto = false
    @State private var splitCount: Int = 1

    private var isEditing: Bool { expense != nil }
    private var isValid: Bool { (Double(amountText) ?? 0) > 0 }
    private var totalAmount: Double { Double(amountText) ?? 0 }
    private var perPersonAmount: Double { splitCount > 1 ? totalAmount / Double(splitCount) : totalAmount }

    var body: some View {
        NavigationStack {
            Form {
                amountSection
                categorySection
                detailsSection
                scannerSection
            }
            .navigationTitle(isEditing ? "Edit Expense" : "Add Expense")
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
            .onAppear { populate() }
            .fullScreenCover(isPresented: $showScanner) {
                ReceiptScannerView(isPresented: $showScanner) { scanned in
                    applyScan(scanned)
                }
                .ignoresSafeArea()
            }
            .alert("Camera Not Available", isPresented: $scannerUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Receipt scanning requires a camera. Add NSCameraUsageDescription to your app's Info.plist to enable this feature.")
            }
        }
    }

    // MARK: - Form Sections

    private var amountSection: some View {
        Section {
            HStack(spacing: 12) {
                Picker("", selection: $currency) {
                    ForEach(Currency.allCases) { c in
                        Text(c.symbol + " " + c.rawValue).tag(c)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(.title2.bold())
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 4)

            HStack {
                Text("Split between")
                    .foregroundStyle(.secondary)
                Spacer()
                Stepper("\(splitCount) \(splitCount == 1 ? "person" : "people")",
                        value: $splitCount, in: 1...20)
                    .fixedSize()
            }

            if splitCount > 1 && totalAmount > 0 {
                HStack {
                    Text("Your share")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(currency.symbol)\(String(format: "%.2f", perPersonAmount))")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.accentColor)
                }
            }
        } header: {
            Text("Amount")
        } footer: {
            if splitCount > 1 {
                Text("Enter the full bill — your share (\(currency.symbol)\(String(format: "%.2f", perPersonAmount))) will be saved.")
                    .font(.caption)
            }
        }
    }

    private var categorySection: some View {
        Section {
            Picker("Category", selection: $category) {
                ForEach(ExpenseCategory.allCases) { cat in
                    Label(cat.displayName, systemImage: cat.symbolName).tag(cat)
                }
            }
        } header: {
            Text("Category")
        }
    }

    private var detailsSection: some View {
        Section {
            TextField("Merchant / Description", text: $merchant)
            TextField("Notes", text: $notes)
            DatePicker("Date", selection: $date, displayedComponents: .date)
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle")
                    .foregroundStyle(.secondary)
                TextField("City (optional)", text: $purchaseCity)
            }
        } header: {
            Text("Details (Optional)")
        }
    }

    private var scannerSection: some View {
        Section {
            Button { openScanner() } label: {
                Label("Scan Receipt", systemImage: "doc.viewfinder.fill")
                    .foregroundStyle(Color.accentColor)
            }
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Import from Photos", systemImage: "photo.on.rectangle")
                    .foregroundStyle(Color.accentColor)
            }
            .onChange(of: selectedPhoto) { _, newItem in
                guard let newItem else { return }
                processPhotoItem(newItem)
            }
            if isProcessingPhoto {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Processing receipt…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("Scans automatically fill in amount, merchant, date, and suggest a category.")
                .font(.caption)
        }
    }

    // MARK: - Helpers

    private func openScanner() {
        guard VNDocumentCameraViewController.isSupported else {
            scannerUnavailableAlert = true
            return
        }
        showScanner = true
    }

    private func applyScan(_ receipt: ScannedReceipt) {
        if let a = receipt.amount {
            amountText = String(format: "%.2f", a)
        }
        if let m = receipt.merchant, !m.isEmpty {
            merchant = m
        }
        if let cat = receipt.suggestedCategory {
            category = cat
        }
        if let d = receipt.date {
            date = d
        }
        HapticManager.success()
    }

    private func processPhotoItem(_ item: PhotosPickerItem) {
        isProcessingPhoto = true
        Task {
            defer {
                isProcessingPhoto = false
                selectedPhoto = nil
            }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data),
                  let cgImage = uiImage.cgImage else { return }
            let receipt = await ReceiptProcessor.process(cgImage: cgImage)
            applyScan(receipt)
        }
    }

    private func populate() {
        guard let e = expense else {
            // Default to the display currency when creating a new expense
            currency = currencyManager.displayCurrency
            return
        }
        amountText = e.amount.formattedAmount
        currency = e.originalCurrency
        category = e.category
        merchant = e.merchant
        notes = e.notes
        date = e.date
        purchaseCity = e.purchaseCity ?? ""
    }

    private func save() {
        guard let amount = Double(amountText), amount > 0 else { return }
        HapticManager.success()
        let savedAmount = splitCount > 1 ? amount / Double(splitCount) : amount

        if let e = expense {
            e.amount = savedAmount
            e.originalCurrency = currency
            e.category = category
            e.merchant = merchant
            e.notes = notes
            e.date = date
            e.purchaseCity = purchaseCity.isEmpty ? nil : purchaseCity
        } else {
            let e = Expense(
                amount: savedAmount,
                originalCurrency: currency,
                category: category,
                merchant: merchant,
                notes: notes,
                date: date,
                purchaseCity: purchaseCity.isEmpty ? nil : purchaseCity
            )
            modelContext.insert(e)
            switch context {
            case .subTrip(let st):
                st.expenses.append(e)
                if st.hasBudget && st.progressCalc >= 0.9 {
                    HapticManager.warning()
                }
            case .trip(let t):
                t.expenses.append(e)
            }
        }
        dismiss()
    }
}
