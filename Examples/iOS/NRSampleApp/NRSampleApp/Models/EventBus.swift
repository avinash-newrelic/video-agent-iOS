import Foundation
import Combine

/// In-app event bus driving `EventLogOverlay`.
///
/// SCOPE: this is for visible event-emission verification by XCUITest.
/// In v1 the events are SYNTHETIC (driven by AVPlayer state observation
/// in the scenario views), not real NRVA agent events. A follow-up commit
/// can wire NRVA events directly into this bus when the agent exposes a
/// public event tap.
///
/// Event names mirror NRVA event names (CONTENT_REQUEST, CONTENT_START,
/// SEEK_START, AD_BREAK_START, etc.) so XCUITest assertions written today
/// will keep passing once real NRVA tap is wired.
final class EventBus: ObservableObject {

    static let shared = EventBus()
    private init() {}

    @Published private(set) var events: [LoggedEvent] = []

    func emit(_ name: String, attributes: [String: String] = [:]) {
        let entry = LoggedEvent(timestamp: Date(), name: name, attributes: attributes)
        if Thread.isMainThread {
            events.append(entry)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.events.append(entry)
            }
        }
    }

    func clear() {
        if Thread.isMainThread {
            events.removeAll()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.events.removeAll()
            }
        }
    }

    struct LoggedEvent: Identifiable, Hashable {
        let id = UUID()
        let timestamp: Date
        let name: String
        let attributes: [String: String]
    }
}
