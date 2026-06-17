# NRSampleApp

Modern iOS reference app for the **New Relic Video Agent**. SwiftUI, iOS 15+.
Demonstrates QoE, custom attributes, multi-tracker scenarios, and integration
patterns alongside a catalog of test scenarios driven by XCUITest in CI.

This app lives only on the `internal/video-rig` branch and is **not** intended
to be merged to `master`. It is the test rig.

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

Build and run the `NRSampleApp` scheme. The app launches into a scenario menu.

## Project layout

```
NRSampleApp/
├── project.yml                    XcodeGen source of truth (.xcodeproj is generated, gitignored)
├── Podfile                        References the local agent via :path
├── NRSampleApp/
│   ├── NRSampleAppApp.swift       @main entry point
│   ├── NewRelicSetup.swift        ★ canonical NRVA wiring — copy this verbatim
│   ├── ScenarioCatalog.swift      Loads scenario manifests at startup
│   ├── LaunchArgRouter.swift      --scenario X support for XCUITest
│   └── Views/
│       ├── ScenarioMenuView.swift Manual mode: pick a scenario
│       └── EventLogOverlay.swift  Live NRVA event tap (drives test assertions)
├── scenarios/                     YAML manifests, one per scenario
└── NRSampleAppUITests/            XCUITest target
```

## Adding a scenario

1. Add `scenarios/<id>.yml` declaring the scenario (id, view, stream, cadence, expected events).
2. Add the matching SwiftUI view in `NRSampleApp/Views/`.
3. Add an XCUITest function in `NRSampleAppUITests/` that launches with `--scenario <id>` and asserts against `EventLogOverlay`.

CI on `internal/video-rig` discovers manifests automatically and runs scenarios at the cadence each manifest declares.

## Scope

See `../../../CHECKLIST.md` (root of `internal/video-rig` worktree) for the full v1 feature list and what's deferred.
