import Foundation
import AVFoundation
import NewRelicVideoCore

// CANONICAL: copy this file verbatim into your own iOS app.
//
// Initialization order:
//   1. Build NRVAVideoConfiguration  (token, harvest, QoE, debug)
//   2. Initialize NRVAVideo singleton via builder
//   3. Set user ID + global attributes
//   4. (Per-video) call NewRelicSetup.addAVPlayer(...) when you create
//      an AVPlayer; call releaseAVPlayer(trackerId:) when you tear down.

enum NewRelicSetup {

    /// App token from one.newrelic.com.
    /// Read from environment so it's never committed to source control.
    /// CI sets `NEW_RELIC_APP_TOKEN` via the workflow; local dev sets it via
    /// the Xcode scheme's "Arguments → Environment Variables."
    private static var appToken: String {
        ProcessInfo.processInfo.environment["NEW_RELIC_APP_TOKEN"]
            ?? "REPLACE_WITH_YOUR_APP_TOKEN"
    }

    /// Call once at app launch (e.g. from `@main App.init`).
    /// Idempotent — safe to call multiple times.
    static func start() {
        guard !NRVAVideo.isInitialized() else { return }

        // 1. Configuration. QoE aggregate is enabled by default in v4.1.x with
        //    interval multiplier 2 — harvest cadence stays in step with event
        //    volume. Tune `withHarvestCycle:` for your traffic shape.
        let config = NRVAVideoConfiguration.builder()
            .withApplicationToken(appToken)
            .withQoeAggregateEnabled(true)
            .withQoeAggregateIntervalMultiplier(2)
            .withDebugLogging(true)              // off for production
            .build()

        // 2. Initialize the singleton via the builder.
        _ = NRVAVideo.newBuilder()
            .withConfiguration(config)
            .build()

        // 3. Per-session global attributes — appear on every event.
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            NRVAVideo.setGlobalAttribute("appVersion", value: version)
        }
        NRVAVideo.setGlobalAttribute("environment", value: "test")

        // 4. Stable user ID for cross-event correlation in NRQL.
        //    UserDefaults is fine for a sample app; use Keychain in production.
        NRVAVideo.setUserId(stableUserId())
    }

    /// Add an AVPlayer to be tracked. Call once per playback session.
    /// Returns the trackerId — pass it to APIs that take a trackerId
    /// (sendSeekStart:, setAttribute:, releaseTracker:).
    @discardableResult
    static func addAVPlayer(_ player: AVPlayer,
                            name: String,
                            adEnabled: Bool = false,
                            customAttributes: [String: Any] = [:]) -> Int {
        let config = NRVAVideoPlayerConfiguration(
            playerName: name,
            player: player,
            adEnabled: adEnabled,
            customAttributes: customAttributes
        )
        return NRVAVideo.addPlayer(config)
    }

    /// Release a previously added player tracker.
    static func releaseAVPlayer(trackerId: Int) {
        NRVAVideo.releaseTracker(trackerId)
    }

    // MARK: - Internal helpers

    private static let userIdKey = "NRSampleApp.UserId"

    private static func stableUserId() -> String {
        if let existing = UserDefaults.standard.string(forKey: userIdKey) {
            return existing
        }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: userIdKey)
        return new
    }
}
