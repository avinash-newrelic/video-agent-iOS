import SwiftUI

@main
struct NRSampleAppApp: App {

    init() {
        // Level 1: main video configuration. Once at app launch.
        NewRelicSetup.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}
