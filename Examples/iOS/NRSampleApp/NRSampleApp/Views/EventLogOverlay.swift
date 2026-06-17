import SwiftUI

/// Slide-up overlay showing NRVA events as they fire.
///
/// XCUITest reads this overlay's text to assert which events were emitted
/// during a scenario. Each event row carries an accessibility identifier
/// of the form `event.<EVENT_NAME>` so tests can match precisely.
///
/// Skeleton commit: the events array is local state; it will later be
/// driven by NRVAEventTap (see NewRelicSetup.swift).
struct EventLogOverlay: View {

    @State private var isExpanded = false
    @State private var events: [LoggedEvent] = []

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 0) {
                handle
                if isExpanded { eventList }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .accessibilityIdentifier("event-log-overlay")
    }

    private var handle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                Text("Events (\(events.count))")
                    .font(.system(.subheadline, design: .monospaced))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("event-log-handle")
    }

    private var eventList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(events) { event in
                    HStack(spacing: 8) {
                        Text(event.timestamp.formatted(.dateTime.hour().minute().second()))
                            .foregroundStyle(.tertiary)
                        Text(event.name)
                    }
                    .font(.system(.caption, design: .monospaced))
                    .accessibilityIdentifier("event.\(event.name)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(maxHeight: 240)
    }

    struct LoggedEvent: Identifiable {
        let id = UUID()
        let timestamp: Date
        let name: String
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        EventLogOverlay()
    }
}
