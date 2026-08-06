import Foundation

public enum AlarmInstanceGenerationError: Error, Equatable, Sendable {
    case invalidInterval
    case invalidClockTime
}

/// Pure algorithm for F1 (K1: end time inclusive).
public enum AlarmInstanceGenerator {
    /// Returns clock times from `start` through `end` stepping by `intervalMinutes`.
    /// Overnight windows (e.g. 23:30–00:30) are supported: end is treated as next-day minutes.
    public static func clockTimes(
        start: ClockTime,
        end: ClockTime,
        intervalMinutes: Int
    ) throws -> [ClockTime] {
        guard intervalMinutes > 0 else { throw AlarmInstanceGenerationError.invalidInterval }
        guard (0..<24).contains(start.hour), (0..<60).contains(start.minute),
              (0..<24).contains(end.hour), (0..<60).contains(end.minute)
        else {
            throw AlarmInstanceGenerationError.invalidClockTime
        }

        let startMinutes = start.minutesFromMidnight
        var endMinutes = end.minutesFromMidnight
        if endMinutes < startMinutes {
            endMinutes += 24 * 60
        }

        var result: [ClockTime] = []
        var cursor = startMinutes
        while cursor <= endMinutes {
            result.append(.from(minutesFromMidnight: cursor))
            // Prevent infinite loop if interval somehow zero (already guarded).
            let next = cursor + intervalMinutes
            if next <= cursor { break }
            cursor = next
        }
        return result
    }
}
