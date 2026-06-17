import Foundation

/// Loads scenario manifests bundled in the app's scenarios/ resource folder.
enum ScenarioCatalog {

    /// All scenarios bundled with this build. Each scenarios/*.json file
    /// becomes a Scenario; results are sorted by id for stable order.
    static func all() -> [Scenario] {
        guard let urls = Bundle.main.urls(
            forResourcesWithExtension: "json",
            subdirectory: "scenarios"
        ) else {
            return []
        }

        let decoder = JSONDecoder()
        return urls.compactMap { url -> Scenario? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(Scenario.self, from: data)
        }
        .sorted { $0.id < $1.id }
    }

    static func find(id: String) -> Scenario? {
        all().first { $0.id == id }
    }
}
