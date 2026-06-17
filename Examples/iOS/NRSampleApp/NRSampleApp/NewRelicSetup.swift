import Foundation

// IMPORTANT: This is the canonical NewRelic Video Agent wiring file.
// Customers should be able to copy this verbatim into their own apps.
// Keep it tight, well-commented (with WHY), and grounded in the agent's
// public API. Update as the agent evolves.
//
// Skeleton commit: actual NRVA API calls are marked TODO. They will be
// filled in once the canonical NRVAVideo facade calls are wired into
// the project's import path. The shape below is what customers see.

enum NewRelicSetup {

    /// The application token from one.newrelic.com. Read from environment so
    /// the token never lands in a public repo. CI sets this; local dev sets
    /// it via Xcode scheme env vars.
    private static var appToken: String {
        ProcessInfo.processInfo.environment["NEW_RELIC_APP_TOKEN"]
            ?? "REPLACE_WITH_YOUR_APP_TOKEN"
    }

    /// Call once at app launch (e.g. from @main App.init).
    static func start() {
        // 1. Start the agent.
        //    QoE is enabled by default in v4.1.x with interval multiplier 2,
        //    so harvest cadence stays in step with event volume.
        // TODO: NRVAVideo.start(withApplicationToken: appToken)

        // 2. Per-session attributes — appear on every event from this session.
        //    Examples customers typically set: app version, build, environment.
        // TODO: NRVAVideo.setAttribute("appVersion", value: Bundle.main.shortVersion)
        // TODO: NRVAVideo.setAttribute("environment", value: "production")

        // 3. User identifier — for cross-event correlation in NRQL.
        //    Use a stable ID (a UUID kept in Keychain for a real app).
        // TODO: NRVAVideo.setUserId(stableUserId())

        // 4. Optional: content metadata if known at session start. Most apps
        //    set these per-video instead, alongside startTracker.

        // 5. Optional: surface the agent's events into our in-app overlay so
        //    the dev (and XCUITest) can see them live. Wires to EventLogOverlay.
        // TODO: NRVAEventTap.shared.enable()
    }
}
