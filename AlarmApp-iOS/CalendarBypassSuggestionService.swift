import EventKit
import Foundation

/// Phase 7 — opt-in EventKit-based bypass day suggestion.
///
/// Deployment target is iOS 17.0 (see `project.yml`), so this uses the modern
/// granular `EKEventStore.requestFullAccessToEvents()` API directly — no need
/// for the older `requestAccess(to:completion:)` continuation-wrapped path.
@MainActor
final class CalendarBypassSuggestionService {
    private let store = EKEventStore()

    /// Keywords (case-insensitive, Turkish + English) that mark an all-day event as a likely non-work day.
    private static let nonWorkKeywords = [
        "izin", "tatil", "resmi tatil", "yıllık izin",
        "vacation", "holiday", "off", "pto", "leave"
    ]

    /// Requests full access to Calendar events. Returns `true` if access was granted.
    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    /// Returns the day-granularity `Date`s within `range` that contain an all-day
    /// event whose title matches one of the known non-work keywords.
    func likelyNonWorkDays(in range: DateInterval) async -> [Date] {
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .fullAccess else { return [] }

        let predicate = store.predicateForEvents(withStart: range.start, end: range.end, calendars: nil)
        let events = store.events(matching: predicate)

        let calendar = Calendar.current
        var matchedDays: Set<Date> = []

        for event in events {
            guard event.isAllDay else { continue }
            let title = event.title?.lowercased() ?? ""
            guard Self.nonWorkKeywords.contains(where: { title.contains($0) }) else { continue }
            let day = calendar.startOfDay(for: event.startDate)
            matchedDays.insert(day)
        }

        return matchedDays.sorted()
    }
}
