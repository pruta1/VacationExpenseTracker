import SwiftUI

// MARK: - Location Picker Field
// Drop-in replacement for a TextField that adds a searchable city/country picker sheet.
// The field is always optional — leaving it blank is valid.

struct LocationPickerField: View {
    @Binding var text: String
    var placeholder: String = "City / Country (optional)"

    @State private var showPicker = false

    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.placeholder)
                } else {
                    Text(text)
                        .foregroundStyle(.primary)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPicker) {
            LocationPickerSheet(selection: $text)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Location Picker Sheet

struct LocationPickerSheet: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss

    @State private var search = ""

    private var filtered: [String] {
        search.isEmpty
            ? LocationData.all
            : LocationData.all.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    /// Shows a "Use [typed text]" row when search text isn't an exact match
    private var showCustomEntry: Bool {
        !search.isEmpty && !LocationData.all.contains(where: {
            $0.caseInsensitiveCompare(search) == .orderedSame
        })
    }

    var body: some View {
        NavigationStack {
            List {
                if showCustomEntry {
                    Button {
                        selection = search
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentColor)
                            Text("Use \"\(search)\"")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }

                if !selection.isEmpty {
                    Button {
                        selection = ""
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                            Text("Clear selection")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ForEach(filtered, id: \.self) { (location: String) in
                    Button {
                        selection = location
                        dismiss()
                    } label: {
                        HStack {
                            Text(location)
                                .foregroundStyle(Color.primary)
                            Spacer()
                            if selection == location {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search cities & countries")
            .navigationTitle("Choose Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Location Data (~280 popular travel destinations, sorted)

enum LocationData {
    static let all: [String] = [
        // Europe
        "Amalfi, Italy",
        "Amsterdam, Netherlands",
        "Antalya, Turkey",
        "Athens, Greece",
        "Barcelona, Spain",
        "Bath, UK",
        "Belgrade, Serbia",
        "Berlin, Germany",
        "Bern, Switzerland",
        "Bilbao, Spain",
        "Bodrum, Turkey",
        "Bologna, Italy",
        "Bratislava, Slovakia",
        "Brighton, UK",
        "Bruges, Belgium",
        "Brussels, Belgium",
        "Bucharest, Romania",
        "Budapest, Hungary",
        "Cannes, France",
        "Cappadocia, Turkey",
        "Capri, Italy",
        "Cinque Terre, Italy",
        "Cologne, Germany",
        "Copenhagen, Denmark",
        "Corfu, Greece",
        "Cordoba, Spain",
        "Crete, Greece",
        "Dubrovnik, Croatia",
        "Dublin, Ireland",
        "Edinburgh, Scotland",
        "Florence, Italy",
        "Frankfurt, Germany",
        "Fuerteventura, Spain",
        "Gdansk, Poland",
        "Geneva, Switzerland",
        "Ghent, Belgium",
        "Gran Canaria, Spain",
        "Granada, Spain",
        "Hamburg, Germany",
        "Helsinki, Finland",
        "Ibiza, Spain",
        "Innsbruck, Austria",
        "Interlaken, Switzerland",
        "Istanbul, Turkey",
        "Kotor, Montenegro",
        "Krakow, Poland",
        "Lake Como, Italy",
        "Lanzarote, Spain",
        "Lisbon, Portugal",
        "Ljubljana, Slovenia",
        "London, UK",
        "Lucerne, Switzerland",
        "Luxembourg City, Luxembourg",
        "Lyon, France",
        "Madrid, Spain",
        "Malaga, Spain",
        "Mallorca, Spain",
        "Malta",
        "Manchester, UK",
        "Milan, Italy",
        "Monaco",
        "Munich, Germany",
        "Mykonos, Greece",
        "Naples, Italy",
        "Nice, France",
        "Oslo, Norway",
        "Oxford, UK",
        "Palermo, Italy",
        "Paris, France",
        "Positano, Italy",
        "Porto, Portugal",
        "Prague, Czech Republic",
        "Reykjavik, Iceland",
        "Rhodes, Greece",
        "Riga, Latvia",
        "Rome, Italy",
        "Salzburg, Austria",
        "San Sebastian, Spain",
        "Santorini, Greece",
        "Sarajevo, Bosnia",
        "Seville, Spain",
        "Sofia, Bulgaria",
        "Split, Croatia",
        "Stockholm, Sweden",
        "Tallinn, Estonia",
        "Tenerife, Spain",
        "Thessaloniki, Greece",
        "Valencia, Spain",
        "Venice, Italy",
        "Vienna, Austria",
        "Vilnius, Lithuania",
        "Warsaw, Poland",
        "Wroclaw, Poland",
        "Zakynthos, Greece",
        "Zurich, Switzerland",
        // Asia
        "Bali, Indonesia",
        "Bangkok, Thailand",
        "Beijing, China",
        "Boracay, Philippines",
        "Busan, South Korea",
        "Cebu, Philippines",
        "Chengdu, China",
        "Chiang Mai, Thailand",
        "Colombo, Sri Lanka",
        "Da Nang, Vietnam",
        "Fukuoka, Japan",
        "Hanoi, Vietnam",
        "Hiroshima, Japan",
        "Ho Chi Minh City, Vietnam",
        "Hoi An, Vietnam",
        "Hong Kong",
        "Hua Hin, Thailand",
        "Jakarta, Indonesia",
        "Jeju, South Korea",
        "Kathmandu, Nepal",
        "Koh Phangan, Thailand",
        "Koh Samui, Thailand",
        "Krabi, Thailand",
        "Kuala Lumpur, Malaysia",
        "Kyoto, Japan",
        "Langkawi, Malaysia",
        "Lombok, Indonesia",
        "Luang Prabang, Laos",
        "Macau",
        "Maldives",
        "Manila, Philippines",
        "Mumbai, India",
        "Nara, Japan",
        "New Delhi, India",
        "Nha Trang, Vietnam",
        "Okinawa, Japan",
        "Osaka, Japan",
        "Palawan, Philippines",
        "Penang, Malaysia",
        "Phuket, Thailand",
        "Sapporo, Japan",
        "Seoul, South Korea",
        "Shanghai, China",
        "Shenzhen, China",
        "Siem Reap, Cambodia",
        "Singapore",
        "Taipei, Taiwan",
        "Tokyo, Japan",
        "Xi'an, China",
        "Yangon, Myanmar",
        // Middle East & Africa
        "Abu Dhabi, UAE",
        "Addis Ababa, Ethiopia",
        "Amman, Jordan",
        "Aswan, Egypt",
        "Cairo, Egypt",
        "Cape Town, South Africa",
        "Casablanca, Morocco",
        "Dar es Salaam, Tanzania",
        "Doha, Qatar",
        "Dubai, UAE",
        "Fez, Morocco",
        "Hurghada, Egypt",
        "Johannesburg, South Africa",
        "Kuwait City, Kuwait",
        "Luxor, Egypt",
        "Marrakech, Morocco",
        "Mauritius",
        "Muscat, Oman",
        "Nairobi, Kenya",
        "Petra, Jordan",
        "Seychelles",
        "Sharm El Sheikh, Egypt",
        "Tangier, Morocco",
        "Tel Aviv, Israel",
        "Victoria Falls, Zimbabwe",
        "Zanzibar, Tanzania",
        // Americas
        "Atlanta, USA",
        "Aruba",
        "Austin, USA",
        "Barbados",
        "Bogota, Colombia",
        "Boston, USA",
        "Buenos Aires, Argentina",
        "Cabo San Lucas, Mexico",
        "Calgary, Canada",
        "Cancun, Mexico",
        "Cartagena, Colombia",
        "Chicago, USA",
        "Cusco, Peru",
        "Dallas, USA",
        "Denver, USA",
        "Havana, Cuba",
        "Honolulu, USA",
        "Houston, USA",
        "Las Vegas, USA",
        "Lima, Peru",
        "Los Angeles, USA",
        "Medellin, Colombia",
        "Mendoza, Argentina",
        "Mexico City, Mexico",
        "Miami, USA",
        "Minneapolis, USA",
        "Montevideo, Uruguay",
        "Montreal, Canada",
        "Nassau, Bahamas",
        "Nashville, USA",
        "New Orleans, USA",
        "New York, USA",
        "Oaxaca, Mexico",
        "Orlando, USA",
        "Ottawa, Canada",
        "Panama City, Panama",
        "Philadelphia, USA",
        "Phoenix, USA",
        "Playa del Carmen, Mexico",
        "Portland, USA",
        "Puerto Vallarta, Mexico",
        "Quebec City, Canada",
        "Quito, Ecuador",
        "Rio de Janeiro, Brazil",
        "Salt Lake City, USA",
        "San Diego, USA",
        "San Francisco, USA",
        "San Jose, Costa Rica",
        "San Juan, Puerto Rico",
        "Santiago, Chile",
        "Sao Paulo, Brazil",
        "Seattle, USA",
        "Toronto, Canada",
        "Tulum, Mexico",
        "Valparaiso, Chile",
        "Vancouver, Canada",
        "Washington DC, USA",
        // Pacific & Oceania
        "Adelaide, Australia",
        "Auckland, New Zealand",
        "Bora Bora, French Polynesia",
        "Brisbane, Australia",
        "Cairns, Australia",
        "Christchurch, New Zealand",
        "Darwin, Australia",
        "Fiji",
        "Gold Coast, Australia",
        "Hobart, Australia",
        "Melbourne, Australia",
        "Perth, Australia",
        "Queenstown, New Zealand",
        "Sydney, Australia",
        "Tahiti, French Polynesia",
        "Wellington, New Zealand",
    ].sorted()
}
