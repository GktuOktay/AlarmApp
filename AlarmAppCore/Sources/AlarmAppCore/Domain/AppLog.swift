import Foundation
import os

public enum AppLogLevel: String, Sendable, Equatable {
    case debug
    case info
    case error
}

public enum AppLogCategory: String, Sendable, Equatable {
    case swiftdata
    case notifications
    case wcsession
    case wake
}

public struct AppLogEvent: Sendable, Equatable {
    public var level: AppLogLevel
    public var category: AppLogCategory
    public var message: String
    public var errorDescription: String?

    public init(
        level: AppLogLevel,
        category: AppLogCategory,
        message: String,
        errorDescription: String? = nil
    ) {
        self.level = level
        self.category = category
        self.message = message
        self.errorDescription = errorDescription
    }
}

public protocol LogSink: Sendable {
    func log(_ event: AppLogEvent)
}

/// Local-first diagnostics. Uses `os.Logger` plus an optional testable sink.
/// Does not change fail-safe product behavior — callers still swallow or surface errors as before.
public enum AppLog {
    private static let subsystem = "com.alarmapp.AlarmApp"
    private static let lock = NSLock()
    private static var _sink: (any LogSink)?
    private static var ring: [AppLogEvent] = []
    private static let ringCapacity = 200

    private static let loggers: [AppLogCategory: Logger] = [
        .swiftdata: Logger(subsystem: subsystem, category: AppLogCategory.swiftdata.rawValue),
        .notifications: Logger(subsystem: subsystem, category: AppLogCategory.notifications.rawValue),
        .wcsession: Logger(subsystem: subsystem, category: AppLogCategory.wcsession.rawValue),
        .wake: Logger(subsystem: subsystem, category: AppLogCategory.wake.rawValue)
    ]

    public static func setSink(_ sink: (any LogSink)?) {
        lock.lock()
        _sink = sink
        lock.unlock()
    }

    public static func recentEvents() -> [AppLogEvent] {
        lock.lock()
        defer { lock.unlock() }
        return ring
    }

    public static func clearRing() {
        lock.lock()
        ring.removeAll()
        lock.unlock()
    }

    public static func debug(_ category: AppLogCategory, _ message: String) {
        emit(.init(level: .debug, category: category, message: message))
    }

    public static func info(_ category: AppLogCategory, _ message: String) {
        emit(.init(level: .info, category: category, message: message))
    }

    public static func error(_ category: AppLogCategory, _ message: String, error: Error? = nil) {
        emit(
            .init(
                level: .error,
                category: category,
                message: message,
                errorDescription: error.map { String(describing: $0) }
            )
        )
    }

    private static func emit(_ event: AppLogEvent) {
        let logger = loggers[event.category] ?? Logger(subsystem: subsystem, category: "general")
        let text: String
        if let errorDescription = event.errorDescription {
            text = "\(event.message) | \(errorDescription)"
        } else {
            text = event.message
        }
        switch event.level {
        case .debug:
            logger.debug("\(text, privacy: .public)")
        case .info:
            logger.info("\(text, privacy: .public)")
        case .error:
            logger.error("\(text, privacy: .public)")
        }

        lock.lock()
        ring.append(event)
        if ring.count > ringCapacity {
            ring.removeFirst(ring.count - ringCapacity)
        }
        let sink = _sink
        lock.unlock()
        sink?.log(event)
    }
}

/// Records log events for unit tests.
public final class RecordingLogSink: LogSink, @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [AppLogEvent] = []

    public init() {}

    public func log(_ event: AppLogEvent) {
        lock.lock()
        _events.append(event)
        lock.unlock()
    }

    public var events: [AppLogEvent] {
        lock.lock()
        defer { lock.unlock() }
        return _events
    }

    public func reset() {
        lock.lock()
        _events.removeAll()
        lock.unlock()
    }
}
