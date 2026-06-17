import SwiftUI

struct ScenarioMenuView: View {

    private let scenarios = ScenarioCatalog.all()

    var body: some View {
        NavigationStack {
            Group {
                if scenarios.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("NRSampleApp")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No scenarios yet")
                .font(.headline)
            Text("Skeleton build. Scenarios added in subsequent commits.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .accessibilityIdentifier("scenario.menu.empty")
    }

    private var list: some View {
        List(scenarios) { scenario in
            VStack(alignment: .leading, spacing: 4) {
                Text(scenario.title).font(.headline)
                Text(scenario.summary).font(.caption).foregroundStyle(.secondary)
                Text("Cadence: \(scenario.cadence.rawValue)")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            .accessibilityIdentifier("scenario.menu.row.\(scenario.id)")
        }
    }
}

#Preview {
    ScenarioMenuView()
}
