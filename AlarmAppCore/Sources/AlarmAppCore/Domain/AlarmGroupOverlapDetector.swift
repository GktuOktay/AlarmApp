import Foundation

/// Detects same-day clock-time collisions between a candidate group and existing groups (F1 warning).
public enum AlarmGroupOverlapDetector {
    public struct Overlap: Equatable, Sendable {
        public let existingGroupId: UUID
        public let existingGroupName: String
        public let weekday: Weekday
        public let time: ClockTime
    }

    public static func overlaps(
        candidateDays: [Weekday],
        candidateTimes: [ClockTime],
        existing: [(id: UUID, name: String, days: [Weekday], times: [ClockTime])]
    ) -> [Overlap] {
        let candidateDaySet = Set(candidateDays)
        let candidateTimeSet = Set(candidateTimes)
        var result: [Overlap] = []

        for group in existing {
            let sharedDays = candidateDaySet.intersection(group.days)
            guard !sharedDays.isEmpty else { continue }
            let sharedTimes = candidateTimeSet.intersection(group.times)
            guard !sharedTimes.isEmpty else { continue }
            for day in sharedDays.sorted(by: { $0.rawValue < $1.rawValue }) {
                for time in sharedTimes.sorted() {
                    result.append(
                        Overlap(
                            existingGroupId: group.id,
                            existingGroupName: group.name,
                            weekday: day,
                            time: time
                        )
                    )
                }
            }
        }
        return result
    }
}
