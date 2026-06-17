import Foundation

/// Hard-coded catalog of public test streams that work with iOS App Transport
/// Security defaults (Apple/Akamai/Google CDNs with widely-trusted certs).
///
/// Bitmovin/Akamai-hosted streams are intentionally excluded: their current
/// Cloudflare-managed certificate chain isn't trusted by stock iOS, so
/// playback fails with NSURLErrorDomain Code=-1200.
enum ContentCatalog {

    static let items: [ContentItem] = [
        // FEATURED
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
            id: "big-buck-bunny",
            title: "Big Buck Bunny",
            subtitle: "Progressive MP4 · 720p · open movie",
            posterURL: nil,
            streamURL: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!,
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

    static func items(in section: ContentItem.Section) -> [ContentItem] {
        items.filter { $0.section == section }
    }

    static func featured() -> ContentItem? {
        items.first { $0.section == .featured }
    }
}
