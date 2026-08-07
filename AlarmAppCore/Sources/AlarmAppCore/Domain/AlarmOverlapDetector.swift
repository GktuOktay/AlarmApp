import Foundation

/// Detects same-day clock-time collisions between a candidate alarm and existing alarms.
public enum AlarmOverlapDetector {
    public struct Overlap: Equatable, Sendable {
        public let existingAlarmId: UUID
        public let existingAlarmTitle: String
        public let weekday: Weekday
        public let time: ClockTime

        public init(existingAlarmId: UUID, existingAlarmTitle: String, weekday: Weekday, time: ClockTime) {
            self.existingAlarmId = existingAlarmId
            self.existingAlarmTitle = existingAlarmTitle
            self.weekday = weekday
            self.time = time
        }
    }

    public static func overlaps(
        candidateDays: [Weekday],
        candidateTime: ClockTime,
        existing: [(id: UUID, title: String, days: [Weekday], time: ClockTime)]
    ) -> [Overlap] {
        let candidateDaySet = Set(candidateDays)
        var result: [Overlap] = []

        for alarm in existing {
            guard alarm.time == candidateTime else { continue }
            let sharedDays = candidateDaySet.intersection(alarm.days)
            guard !sharedDays.isEmpty else { continue }
            for day in sharedDays.sorted(by: { $0.rawValue < $1.rawValue }) {
                result.append(
                    Overlap(
                        existingAlarmId: alarm.id,
                        existingAlarmTitle: alarm.title,
                        weekday: day,
                        time: candidateTime
                    )
                )
            }
        }
        return result
    }
}
