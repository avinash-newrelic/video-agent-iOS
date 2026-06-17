import SwiftUI
import AVKit

/// Plays an HLS VOD stream with NRVA tracking attached.
///
/// Emits SYNTHETIC events to `EventBus.shared` based on AVPlayer state so
/// XCUITest can assert visible behavior. When NRVA exposes a public event
/// tap, replace the synthetic emission with the real one — test assertions
/// will keep working since names align with NRVA's event names.
struct BasicVODView: View {

    let scenario: Scenario
    @StateObject private var model = PlayerModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = model.player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .accessibilityIdentifier("player.\(scenario.id)")
            } else {
                ProgressView()
                    .tint(.white)
                    .accessibilityIdentifier("player.loading")
            }

            EventLogOverlay()
        }
        .onAppear {
            EventBus.shared.clear()
            EventBus.shared.emit("VIEW_LOADED", attributes: ["scenario": scenario.id])
            model.start(streamUrl: scenario.streamUrl, name: scenario.id)
        }
        .onDisappear {
            model.stop()
        }
    }
}

@MainActor
final class PlayerModel: ObservableObject {

    @Published var player: AVPlayer?

    private var trackerId: Int?
    private var statusObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var hasEmittedStart = false

    func start(streamUrl: URL, name: String) {
        EventBus.shared.emit("CONTENT_REQUEST",
                             attributes: ["streamUrl": streamUrl.absoluteString])

        let item = AVPlayerItem(url: streamUrl)
        let player = AVPlayer(playerItem: item)
        self.player = player
        self.trackerId = NewRelicSetup.addAVPlayer(player, name: name)

        statusObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] p, _ in
            Task { @MainActor in self?.handleTimeControlChange(p.timeControlStatus) }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            EventBus.shared.emit("CONTENT_END")
        }

        player.play()
    }

    private func handleTimeControlChange(_ status: AVPlayer.TimeControlStatus) {
        if status == .playing && !hasEmittedStart {
            hasEmittedStart = true
            EventBus.shared.emit("CONTENT_START")
        }
    }

    func stop() {
        statusObservation?.invalidate()
        statusObservation = nil
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        if let id = trackerId {
            NewRelicSetup.releaseAVPlayer(trackerId: id)
            trackerId = nil
        }
        player?.pause()
    }
}
