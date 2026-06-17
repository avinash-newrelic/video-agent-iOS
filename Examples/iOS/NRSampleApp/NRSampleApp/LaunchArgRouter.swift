import SwiftUI

/// Resolves the app's root view from launch arguments.
///
/// XCUITest passes `--scenario <id>` to launch directly into a scenario view.
/// Manual launches without arguments show the menu.
struct LaunchArgRouter {

    @ViewBuilder
    func resolveRoot() -> some View {
        if let id = scenarioIDFromArgs(),
           let scenario = ScenarioCatalog.find(id: id) {
            ScenarioRouterView(scenario: scenario)
        } else {
            ScenarioMenuView()
        }
    }

    private func scenarioIDFromArgs() -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--scenario"),
              i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}

/// Dispatch table from scenario.id to the SwiftUI view for that scenario.
/// Add a `case` here when you add a new scenario view.
private struct ScenarioRouterView: View {
    let scenario: Scenario

    @ViewBuilder
    var body: some View {
        switch scenario.id {
        case "basic-vod":
            BasicVODView(scenario: scenario)
        default:
            ScenarioPlaceholderView(scenario: scenario)
        }
    }
}

private struct ScenarioPlaceholderView: View {
    let scenario: Scenario

    var body: some View {
        VStack(spacing: 12) {
            Text(scenario.title).font(.title2).bold()
            Text(scenario.summary).font(.callout).foregroundStyle(.secondary)
            Text("View not yet implemented")
                .font(.caption).foregroundStyle(.tertiary).padding(.top, 8)
        }
        .padding()
        .accessibilityIdentifier("scenario.placeholder.\(scenario.id)")
    }
}
