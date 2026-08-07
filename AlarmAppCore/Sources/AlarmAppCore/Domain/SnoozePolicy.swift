import Foundation

public enum SnoozePolicy {
    public static let defaultMinutes = 9
    public static let minMinutes = 1
    public static let maxMinutes = 30

    public static func clampMinutes(_ value: Int) -> Int {
        min(max(value, minMinutes), maxMinutes)
    }

    public static func fireDate(from now: Date, minutes: Int) -> Date {
        now.addingTimeInterval(TimeInterval(clampMinutes(minutes) * 60))
    }
}
