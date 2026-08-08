import Foundation

/// Side effects produced when applying a peer `WatchMessage` to the local repository.
public struct WatchSyncEffects: Sendable, Equatable {
    public var cancelledInstanceIds: [UUID]
    public var newSchedules: [AlarmSchedule]
    /// Optional ringing hint when today context implies a due alarm (Watch may present UI).
    public var ringingCandidate: RingingCandidate?

    public struct RingingCandidate: Sendable, Equatable {
        public var alarmId: UUID
        public var instanceId: UUID
        public var groupId: UUID?
        public var title: String
        public var timeText: String
        public var snoozeEnabled: Bool

        public init(
            alarmId: UUID,
            instanceId: UUID,
            groupId: UUID? = nil,
            title: String,
            timeText: String,
            snoozeEnabled: Bool
        ) {
            self.alarmId = alarmId
            self.instanceId = instanceId
            self.groupId = groupId
            self.title = title
            self.timeText = timeText
            self.snoozeEnabled = snoozeEnabled
        }
    }

    public init(
        cancelledInstanceIds: [UUID] = [],
        newSchedules: [AlarmSchedule] = [],
        ringingCandidate: RingingCandidate? = nil
    ) {
        self.cancelledInstanceIds = cancelledInstanceIds
        self.newSchedules = newSchedules
        self.ringingCandidate = ringingCandidate
    }
}

/// Applies incoming peer messages with fail-safe, idempotent repository updates.
public enum WatchMessageSyncApplier: Sendable {
    /// Window: fire in the past 15 minutes up to 60 seconds ahead → candidate for ringing UI.
    public static let ringingLookbackSeconds: TimeInterval = 15 * 60
    public static let ringingLookaheadSeconds: TimeInterval = 60

    public static func apply(
        _ message: WatchMessage,
        repository: AlarmRepository,
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) async throws -> WatchSyncEffects {
        switch message {
        case .todayContextUpdate(let context):
            return try await ringingEffects(
                from: context,
                repository: repository,
                now: now,
                calendar: calendar
            )

        case .wakeConfirmed(let groupId, let timestamp):
            let cancelled = try await repository.handleWakeEvent(
                groupId: groupId,
                source: .watchManual,
                timestamp: timestamp
            )
            return WatchSyncEffects(cancelledInstanceIds: cancelled)

        case .snoozeApplied(let alarmId, let instanceId, let fireDate):
            if let schedule = try await repository.applyRemoteSnooze(
                alarmId: alarmId,
                instanceId: instanceId,
                fireDate: fireDate,
                now: now
            ) {
                return WatchSyncEffects(
                    cancelledInstanceIds: [instanceId],
                    newSchedules: [schedule]
                )
            }
            // Already applied — still cancel the old notification id.
            return WatchSyncEffects(cancelledInstanceIds: [instanceId])

        case .dismissApplied(let alarmId, let instanceId):
            let cancelled = try await repository.dismissAlarm(
                alarmId: alarmId,
                instanceId: instanceId,
                now: now
            )
            return WatchSyncEffects(cancelledInstanceIds: cancelled)

        case .bulkCancelApplied(let scope, let timestamp):
            let reason: CancelReason
            switch scope {
            case .allNextHours:
                reason = .nextHoursWindow
            case .groupToday, .allToday:
                reason = .manualToday
            }
            let cancelled = try await repository.cancel(
                scope: scope,
                reason: reason,
                now: timestamp
            )
            return WatchSyncEffects(cancelledInstanceIds: cancelled)
        }
    }

    private static func ringingEffects(
        from context: TodayContext,
        repository: AlarmRepository,
        now: Date,
        calendar: Calendar
    ) async throws -> WatchSyncEffects {
        let dayItems = try await repository.instances(on: context.date)
        let dayByInstanceId = Dictionary(uniqueKeysWithValues: dayItems.map { ($0.instanceId, $0) })
        let alarms = try await repository.fetchActiveAlarms()
        let alarmById = Dictionary(uniqueKeysWithValues: alarms.map { ($0.id, $0) })

        let windowStart = now.addingTimeInterval(-ringingLookbackSeconds)
        let windowEnd = now.addingTimeInterval(ringingLookaheadSeconds)
        let dayStart = calendar.startOfDay(for: context.date)

        // Prefer context summaries (Watch may be catalog-thin); enrich from local when present.
        for group in context.activeGroups {
            for summary in group.remainingInstances {
                guard summary.status == .pending || summary.status == .fired else { continue }
                guard let fire = AlarmFireDate.make(
                    day: dayStart,
                    time: summary.time,
                    calendar: calendar
                ) else { continue }
                guard fire >= windowStart, fire <= windowEnd else { continue }

                let local = dayByInstanceId[summary.id]
                let alarmId = local?.alarmId ?? summary.alarmId
                let summaryAlarm = alarmById[alarmId]
                let timeText = String(format: "%02d:%02d", summary.time.hour, summary.time.minute)
                let candidate = WatchSyncEffects.RingingCandidate(
                    alarmId: alarmId,
                    instanceId: summary.id,
                    groupId: local?.groupId ?? group.id,
                    title: local?.title ?? summaryAlarm?.title ?? "Alarm",
                    timeText: timeText,
                    snoozeEnabled: summaryAlarm?.snoozeEnabled ?? true
                )
                return WatchSyncEffects(ringingCandidate: candidate)
            }
        }
        return WatchSyncEffects()
    }
}
