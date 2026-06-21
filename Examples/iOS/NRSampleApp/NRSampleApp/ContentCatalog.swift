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
        // -- Scripted scenarios (Wave 1+) --
        // Each runs the player through a defined sequence of actions to fire
        // every NRVA event type: CONTENT_PAUSE, RESUME, SEEK_*, END (via
        // near-end seek), RENDITION_CHANGE, ERROR, plus AD_* via IMA.
        ContentItem(
            id: "content-hls-lifecycle",
            title: "Content Lifecycle (HLS)",
            subtitle: "Scripted: play → pause → resume → seek mid → seek end → done",
            posterURL: nil,
            streamURL: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!,
            durationSecs: 600,
            isLive: false,
            section: .featured,
            imaTagURL: nil,
            actionScript: [
                PlayerAction(t:  0, "play"),
                PlayerAction(t:  5, "pause"),
                PlayerAction(t:  7, "play"),
                PlayerAction(t: 10, "seek_pct", "50"),
                PlayerAction(t: 14, "seek_end_offset", "2"),
                PlayerAction(t: 20, "done"),
            ]
        ),
        ContentItem(
            id: "content-mp4-lifecycle",
            title: "Content Lifecycle (Progressive MP4)",
            subtitle: "Same script as HLS, MP4 source — exercises non-HLS AVPlayer codepath",
            posterURL: nil,
            streamURL: URL(string: "https://download.blender.org/peach/bigbuckbunny_movies/big_buck_bunny_720p_h264.mov")!,
            durationSecs: 596,
            isLive: false,
            section: .vod,
            imaTagURL: nil,
            actionScript: [
                PlayerAction(t:  0, "play"),
                PlayerAction(t:  5, "pause"),
                PlayerAction(t:  7, "play"),
                PlayerAction(t: 10, "seek_pct", "50"),
                PlayerAction(t: 14, "seek_end_offset", "2"),
                PlayerAction(t: 20, "done"),
            ]
        ),
        ContentItem(
            id: "content-error",
            title: "Content Error Path",
            subtitle: "Unresolvable URL — fires CONTENT_ERROR event",
            posterURL: nil,
            streamURL: URL(string: "https://does-not-resolve.example.invalid/foo.m3u8")!,
            durationSecs: nil,
            isLive: false,
            section: .vod,
            imaTagURL: nil,
            actionScript: [
                PlayerAction(t: 0, "play"),
                PlayerAction(t: 8, "done"),
            ]
        ),
        ContentItem(
            id: "ad-vmap-lifecycle",
            title: "Ad VMAP Lifecycle",
            subtitle: "Pre + mid + post pods · fires every AD_* event",
            posterURL: nil,
            streamURL: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!,
            durationSecs: 600,
            isLive: false,
            section: .vod,
            imaTagURL: URL(string: "https://pubads.g.doubleclick.net/gampad/ads?iu=/21775744923/external/vmap_ad_samples&sz=640x480&cust_params=sample_ar%3Dpremidpost&ciu_szs=300x250&gdfp_req=1&ad_rule=1&output=vmap&unviewed_position_start=1&env=vp&impl=s&correlator="),
            actionScript: [
                PlayerAction(t:  0, "play"),
                PlayerAction(t: 45, "done"),
            ]
        ),
        ContentItem(
            id: "ad-error",
            title: "Ad Error Fallback",
            subtitle: "Invalid VAST URL — fires AD_ERROR, content plays via fallback",
            posterURL: nil,
            streamURL: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!,
            durationSecs: 600,
            isLive: false,
            section: .vod,
            imaTagURL: URL(string: "https://does-not-resolve.example.invalid/vast.xml"),
            actionScript: [
                PlayerAction(t:  0, "play"),
                PlayerAction(t: 12, "done"),
            ]
        ),

        // -- Passive playback scenarios (legacy, kept for local testing) --
        ContentItem(
            id: "bipbop-adv",
            title: "Apple BipBop",
            subtitle: "HLS adaptive bitrate · TS segments · iOS reference stream",
            posterURL: nil,
            streamURL: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!,
            durationSecs: 600,
            isLive: false,
            section: .vod,
            imaTagURL: nil,
            actionScript: nil
        ),
        ContentItem(
            id: "mux-tears-of-steel",
            title: "Tears of Steel (Mux)",
            subtitle: "HLS adaptive · 12 renditions · alt CDN",
            posterURL: nil,
            streamURL: URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!,
            durationSecs: 734,
            isLive: false,
            section: .vod,
            imaTagURL: nil,
            actionScript: nil
        ),
        ContentItem(
            id: "big-buck-bunny",
            title: "Big Buck Bunny",
            subtitle: "Progressive H.264 · 720p · open movie (Blender)",
            posterURL: nil,
            streamURL: URL(string: "https://download.blender.org/peach/bigbuckbunny_movies/big_buck_bunny_720p_h264.mov")!,
            durationSecs: 596,
            isLive: false,
            section: .vod,
            imaTagURL: nil,
            actionScript: nil
        ),
        ContentItem(
            id: "sintel-mp4",
            title: "Sintel",
            subtitle: "Progressive MP4 · 1080p · open movie (Blender)",
            posterURL: nil,
            streamURL: URL(string: "https://download.blender.org/durian/movies/sintel-1024-surround.mp4")!,
            durationSecs: 888,
            isLive: false,
            section: .vod,
            imaTagURL: nil,
            actionScript: nil
        ),
        ContentItem(
            id: "mux-discontinuity",
            title: "Discontinuity Stream",
            subtitle: "HLS with EXT-X-DISCONTINUITY tags · NRVA stress test",
            posterURL: nil,
            streamURL: URL(string: "https://test-streams.mux.dev/dai-discontinuity-deltatre/manifest.m3u8")!,
            durationSecs: nil,
            isLive: false,
            section: .vod,
            imaTagURL: nil,
            actionScript: nil
        ),

        // -- VOD with ads (Google IMA test tags) --
        ContentItem(
            id: "ima-preroll",
            title: "IMA Pre-roll",
            subtitle: "Google IMA · single skippable pre-roll ad",
            posterURL: nil,
            streamURL: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!,
            durationSecs: 600,
            isLive: false,
            section: .vod,
            imaTagURL: URL(string: "https://pubads.g.doubleclick.net/gampad/ads?iu=/21775744923/external/single_preroll_skippable&sz=640x480&ciu_szs=300x250&gdfp_req=1&output=vast&unviewed_position_start=1&env=vp&impl=s&correlator="),
            actionScript: nil
        ),
        ContentItem(
            id: "ima-vmap",
            title: "IMA VMAP",
            subtitle: "Google IMA · pre + mid + post ad pods (VMAP)",
            posterURL: nil,
            streamURL: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!,
            durationSecs: 600,
            isLive: false,
            section: .vod,
            imaTagURL: URL(string: "https://pubads.g.doubleclick.net/gampad/ads?iu=/21775744923/external/vmap_ad_samples&sz=640x480&cust_params=sample_ar%3Dpremidpost&ciu_szs=300x250&gdfp_req=1&ad_rule=1&output=vmap&unviewed_position_start=1&env=vp&impl=s&correlator="),
            actionScript: nil
        ),
        ContentItem(
            id: "ima-error",
            title: "IMA Error Fallback",
            subtitle: "Google IMA · invalid VAST URL · exercises error path + content fallback",
            posterURL: nil,
            streamURL: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!,
            durationSecs: 600,
            isLive: false,
            section: .vod,
            imaTagURL: URL(string: "https://does-not-resolve.example.invalid/vast.xml"),
            actionScript: nil
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
