import SwiftUI

// MARK: - Exchange Rates
// Update eurToUsdRate to the current market rate as needed.
enum Constants {
    /// 1 EUR expressed in USD
    static let eurToUsdRate: Double = 1.08
    /// 1 USD expressed in EUR
    static let usdToEurRate: Double = 1.0 / eurToUsdRate
}

// MARK: - Currency

enum Currency: String, CaseIterable, Identifiable, Codable {
    case eur = "EUR"
    case usd = "USD"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .eur: return "€"
        case .usd: return "$"
        }
    }

    var flag: String {
        switch self {
        case .eur: return "🇪🇺"
        case .usd: return "🇺🇸"
        }
    }
}

// MARK: - Trip Cover Options

enum TripCoverOption {
    static let symbols: [String] = [
        "airplane", "beach.umbrella.fill", "mountain.2.fill",
        "building.columns.fill", "globe.europe.africa.fill", "camera.fill",
        "heart.fill", "star.fill", "map.fill", "figure.hiking",
        "sailboat.fill", "tent.fill", "train.side.front.car",
        "fork.knife", "leaf.fill", "sun.max.fill",
        "snowflake", "suitcase.fill", "backpack.fill", "binoculars.fill"
    ]

    static let colorHexes: [(hex: String, label: String)] = [
        ("4A90D9", "Blue"),
        ("E8433D", "Red"),
        ("F5A623", "Orange"),
        ("5BBF5A", "Green"),
        ("BD10E0", "Purple"),
        ("1ABEA7", "Teal"),
        ("E67E22", "Amber"),
        ("9B59B6", "Violet"),
        ("E91E8C", "Pink"),
        ("607D8B", "Slate")
    ]
}
