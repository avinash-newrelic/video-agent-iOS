import Foundation
import AVFoundation

/// One step in a scripted scenario. Executed at offset `t` seconds after
/// the scenario begins; takes a player-level action.
///
/// Scenarios use these to fire NRVA telemetry events that wouldn't occur
/// during passive playback (CONTENT_PAUSE, CONTENT_SEEK_*, CONTENT_END
/// via seek-to-near-end, etc.).
///
/// Codable so a script can be passed in via:
///   1. `ContentItem.actionScript` (default for the scenario, in code)
///   2. `--action-script <json>` launch argument (workflow override)
struct PlayerAction: Codable, Hashable {
    /// Seconds after scenario start.
    let t: Double
    /// One of: "play", "pause", "seek_pct", "seek_end_offset", "done".
    let action: String
    /// For "seek_pct" — percentage 0-100. For "seek_end_offset" — seconds before duration.
    let value: String?

    init(t: Double, _ action: String, _ value: String? = nil) {
        self.t = t
        self.action = action
        self.value = value
    }
}

extension PlayerAction {

    /// Apply this step to an AVPlayer. No-op if the action doesn't recognize.
    /// Logs a sentinel line on "done" so the CI runner can detect completion.
    func apply(to player: AVPlayer, scenarioId: String) {
        switch action {
        case "play":
            player.play()
            AppLog.shared.log(.event, "Scenario", "action", ["t": t, "action": "play"])

        case "pause":
            player.pause()
            AppLog.shared.log(.event, "Scenario", "action", ["t": t, "action": "pause"])

        case "seek_pct":
            let pct = Double(value ?? "50") ?? 50
            guard let dur = player.currentItem?.duration.seconds, dur.isFinite, dur > 0 else {
                AppLog.shared.log(.warn, "Scenario", "seek_pct skipped — no duration",
                                  ["t": t, "pct": pct])
                return
            }
            let target = CMTime(seconds: dur * (pct / 100.0), preferredTimescale: 600)
            player.seek(to: target)
            AppLog.shared.log(.event, "Scenario", "action",
                              ["t": t, "action": "seek_pct", "pct": pct, "sec": dur * (pct / 100.0)])

        case "seek_end_offset":
            let offset = Double(value ?? "2") ?? 2
            guard let dur = player.currentItem?.duration.seconds, dur.isFinite, dur > 0 else {
                AppLog.shared.log(.warn, "Scenario", "seek_end_offset skipped — no duration",
                                  ["t": t, "offset": offset])
                return
            }
            let target = CMTime(seconds: max(0, dur - offset), preferredTimescale: 600)
            player.seek(to: target)
            AppLog.shared.log(.event, "Scenario", "action",
                              ["t": t, "action": "seek_end_offset", "offsetSec": offset,
                               "sec": dur - offset])

        case "done":
            // Sentinel for the CI runner to detect scenario completion.
            AppLog.shared.log(.event, "Scenario", "SCENARIO_DONE",
                              ["scenarioId": scenarioId, "t": t])

        default:
            AppLog.shared.log(.warn, "Scenario", "unknown action",
                              ["t": t, "action": action])
        }
    }
}

enum PlayerActionScript {

    /// Resolve the active script for a given content item:
    ///   1. `--action-script <json>` CLI arg overrides everything
    ///   2. Otherwise the item's own `actionScript` (if any)
    ///   3. Otherwise nil (passive playback)
    static func resolve(for item: ContentItem) -> [PlayerAction]? {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--action-script"), i + 1 < args.count {
            let json = args[i + 1]
            if let data = json.data(using: .utf8) {
                do {
                    return try JSONDecoder().decode([PlayerAction].self, from: data)
                } catch {
                    AppLog.shared.log(.fail, "Scenario", "action-script parse failed",
                                      ["err": String(describing: error)])
                }
            }
        }
        return item.actionScript
    }

    /// Run a script against a player on the main actor. Cancellable via the
    /// returned Task — caller cancels on view disappear to prevent late
    /// dispatches firing after the player is torn down.
    @MainActor
    static func run(_ script: [PlayerAction],
                    on player: AVPlayer,
                    scenarioId: String) -> Task<Void, Never> {
        Task { @MainActor in
            let start = Date()
            for step in script {
                let elapsed = Date().timeIntervalSince(start)
                let wait = step.t - elapsed
                if wait > 0 {
                    let nanos = UInt64(wait * 1_000_000_000)
                    do {
                        try await Task.sleep(nanoseconds: nanos)
                    } catch {
                        return  // cancelled
                    }
                }
                if Task.isCancelled { return }
                step.apply(to: player, scenarioId: scenarioId)
            }
        }
    }
}
