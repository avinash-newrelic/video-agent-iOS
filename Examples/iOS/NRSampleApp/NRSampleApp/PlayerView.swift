import SwiftUI
import AVKit

/// Full-bleed player using AVKit's `VideoPlayer` for native iOS playback
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

    func start(item: ContentItem) {
        let p = AVPlayer(url: item.streamURL)
        self.player = p
        p.play()
    }

    func stop() {
        player?.pause()
        player = nil
    }
}
