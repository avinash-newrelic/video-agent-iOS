import Foundation
import AVFoundation
import NewRelicVideoCore

// CANONICAL: copy this file verbatim into your own iOS / tvOS app.
//
// Two-level NRVA configuration:
//
//   Level 1 — MAIN VIDEO CONFIGURATION (NRVAVideoConfiguration)
//   Set ONCE at app launch (`NewRelicSetup.start()` from @main App.init).
//
//   Level 2 — PLAYER CONFIGURATION (NRVAVideoPlayerConfiguration)
//   Set PER PLAYBACK SESSION (`NewRelicSetup.addAVPlayer(...)`).
//
// All NRVA knobs are configurable via environment variables. Set them in
// the Xcode scheme (local) or via GitHub Actions vars/secrets (CI).
// `scripts/run-playback.sh` forwards env vars into the simulator's launchd
// before each launch, so the app process inherits them.

enum NewRelicSetup {

    // MARK: - Level 1: Main video configuration

    /// Call once at app launch. Idempotent.
    static func start() {
        guard !NRVAVideo.isInitialized() else { return }
        guard let token = appToken() else {
            print("[NewRelicSetup] NEW_RELIC_APP_TOKEN not set — NRVA disabled.")
            return
        }

        // NRVA's headers don't have NS_ASSUME_NONNULL_BEGIN, so Swift
        // imports each builder method as returning Optional. Use ?-chaining
        // and guard at the end.
        guard var b = NRVAVideoConfiguration.builder()?
            .withApplicationToken(token)?
            .withQoeAggregateEnabled(qoeEnabled())?
            .withQoeAggregateIntervalMultiplier(qoeMultiplier())?
            .withHarvestCycle(harvestCycleSecs())?
            .withLiveHarvestCycle(liveHarvestCycleSecs())?
            .withDebugLogging(debugLogging())?
            .withMemoryOptimization(memoryOptimization())?
            .withRegularBatchSize(regularBatchSizeBytes())?
            .withLiveBatchSize(liveBatchSizeBytes())?
            .withMaxDeadLetterSize(maxDeadLetterSize())?
            .withMaxOfflineStorageSize(maxOfflineStorageMB())
        else {
            print("[NewRelicSetup] failed to build NRVA configuration")
            return
        }

        if let collector = collectorAddress(), let withCol = b.withCollectorAddress(collector) {
            b = withCol
        }

        guard let config = b.build() else {
            print("[NewRelicSetup] failed to build NRVA configuration")
            return
        }

        _ = NRVAVideo.newBuilder()
            .withConfiguration(config)
            .build()

        // Don't echo collector address or any token-derived value — these
        // appear in CI artifacts on a public repo. State only: set / default.
        print("""
            [NewRelicSetup] started · harvest=\(harvestCycleSecs())s · liveHarvest=\(liveHarvestCycleSecs())s · \
            debug=\(debugLogging()) · memOpt=\(memoryOptimization()) · \
            qoe=\(qoeEnabled())x\(qoeMultiplier()) · collector=\(collectorAddress() != nil ? "(custom-set)" : "(default)")
            """)

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

    @discardableResult
    static func addAVPlayer(_ player: AVPlayer,
                            name: String,
                            adEnabled: Bool = false,
                            customAttributes: [String: Any] = [:]) -> Int {
        guard NRVAVideo.isInitialized() else { return -1 }
        let cfg = NRVAVideoPlayerConfiguration(
            playerName: name,
            player: player,
            adEnabled: adEnabled,
            customAttributes: customAttributes
        )
        return NRVAVideo.addPlayer(cfg)
    }

    static func releaseAVPlayer(trackerId: Int) {
        guard NRVAVideo.isInitialized(), trackerId >= 0 else { return }
        NRVAVideo.releaseTracker(trackerId)
    }

    // MARK: - Configuration sources (env vars)
    // Names match NRVAVideoConfiguration.h fields, prefixed NEW_RELIC_*.

    private static func appToken() -> String? {
        nonEmpty("NEW_RELIC_APP_TOKEN").flatMap {
            $0 == "REPLACE_WITH_YOUR_APP_TOKEN" ? nil : $0
        }
    }

    private static func collectorAddress() -> String? {
        nonEmpty("NEW_RELIC_COLLECTOR_ADDRESS")
    }

    private static func harvestCycleSecs() -> Int {
        intEnv("NEW_RELIC_HARVEST_CYCLE_SECS", default: 10)
    }

    private static func liveHarvestCycleSecs() -> Int {
        intEnv("NEW_RELIC_LIVE_HARVEST_CYCLE_SECS", default: 10)
    }

    private static func regularBatchSizeBytes() -> Int {
        intEnv("NEW_RELIC_REGULAR_BATCH_SIZE_BYTES", default: 65536)   // 64 KB
    }

    private static func liveBatchSizeBytes() -> Int {
        intEnv("NEW_RELIC_LIVE_BATCH_SIZE_BYTES", default: 32768)      // 32 KB
    }

    private static func maxDeadLetterSize() -> Int {
        intEnv("NEW_RELIC_MAX_DEAD_LETTER_SIZE", default: 100)
    }

    private static func maxOfflineStorageMB() -> Int {
        intEnv("NEW_RELIC_MAX_OFFLINE_STORAGE_MB", default: 10)
    }

    private static func qoeEnabled() -> Bool {
        boolEnv("NEW_RELIC_QOE_ENABLED", default: true)
    }

    private static func qoeMultiplier() -> Int {
        intEnv("NEW_RELIC_QOE_INTERVAL_MULTIPLIER", default: 2)
    }

    private static func debugLogging() -> Bool {
        boolEnv("NEW_RELIC_DEBUG_LOGGING", default: true)
    }

    private static func memoryOptimization() -> Bool {
        boolEnv("NEW_RELIC_MEMORY_OPTIMIZATION", default: false)
    }

    // MARK: - Helpers

    private static func nonEmpty(_ key: String) -> String? {
        let v = ProcessInfo.processInfo.environment[key]
        guard let v, !v.isEmpty else { return nil }
        return v
    }

    private static func intEnv(_ key: String, default fallback: Int) -> Int {
        guard let raw = nonEmpty(key) else { return fallback }
        return Int(raw) ?? fallback
    }

    private static func boolEnv(_ key: String, default fallback: Bool) -> Bool {
        guard let raw = nonEmpty(key)?.lowercased() else { return fallback }
        return ["true", "1", "yes", "on"].contains(raw)
    }

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
