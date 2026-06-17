import Foundation
import os.log

/// Levels of log lines, mirrored in the on-disk log file as bracketed prefixes.
enum LogLevel: String {
    case info  = "INFO"     // diagnostics
    case event = "EVENT"    // app/player state changes
    case action = "ACTION"  // user-driven (taps, navigation)
    case warn  = "WARN"
    case fail  = "FAIL"     // errors
}

/// Process-wide logger writing to:
///   1. Xcode console via `os_log` (visible in Xcode while debugging)
///   2. A daily file at `Documents/logs/yyyy-MM-dd.log` (visible in
///      Xcode → Window → Devices & Simulators → app container → Download)
///
/// Use `AppLog.shared.log(.event, "Player", "play tapped", ["id": item.id])`.
final class AppLog {

    static let shared = AppLog()

    private let osLog = OSLog(subsystem: "com.newrelic.video.sample.NRSampleApp", category: "app")
    private let fileQueue = DispatchQueue(label: "applog.file", qos: .utility)
    private let stateLock = NSLock()
    private var _customFileName: String?

    private init() {}

    /// Switch the log destination to a specific file under `Documents/logs/`.
    /// Used by automation runs (`--auto-play`) so each scenario writes to a
    /// dedicated, predictable file the runner can poll without parsing the
    /// shared daily log. The file is truncated on switch.
    func switchToFile(named name: String) {
        stateLock.lock()
        _customFileName = name
        stateLock.unlock()
        let url = Self.logsDirectory.appendingPathComponent(name)
        try? Data().write(to: url, options: .atomic)
    }

    @discardableResult
    func log(_ level: LogLevel,
             _ category: String,
             _ message: String,
             _ context: [String: Any] = [:]) -> String {
        let ts = ISO8601DateFormatter.applog.string(from: Date())
        let ctx = context.isEmpty
            ? ""
            : " · " + context.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " · ")
        let line = "[\(ts)] [\(level.rawValue.padding(toLength: 6, withPad: " ", startingAt: 0))] [\(category)] \(message)\(ctx)"

        os_log("%{public}@", log: osLog, type: osType(for: level), line)

        fileQueue.async { [weak self] in
            self?.appendToFile(line: line)
        }

        return line
    }

    /// Path to the active log file. If `switchToFile(named:)` was called,
    /// returns that custom path; otherwise the daily file `yyyy-MM-dd.log`.
    func todayURL() -> URL {
        stateLock.lock()
        let custom = _customFileName
        stateLock.unlock()
        if let name = custom {
            return Self.logsDirectory.appendingPathComponent(name)
        }
        let day = DateFormatter.applogDay.string(from: Date())
        return Self.logsDirectory.appendingPathComponent("\(day).log")
    }

    /// `Documents/logs/`. Created on first access.
    static var logsDirectory: URL {
        let docs = (try? FileManager.default.url(for: .documentDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil,
                                                 create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let logs = docs.appendingPathComponent("logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logs,
                                                 withIntermediateDirectories: true)
        return logs
    }

    // MARK: - File I/O

    private func appendToFile(line: String) {
        let url = todayURL()
        let data = (line + "\n").data(using: .utf8) ?? Data()
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func osType(for level: LogLevel) -> OSLogType {
        switch level {
        case .info, .event, .action: return .default
        case .warn: return .info
        case .fail: return .error
        }
    }
}

private extension ISO8601DateFormatter {
    static let applog: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

private extension DateFormatter {
    static let applogDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()
}
