import Foundation

/// Ensures at most one alarm is marked as the wake schedule selection.
/// Repository clears the previous wake flag; this policy returns the new id.
public enum WakeSchedulePolicy {
    public static func applying(selectedId: UUID, currentWakeId: UUID?) -> UUID? {
        selectedId
    }
}
