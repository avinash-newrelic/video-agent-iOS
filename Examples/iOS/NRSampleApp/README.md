# NRSampleApp

Modern iOS reference app for the **New Relic Video Agent**. SwiftUI, iOS 15+, AVPlayer-based playback. Demonstrates how to wire the agent into a real video app using public test streams.

This app lives only on the `internal/video-rig` branch and is not merged to `master`.

## Requirements

- macOS, Xcode 15+
- CocoaPods
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Quick start

```bash
cd Examples/iOS/NRSampleApp
xcodegen generate          # produces NRSampleApp.xcodeproj
pod install                # produces NRSampleApp.xcworkspace
open NRSampleApp.xcworkspace
```

Set `NEW_RELIC_APP_TOKEN` in the Xcode scheme's Environment Variables before running. Then build and run the `NRSampleApp` scheme.

## What's in the app

A catalog of public test streams across HLS VOD, HLS Live, and progressive MP4. Tap a card to open the player. Each playback session is tracked by NRVA via `NewRelicSetup.addAVPlayer(...)`.

```
Watch
├── Featured       Apple BipBop (hero card)
├── Live           Akamai 24/7 test stream
└── On Demand      Sintel · Tears of Steel · Big Buck Bunny
```

## Files

```
NRSampleApp/
├── project.yml                  XcodeGen source of truth (.xcodeproj is generated, gitignored)
├── Podfile                      References the local agent via :path
└── NRSampleApp/
    ├── NRSampleAppApp.swift     @main entry — calls NewRelicSetup.start()
    ├── NewRelicSetup.swift      ★ canonical NRVA wiring — copy this verbatim
    ├── ContentItem.swift        Codable model for a streamable item
    ├── ContentCatalog.swift     Hard-coded catalog of public test streams
    ├── HomeView.swift           Catalog screen with hero + horizontal sections
    ├── CardView.swift           Reusable card with gradient placeholder
    └── PlayerView.swift         Full-bleed AVKit player + NRVA tracking
```

## Adding a new content item

1. Append a `ContentItem` to `ContentCatalog.items`.
2. Choose its `section` (`.featured` / `.live` / `.vod`).
3. Run.

## Notes

- All streams are public. Replace with your own when integrating into a real app.
- Poster art uses generated gradients; supply a `posterURL` to use a real thumbnail.
- The Podfile uses `:path => '../../../'` so any change to the agent's source is picked up by the next `pod install`.
