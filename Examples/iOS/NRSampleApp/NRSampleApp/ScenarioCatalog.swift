import Foundation

/// One scenario the app can run. Loaded from a YAML manifest in scenarios/.
struct Scenario: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let cadence: Cadence

    enum Cadence: String, Codable {
        case hourly
        case sixHourly = "six-hourly"
        case daily
    }
}

/// Source of truth for scenarios available in this build.
enum ScenarioCatalog {

    /// All scenarios bundled with the app. Empty in the skeleton commit;
    /// fills in as scenario manifests are added under scenarios/.
    static func all() -> [Scenario] {
        // TODO: enumerate Bundle.main URLs for "*.yml" under the scenarios/
        // resource directory, parse each into a Scenario via a YAML decoder.
        // Until the first scenario is added, return empty.
        []
    }

    static func find(id: String) -> Scenario? {
        all().first { $0.id == id }
    }
}
