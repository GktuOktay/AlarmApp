import Foundation

/// Scope for bulk-cancelling pending alarm instances from the ringing “Daha fazla” menu.
/// Day/group filtering for `.groupToday` / `.allToday` is applied by the repository with a calendar.
public enum BulkCancelScope: Codable, Sendable, Equatable {
    case groupToday(UUID)
    case allNextHours(Int)
    case allToday

    /// Membership for fire dates. For `.allNextHours`, half-open `[now, now + hours*3600)`.
    public func includesFireDate(_ fire: Date, now: Date) -> Bool {
        switch self {
        case .allNextHours(let hours):
            let end = now.addingTimeInterval(TimeInterval(max(hours, 0) * 3600))
            return fire >= now && fire < end
        case .groupToday, .allToday:
            return true
        }
    }
}
