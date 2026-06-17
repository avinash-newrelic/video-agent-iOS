import Foundation

/// Hard-coded catalog of public test streams. Extra streams can be appended
/// at runtime by setting the `PLAYBACK_EXTRA_STREAMS` environment variable
/// to a JSON array of ContentItem objects:
///
///   [
///     { "id": "my-test", "title": "...", "subtitle": "...",
///       "streamURL": "https://...", "isLive": false,
///       "section": "vod", "posterURL": null, "durationSecs": null }
///   ]
///
/// Set in Xcode scheme env vars locally, or via GitHub Actions vars/inputs
/// in CI. `scripts/run-playback.sh` forwards the env into the simulator.
enum ContentCatalog {

    static let hardcoded: [ContentItem] = [
        ContentItem(
            id: "bipbop-adv",
            title: "Apple BipBop",
            subtitle: "HLS adaptive bitrate · iOS reference stream",
            posterURL: nil,
            streamURL: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!,
            durationSecs: 600,
            isLive: false,
            section: .featured
        ),
        ContentItem(
            id: "akamai-live",
            title: "Akamai Live",
            subtitle: "24/7 HLS test stream",
            posterURL: nil,
            streamURL: URL(string: "https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8")!,
            durationSecs: nil,
            isLive: true,
            section: .live
        ),
        ContentItem(
            id: "big-buck-bunny",
            title: "Big Buck Bunny",
            subtitle: "Progressive H.264 · 720p · open movie (Blender)",
            posterURL: nil,
            streamURL: URL(string: "https://download.blender.org/peach/bigbuckbunny_movies/big_buck_bunny_720p_h264.mov")!,
            durationSecs: 596,
            isLive: false,
            section: .vod
        ),
        ContentItem(
            id: "bipbop-basic",
            title: "BipBop Basic",
            subtitle: "HLS · single bitrate variant",
            posterURL: nil,
            streamURL: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8")!,
            durationSecs: 60,
            isLive: false,
            section: .vod
        ),
    ]

    /// Hardcoded catalog plus any items injected via PLAYBACK_EXTRA_STREAMS.
    /// Computed on each access (cheap; <10 items typically) so the env var
    /// can be set after app start in tests if needed.
    static var items: [ContentItem] {
        hardcoded + extras()
    }

    static func items(in section: ContentItem.Section) -> [ContentItem] {
        items.filter { $0.section == section }
    }

    static func featured() -> ContentItem? {
        items.first { $0.section == .featured }
    }

    // MARK: - Runtime extras

    private static func extras() -> [ContentItem] {
        guard let raw = ProcessInfo.processInfo.environment["PLAYBACK_EXTRA_STREAMS"],
              !raw.isEmpty,
              let data = raw.data(using: .utf8) else {
            return []
        }
        do {
            return try JSONDecoder().decode([ContentItem].self, from: data)
        } catch {
            print("[ContentCatalog] PLAYBACK_EXTRA_STREAMS parse error: \(error)")
            return []
        }
    }
}
