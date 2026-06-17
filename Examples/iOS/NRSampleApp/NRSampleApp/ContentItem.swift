import Foundation

/// One piece of streamable content in the app's catalog.
struct ContentItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let posterURL: URL?
    let streamURL: URL
    let durationSecs: Int?
    let isLive: Bool
    let section: Section

    enum Section: String, CaseIterable, Hashable {
        case featured = "Featured"
        case live     = "Live"
        case vod      = "On Demand"
    }
}
