import Foundation

/// Whether Watch should offer “Uyandın mı? Bu gruptaki kalan alarmları kapatayım mı?”
/// after the user dismisses a ringing alarm. Never cancels — prompt only.
public enum PostDismissWakeOfferPolicy: Sendable {
    /// Offer only when the dismissed alarm belonged to a group and other pending
    /// instances remain for that group today.
    public static func shouldOffer(
        groupId: UUID?,
        remainingPendingInGroupToday: Int
    ) -> Bool {
        guard groupId != nil else { return false }
        return remainingPendingInGroupToday > 0
    }
}
