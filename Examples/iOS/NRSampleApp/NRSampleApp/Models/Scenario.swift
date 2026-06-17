import Foundation

/// One scenario the app can run. Loaded from a JSON manifest in scenarios/.
struct Scenario: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let summary: String
    let cadence: Cadence
    let streamUrl: URL
    let expectedDurationSecs: Int
    let expectedEvents: [String]

    enum Cadence: String, Codable, Hashable {
        case hourly
        case sixHourly = "six-hourly"
        case daily
    }
}
