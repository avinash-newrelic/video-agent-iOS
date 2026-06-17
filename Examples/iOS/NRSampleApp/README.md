# NRSampleApp

Modern iOS video sample app. SwiftUI, iOS 15+, AVPlayer-based playback. Catalog of public test streams. **Pure AVKit — no third-party dependencies.**

This app lives only on the `internal/video-rig` branch.

## Requirements

- macOS, Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Quick start

```bash
cd Examples/iOS/NRSampleApp
xcodegen generate          # produces NRSampleApp.xcodeproj
open NRSampleApp.xcodeproj
```

Build and run the `NRSampleApp` scheme.

## What's in the app

A catalog of public test streams that all work with iOS App Transport Security defaults:

```
Watch
├── Featured       Apple BipBop (HLS adaptive)
├── Live           Akamai 24/7 test stream
└── On Demand      Big Buck Bunny (MP4) · BipBop Basic (HLS)
```

Tap a card → full-bleed `VideoPlayer` (AVKit). Native controls, AirPlay, scrub, captions all work out of the box.

## Files

```
NRSampleApp/
├── project.yml                  XcodeGen source of truth (.xcodeproj is generated, gitignored)
└── NRSampleApp/
    ├── NRSampleAppApp.swift     @main entry
    ├── ContentItem.swift        Codable model for a streamable item
    ├── ContentCatalog.swift     Hard-coded catalog of public streams
    ├── HomeView.swift           Catalog screen with hero + horizontal sections
    ├── CardView.swift           Reusable card with gradient placeholder
    └── PlayerView.swift         Full-bleed AVKit player
```

## Adding a new content item

Append a `ContentItem` to `ContentCatalog.items`, choose its `section`, run.

## Stream selection notes

iOS's default App Transport Security only accepts streams hosted on CAs in
the system trust store. Some popular public test streams (Bitmovin /
older Akamai endpoints) now use Cloudflare-managed certificates which
fail with `NSURLErrorDomain -1200`. The catalog only includes streams
that Just Work: Apple's `devstreaming-cdn.apple.com`, Google's
`commondatastorage.googleapis.com`, and Akamai's `cph-p2p-msl.akamaized.net`.
