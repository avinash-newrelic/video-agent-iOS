import Foundation

/// Hard-coded catalog of public test streams. In a real app, this would be
/// loaded from a backend service.
enum ContentCatalog {

    static let items: [ContentItem] = [
        // FEATURED
        ContentItem(
            id: "bipbop-adv",
            title: "Apple BipBop",
            subtitle: "HLS adaptive bitrate reference stream",
            posterURL: nil,
            streamURL: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!,
            durationSecs: 600,
            isLive: false,
            section: .featured
        ),

        // LIVE
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

        // ON DEMAND
        ContentItem(
            id: "sintel",
            title: "Sintel",
            subtitle: "Open movie · Blender Foundation",
            posterURL: nil,
            streamURL: URL(string: "https://bitmovin-a.akamaihd.net/content/sintel/hls/playlist.m3u8")!,
            durationSecs: 888,
            isLive: false,
            section: .vod
        ),
        ContentItem(
            id: "tears-of-steel",
            title: "Tears of Steel",
            subtitle: "Open movie · Blender Foundation",
            posterURL: nil,
            streamURL: URL(string: "https://bitmovin-a.akamaihd.net/content/tears-of-steel/m3u8s/tears-of-steel.m3u8")!,
            durationSecs: 730,
            isLive: false,
            section: .vod
        ),
        ContentItem(
            id: "big-buck-bunny",
            title: "Big Buck Bunny",
            subtitle: "Progressive MP4 · 720p",
            posterURL: nil,
            streamURL: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!,
            durationSecs: 596,
            isLive: false,
            section: .vod
        ),
    ]

    static func items(in section: ContentItem.Section) -> [ContentItem] {
        items.filter { $0.section == section }
    }

    static func featured() -> ContentItem? {
        items.first { $0.section == .featured }
    }
}
