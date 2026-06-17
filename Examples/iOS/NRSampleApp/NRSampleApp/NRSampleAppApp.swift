import SwiftUI

@main
struct NRSampleAppApp: App {

    init() {
        NewRelicSetup.start()
    }

    var body: some Scene {
        WindowGroup {
            LaunchArgRouter().resolveRoot()
        }
    }
}
