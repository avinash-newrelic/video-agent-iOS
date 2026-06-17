import SwiftUI
import AVKit

/// Full-bleed player using AVKit's `VideoPlayer` for native iOS playback
/// controls (play/pause, scrub, AirPlay, captions, full-screen).
///
/// Observes the AVPlayer + AVPlayerItem state machine and writes every
/// transition + every error to AppLog. Tap the Logs button on Home to see.
struct PlayerView: View {

    let item: ContentItem
    @StateObject private var model = PlayerModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = model.player {
                VideoPlayer(player: player)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                ProgressView().tint(.white)
            }
        }
        .navigationTitle(item.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { model.start(item: item) }
        .onDisappear { model.stop() }
    }
}

@MainActor
final class PlayerModel: ObservableObject {

    @Published var player: AVPlayer?

    private var timeControlObs: NSKeyValueObservation?
    private var rateObs: NSKeyValueObservation?
    private var itemStatusObs: NSKeyValueObservation?
    private var newErrorEntryObs: NSObjectProtocol?
    private var failedToEndObs: NSObjectProtocol?
    private var didEndObs: NSObjectProtocol?
    private var stalledObs: NSObjectProtocol?

    private var startedAt: Date?
    private var contentId: String = ""

    func start(item: ContentItem) {
        contentId = item.id
        startedAt = Date()

        AppLog.shared.log(.event, "Player", "start", [
            "id": item.id,
            "title": item.title,
            "isLive": item.isLive,
            "url": item.streamURL.absoluteString,
        ])

        let asset = AVURLAsset(url: item.streamURL)
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        self.player = player

        timeControlObs = player.observe(\.timeControlStatus, options: [.new]) { [weak self] p, _ in
            Task { @MainActor in self?.logTimeControl(p.timeControlStatus, reason: p.reasonForWaitingToPlay) }
        }
        rateObs = player.observe(\.rate, options: [.new]) { [weak self] p, _ in
            Task { @MainActor in
                AppLog.shared.log(.event, "Player", "rate", ["rate": p.rate])
            }
        }
        itemStatusObs = playerItem.observe(\.status, options: [.new]) { [weak self] i, _ in
            Task { @MainActor in self?.logItemStatus(i) }
        }

        newErrorEntryObs = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemNewErrorLogEntry,
            object: playerItem, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.logErrorLog(item: playerItem) }
        }
        failedToEndObs = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem, queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                let err = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
                AppLog.shared.log(.fail, "Player", "failedToPlayToEnd", [
                    "id": self?.contentId ?? "",
                    "err": err.map { String(describing: $0) } ?? "(nil)",
                ])
            }
        }
        didEndObs = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                AppLog.shared.log(.event, "Player", "didPlayToEnd", ["id": self?.contentId ?? ""])
            }
        }
        stalledObs = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: playerItem, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                AppLog.shared.log(.warn, "Player", "playbackStalled", ["id": self?.contentId ?? ""])
            }
        }

        player.play()
    }

    func stop() {
        let durationMs = Int(Date().timeIntervalSince(startedAt ?? Date()) * 1000)
        AppLog.shared.log(.event, "Player", "stop",
                          ["id": contentId, "session_ms": durationMs])

        timeControlObs?.invalidate(); timeControlObs = nil
        rateObs?.invalidate(); rateObs = nil
        itemStatusObs?.invalidate(); itemStatusObs = nil

        for o in [newErrorEntryObs, failedToEndObs, didEndObs, stalledObs] {
            if let o = o { NotificationCenter.default.removeObserver(o) }
        }
        newErrorEntryObs = nil
        failedToEndObs = nil
        didEndObs = nil
        stalledObs = nil

        player?.pause()
        player = nil
    }

    // MARK: - Logging helpers

    private func logTimeControl(_ status: AVPlayer.TimeControlStatus,
                                reason: AVPlayer.WaitingReason?) {
        let s: String = {
            switch status {
            case .paused: return "paused"
            case .playing: return "playing"
            case .waitingToPlayAtSpecifiedRate: return "waiting"
            @unknown default: return "?"
            }
        }()
        var ctx: [String: Any] = ["state": s]
        if let r = reason { ctx["reason"] = r.rawValue }
        AppLog.shared.log(.event, "Player", "timeControl", ctx)
    }

    private func logItemStatus(_ item: AVPlayerItem) {
        let s: String = {
            switch item.status {
            case .unknown: return "unknown"
            case .readyToPlay: return "readyToPlay"
            case .failed: return "failed"
            @unknown default: return "?"
            }
        }()
        var ctx: [String: Any] = ["state": s]
        if let err = item.error {
            ctx["err"] = String(describing: err)
        }
        AppLog.shared.log(item.status == .failed ? .fail : .event,
                          "Player", "itemStatus", ctx)
    }

    private func logErrorLog(item: AVPlayerItem) {
        guard let log = item.errorLog() else { return }
        for ev in log.events {
            AppLog.shared.log(.fail, "Player", "errorLogEvent", [
                "code": ev.errorStatusCode,
                "domain": ev.errorDomain,
                "comment": ev.errorComment ?? "",
                "uri": ev.uri ?? "",
            ])
        }
    }
}
