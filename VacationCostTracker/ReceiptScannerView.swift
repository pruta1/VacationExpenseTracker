import SwiftUI
import VisionKit
import Vision

// MARK: - Scanned Receipt Result

struct ScannedReceipt {
    var amount: Double?
    var merchant: String?
    var suggestedCategory: ExpenseCategory?
    var date: Date?
}

// MARK: - Shared Receipt Processor

struct ReceiptProcessor {
    /// Runs Vision OCR on a CGImage and returns a parsed ScannedReceipt.
    static func process(cgImage: CGImage) async -> ScannedReceipt {
        let lines = await recognizeText(in: cgImage)
        return parseLines(lines)
    }

    static nonisolated func recognizeText(in cgImage: CGImage) async -> [String] {
        await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
            return (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
        }.value
    }

    static func parseLines(_ lines: [String]) -> ScannedReceipt {
        var receipt = ScannedReceipt()
        receipt.merchant = lines.first {
            let t = $0.trimmingCharacters(in: .whitespaces)
            return !t.isEmpty && !(t.first?.isNumber ?? true)
        }
        let pattern = #"(?:[\$€£]\s*)?(\d{1,6}[.,]\d{2})(?!\d)"#
        var amounts: [Double] = []
        for line in lines {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let nsLine = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
            for m in matches {
                if let range = Range(m.range(at: 1), in: line) {
                    let s = String(line[range]).replacingOccurrences(of: ",", with: ".")
                    if let v = Double(s) { amounts.append(v) }
                }
            }
        }
        receipt.amount = amounts.max()
        receipt.suggestedCategory = detectCategory(from: lines)
        receipt.date = extractDate(from: lines)
        return receipt
    }

    static func extractDate(from lines: [String]) -> Date? {
        let text = lines.joined(separator: " ")
        let now = Date()
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: now) ?? now

        // (regex pattern, candidate date formats to try)
        let candidates: [(String, [String])] = [
            (#"\b(\d{4}-\d{2}-\d{2})\b"#,          ["yyyy-MM-dd"]),
            (#"\b(\d{2}/\d{2}/\d{4})\b"#,           ["dd/MM/yyyy", "MM/dd/yyyy"]),
            (#"\b(\d{2}-\d{2}-\d{4})\b"#,           ["dd-MM-yyyy", "MM-dd-yyyy"]),
            (#"\b(\d{2}\.\d{2}\.\d{4})\b"#,         ["dd.MM.yyyy"]),
            (#"\b(\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4})\b"#, ["d MMMM yyyy", "d MMM yyyy"]),
            (#"\b([A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4})\b"#, ["MMMM d, yyyy", "MMM d, yyyy",
                                                              "MMMM d yyyy",  "MMM d yyyy"]),
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for (pattern, formats) in candidates {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let nsText = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                guard let range = Range(match.range(at: 1), in: text) else { continue }
                let dateStr = String(text[range])
                for format in formats {
                    formatter.dateFormat = format
                    if let d = formatter.date(from: dateStr), d <= now, d >= twoYearsAgo {
                        return d
                    }
                }
            }
        }
        return nil
    }

    static func detectCategory(from lines: [String]) -> ExpenseCategory {
        let text = lines.joined(separator: " ").lowercased()

        // Each rule: (keywords, category, weight per hit)
        let rules: [(keywords: [String], category: ExpenseCategory, weight: Int)] = [
            // Transportation
            (["airline", "airways", "boarding pass", "flight", "e-ticket",
              "lufthansa", "ryanair", "easyjet", "wizz", "norwegian",
              "rent a car", "car rental", "hertz", "avis", "europcar", "sixt", "alamo",
              "taxi", "cab ", "uber", "lyft", "bolt", "grab",
              "metro", "subway", "underground", "tram", "bus ticket", "train ticket",
              "rail", "ferry", "eurostar", "transport", "transit",
              "parking", "toll ", "petrol", "fuel", "gas station"], .transportation, 2),

            // Accommodation
            (["hotel", "hostel", "auberge", "albergo", "pension", "b&b", "bed and breakfast",
              "guesthouse", "inn ", "resort", "villa", "airbnb", "booking.com",
              "check-in", "check-out", "room rate", "nightly rate", "nights stay"], .accommodation, 2),

            // Food & Drink
            (["restaurant", "ristorante", "trattoria", "osteria", "pizzeria", "bistro",
              "brasserie", "diner", "steak", "sushi", "grill", "taverna", "noodle", "ramen",
              "cafe", "café", "caffe", "coffee", "espresso", "bakery", "boulangerie",
              "croissant", "sandwich", "brunch", "smoothie", "donut",
              "bar ", "pub ", "tavern", "nightclub", "cocktail", "beer", "wine list",
              "menu", "waiter", "tip ", "service charge", "gratuity",
              "mcdonald", "kfc", "burger", "pizza hut", "subway", "starbucks"], .food, 2),

            // Events & Activities
            (["museum", "musée", "gallery", "exhibition", "monument", "castle",
              "guided tour", "admission ticket", "entry fee", "entrance fee",
              "zoo", "aquarium", "theme park", "amusement", "safari",
              "snorkel", "diving", "ski pass", "bowling", "escape room",
              "cinema", "movie", "concert", "show ticket", "excursion",
              "adventure", "spa ", "wellness", "fitness"], .events, 2),

            // Shopping
            (["souvenir", "gift shop", "boutique", "clothing", "apparel",
              "fashion", "shoes", "accessories", "jewellery", "jewelry",
              "supermarket", "grocery", "department store", "outlet",
              "market", "bazaar", "mall", "pharmacy", "drugstore",
              "sim card", "mobile data", "roaming"], .shopping, 1),
        ]

        // Score each category and pick the highest
        var scores: [ExpenseCategory: Int] = [:]
        for rule in rules {
            let hits = rule.keywords.filter { text.contains($0) }.count
            if hits > 0 {
                scores[rule.category, default: 0] += hits * rule.weight
            }
        }

        return scores.max(by: { $0.value < $1.value })?.key ?? .other
    }
}

// MARK: - Scanner Representable

struct ReceiptScannerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onScanComplete: (ScannedReceipt) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var parent: ReceiptScannerView

        init(parent: ReceiptScannerView) {
            self.parent = parent
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.isPresented = false
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            parent.isPresented = false
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            guard scan.pageCount > 0, let cgImage = scan.imageOfPage(at: 0).cgImage else {
                parent.isPresented = false
                return
            }
            processImage(cgImage)
        }

        // MARK: - OCR Processing

        private func processImage(_ cgImage: CGImage) {
            Task { [weak self] in
                guard let self else { return }
                let receipt = await ReceiptProcessor.process(cgImage: cgImage)
                self.parent.onScanComplete(receipt)
                self.parent.isPresented = false
            }
        }
    }
}
