import SwiftUI

/// Decides what the app shows on launch:
///   - With `--auto-play <id>` → opens directly into the player for that item
///     and logs the auto-play handoff. Used by the `playback-test.yml`
///     GitHub Actions workflow when running scripted scenarios.
///   - Otherwise → the normal `HomeView` catalog.
struct RootView: View {

    var body: some View {
        if let item = autoPlayItem() {
            NavigationView {
                playerView(for: item)
            }
            .navigationViewStyle(.stack)
            .onAppear {
                // Redirect logs to a dedicated per-scenario file so the
                // automation runner can poll just this scenario's events.
                AppLog.shared.switchToFile(named: "auto-play-\(item.id).log")
                AppLog.shared.log(.event, "AutoPlay", "launched", [
                    "id": item.id,
                    "title": item.title,
                    "isLive": item.isLive,
                ])
            }
        } else {
            HomeView()
        }
    }

    /// Pick the right player view for the scenario.
    /// IMA-flagged scenarios (imaTagURL set) route to IMAPlayerView on iOS.
    /// Everything else (and tvOS for IMA scenarios) goes through PlayerView.
    @ViewBuilder
    private func playerView(for item: ContentItem) -> some View {
        #if os(iOS)
        if item.imaTagURL != nil {
            IMAPlayerView(item: item)
        } else {
            PlayerView(item: item)
        }
        #else
        // tvOS: skip IMA wiring for now; play content only.
        PlayerView(item: item)
        #endif
    }

    /// If launched with `--auto-play <id>`, returns the matching ContentItem.
    private func autoPlayItem() -> ContentItem? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--auto-play"),
              i + 1 < args.count else { return nil }
        let id = args[i + 1]
        return ContentCatalog.items.first { $0.id == id }
    }
}
