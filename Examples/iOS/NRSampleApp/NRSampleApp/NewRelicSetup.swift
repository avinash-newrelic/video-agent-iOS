import Foundation
import AVFoundation
import NewRelicVideoCore

// CANONICAL: copy this file verbatim into your own iOS / tvOS app.
//
// Two-level NRVA configuration:
//
//   Level 1 — MAIN VIDEO CONFIGURATION (NRVAVideoConfiguration)
//   ============================================================
//   Set ONCE at app launch (`NewRelicSetup.start()` from @main App.init).
//   Configures: app token, collector address (prod / staging), harvest
//   cadence, QoE aggregate, debug logging.
//
//   Level 2 — PLAYER CONFIGURATION (NRVAVideoPlayerConfiguration)
//   =============================================================
//   Set PER PLAYBACK SESSION (`NewRelicSetup.addAVPlayer(...)` from your
//   PlayerView/PlayerModel). Configures: player name, AVPlayer instance,
//   ad-tracking on/off, custom per-session attributes.
//
// Configuration sources, in priority order:
//   1. Environment variables (CI sets these via simctl launchctl setenv,
//      local Xcode users set them in Scheme → Arguments → Environment).
//   2. Hard-coded fallback (no token = agent disabled, app still plays
//      videos with full AVKit functionality).

enum NewRelicSetup {

    // MARK: - Level 1: Main video configuration

    /// Call once at app launch (from `@main App.init`). Idempotent.
    static func start() {
        guard !NRVAVideo.isInitialized() else { return }
        guard let token = appToken() else {
            print("[NewRelicSetup] NEW_RELIC_APP_TOKEN not set — NRVA disabled.")
            return
        }

        var builder = NRVAVideoConfiguration.builder()
            .withApplicationToken(token)
            .withQoeAggregateEnabled(true)
            .withQoeAggregateIntervalMultiplier(2)
            .withDebugLogging(false)             // set true for verbose Xcode console

        // Optional: custom collector endpoint (e.g. staging).
        if let collector = collectorAddress() {
            builder = builder.withCollectorAddress(collector)
        }

        let config = builder.build()

        _ = NRVAVideo.newBuilder()
            .withConfiguration(config)
            .build()

        // Per-session global attributes — appear on every event.
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            NRVAVideo.setGlobalAttribute("appVersion", value: version)
        }
        NRVAVideo.setGlobalAttribute(
            "environment",
            value: collectorAddress() != nil ? "staging" : "production"
        )
        NRVAVideo.setUserId(stableUserId())
    }

    // MARK: - Level 2: Per-player configuration

    /// Call once per AVPlayer session (e.g., when PlayerView appears).
    /// Returns the trackerId — pass to `releaseAVPlayer(trackerId:)` on teardown
    /// and to NRVAVideo APIs that take a trackerId (sendSeekStart, etc.).
    @discardableResult
    static func addAVPlayer(_ player: AVPlayer,
                            name: String,
                            adEnabled: Bool = false,
                            customAttributes: [String: Any] = [:]) -> Int {
        guard NRVAVideo.isInitialized() else { return -1 }
        let config = NRVAVideoPlayerConfiguration(
            playerName: name,
            player: player,
            adEnabled: adEnabled,
            customAttributes: customAttributes
        )
        return NRVAVideo.addPlayer(config)
    }

    /// Call when tearing down the playback session.
    static func releaseAVPlayer(trackerId: Int) {
        guard NRVAVideo.isInitialized(), trackerId >= 0 else { return }
        NRVAVideo.releaseTracker(trackerId)
    }

    // MARK: - Configuration sources

    private static func appToken() -> String? {
        let env = ProcessInfo.processInfo.environment["NEW_RELIC_APP_TOKEN"]
        guard let env, !env.isEmpty, env != "REPLACE_WITH_YOUR_APP_TOKEN" else { return nil }
        return env
    }

    private static func collectorAddress() -> String? {
        let env = ProcessInfo.processInfo.environment["NEW_RELIC_COLLECTOR_ADDRESS"]
        guard let env, !env.isEmpty else { return nil }
        return env
    }

    // MARK: - Stable user ID

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
