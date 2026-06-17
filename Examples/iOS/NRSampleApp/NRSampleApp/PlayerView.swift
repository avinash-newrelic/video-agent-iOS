import SwiftUI
import AVKit

/// Full-bleed player view. Uses AVKit's `VideoPlayer` for native iOS playback
/// controls (play/pause, scrub, AirPlay, captions, full-screen).
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
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.start(item: item) }
        .onDisappear { model.stop() }
    }
}

@MainActor
final class PlayerModel: ObservableObject {

    @Published var player: AVPlayer?
    private var trackerId: Int?

    func start(item: ContentItem) {
        let player = AVPlayer(url: item.streamURL)
        self.player = player
        self.trackerId = NewRelicSetup.addAVPlayer(
            player,
            name: item.id,
            customAttributes: [
                "contentTitle": item.title,
                "isLive": item.isLive,
            ]
        )
        player.play()
    }

    func stop() {
        if let id = trackerId {
            NewRelicSetup.releaseAVPlayer(trackerId: id)
            trackerId = nil
        }
        player?.pause()
        player = nil
    }
}
