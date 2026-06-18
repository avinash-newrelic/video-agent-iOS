import Foundation

/// One piece of streamable content in the app's catalog.
///
/// Codable so extra items can be injected at runtime via the
/// `PLAYBACK_EXTRA_STREAMS` env var (a JSON array of ContentItem objects).
struct ContentItem: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let posterURL: URL?
    let streamURL: URL
    let durationSecs: Int?
    let isLive: Bool
    let section: Section
    /// Optional Google IMA ad tag URL. When set, the app routes the
    /// scenario to `IMAPlayerView` (iOS only) which loads + plays ads
    /// via the IMA SDK and forwards every event to NRVA. nil means
    /// content-only playback through the regular `PlayerView`.
    let imaTagURL: URL?

    enum Section: String, CaseIterable, Hashable, Codable {
        case featured
        case live
        case vod

        /// Localized-style display label. The raw value stays machine-readable
        /// for JSON / env var injection.
        var displayName: String {
            switch self {
            case .featured: return "Featured"
            case .live:     return "Live"
            case .vod:      return "On Demand"
            }
        }
    }
}
