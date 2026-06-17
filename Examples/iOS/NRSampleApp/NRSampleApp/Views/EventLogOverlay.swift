import SwiftUI

/// Slide-up overlay showing scenario events as they fire.
///
/// XCUITest reads this overlay's text to assert which events were emitted.
/// Each event row carries an accessibility identifier of the form
/// `event.<EVENT_NAME>` so tests can match precisely.
///
/// Backed by `EventBus.shared`. See EventBus.swift for the event source policy.
struct EventLogOverlay: View {

    @State private var isExpanded = false
    @ObservedObject private var bus = EventBus.shared

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
                Text("Events (\(bus.events.count))")
                    .font(.system(.subheadline, design: .monospaced))
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("event-log-handle")
    }

    private var eventList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(bus.events) { event in
                    HStack(spacing: 8) {
                        Text(event.timestamp.formatted(.dateTime.hour().minute().second()))
                            .foregroundStyle(.tertiary)
                        Text(event.name)
                    }
                    .font(.system(.caption, design: .monospaced))
                    .accessibilityIdentifier("event.\(event.name)")
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 12)
        }
        .frame(maxHeight: 240)
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        EventLogOverlay()
    }
}
