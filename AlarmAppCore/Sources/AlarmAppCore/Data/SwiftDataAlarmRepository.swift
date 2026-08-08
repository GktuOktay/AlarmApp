import Foundation
import SwiftData

public enum SwiftDataAlarmRepositoryError: Error, Sendable, Equatable {
    case groupNotFound
    case alarmNotFound
    case instanceNotFound
    case snoozeDisabled
}

@ModelActor
public actor SwiftDataAlarmRepository: AlarmRepository {
    public func createAlarm(from prepared: PreparedAlarm) async throws -> CreateAlarmResult {
        let group: AlarmGroup?
        if let groupId = prepared.groupId {
            group = try requireGroup(id: groupId)
        } else {
            group = nil
        }

        let alarm = Alarm(
            id: prepared.id,
            title: prepared.title,
            time: prepared.time,
            daysOfWeek: prepared.daysOfWeek,
            soundId: prepared.soundId,
            soundVolume: prepared.soundVolume,
            snoozeEnabled: prepared.snoozeEnabled,
            snoozeMinutes: prepared.snoozeMinutes,
            isWakeSchedule: prepared.isWakeSchedule,
            endsOn: prepared.endsOn,
            group: group,
            createdAt: prepared.createdAt,
            updatedAt: prepared.updatedAt
        )
        modelContext.insert(alarm)

        let calendar = Calendar.autoupdatingCurrent
        var schedules: [AlarmSchedule] = []
        for spec in prepared.instances {
            let instance = AlarmInstance(
                scheduledDate: spec.scheduledDate,
                scheduledTime: spec.scheduledTime,
                status: .pending,
                updatedAt: prepared.updatedAt
            )
            instance.alarm = alarm
            modelContext.insert(instance)
            if let fire = AlarmFireDate.make(day: spec.scheduledDate, time: spec.scheduledTime, calendar: calendar) {
                schedules.append(AlarmSchedule(
                    instanceId: instance.id,
                    alarmId: alarm.id,
                    fireDate: fire,
                    soundId: alarm.soundId,
                    soundVolume: alarm.soundVolume
                ))
            }
        }

        try modelContext.save()

        // Near-term materialization for notifications only — pattern stays the source of truth.
        let upcoming = try materializeUpcoming(
            for: [alarm],
            horizonDays: AlarmHorizon.notificationDays,
            calendar: calendar,
            now: Date()
        )
        schedules.append(contentsOf: upcoming)

        return CreateAlarmResult(
            alarmId: alarm.id,
            groupId: group?.id,
            instanceCount: schedules.count,
            schedules: schedules,
            title: alarm.title
        )
    }

    public func createGroup(name: String) async throws -> UUID {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SwiftDataAlarmRepositoryError.groupNotFound }
        let group = AlarmGroup(name: trimmed)
        modelContext.insert(group)
        try modelContext.save()
        return group.id
    }

    /// Updates the core editable fields of an existing alarm (used by the edit screen) and
    /// re-materializes upcoming pending instances to match the new pattern. Historical
    /// (already fired/dismissed/snoozed) instances are left untouched.
    public func updateAlarmPattern(
        alarmId: UUID,
        title: String,
        time: ClockTime,
        daysOfWeek: [Weekday],
        endsOn: Date?,
        soundId: String,
        soundVolume: Double,
        groupId: UUID?
    ) async throws -> CreateAlarmResult {
        let alarm = try requireAlarm(id: alarmId)
        let group: AlarmGroup?
        if let groupId {
            group = try requireGroup(id: groupId)
        } else {
            group = nil
        }

        let now = Date()
        let staleInstances = alarm.instances.filter { $0.status == .pending }
        for instance in staleInstances {
            modelContext.delete(instance)
        }

        alarm.title = title
        alarm.time = time
        alarm.daysOfWeek = daysOfWeek
        alarm.endsOn = endsOn
        alarm.soundId = soundId
        alarm.soundVolume = AlarmSoundCatalog.clampVolume(soundVolume)
        alarm.group = group
        alarm.updatedAt = now
        try modelContext.save()

        let calendar = Calendar.autoupdatingCurrent
        let schedules = try materializeUpcoming(
            for: [alarm],
            horizonDays: AlarmHorizon.notificationDays,
            calendar: calendar,
            now: now
        )

        return CreateAlarmResult(
            alarmId: alarm.id,
            groupId: group?.id,
            instanceCount: schedules.count,
            schedules: schedules,
            title: alarm.title
        )
    }

    public func assignAlarm(alarmId: UUID, to groupId: UUID?) async throws {
        let alarm = try requireAlarm(id: alarmId)
        if let groupId {
            alarm.group = try requireGroup(id: groupId)
        } else {
            alarm.group = nil
        }
        alarm.updatedAt = Date()
        try modelContext.save()
    }

    @discardableResult
    public func cancelToday(groupId: UUID) async throws -> [UUID] {
        try cancelGroupToday(groupId: groupId, reason: .manualToday, now: Date())
    }

    @discardableResult
    public func cancelToday(alarmId: UUID) async throws -> [UUID] {
        try cancelAlarmToday(alarmId: alarmId, reason: .manualToday, now: Date())
    }

    @discardableResult
    public func bypassDays(groupId: UUID, from startDay: Date, to endDay: Date) async throws -> [UUID] {
        let group = try requireGroup(id: groupId)
        let cal = Calendar.autoupdatingCurrent
        let draft = BypassAlarms.draft(from: startDay, to: endDay, target: .group(groupId), calendar: cal)
        let rangeStart = draft.startDate
        let rangeLast = BypassAlarms.lastCoveredDay(
            start: draft.startDate,
            end: draft.endDate,
            type: draft.type,
            calendar: cal
        )
        guard let rangeEndExclusive = cal.date(byAdding: .day, value: 1, to: rangeLast) else { return [] }

        let exception = AlarmException(
            group: group,
            alarmId: nil,
            type: draft.type,
            startDate: draft.startDate,
            endDate: draft.endDate,
            action: .skip
        )
        modelContext.insert(exception)

        let all = try modelContext.fetch(FetchDescriptor<AlarmInstance>())
        let matching = all.filter {
            $0.alarm?.group?.id == groupId
                && $0.status == .pending
                && $0.scheduledDate >= rangeStart
                && $0.scheduledDate < rangeEndExclusive
        }
        return try cancel(instances: matching, reason: .exception)
    }

    @discardableResult
    public func bypassDays(alarmId: UUID, from startDay: Date, to endDay: Date) async throws -> [UUID] {
        _ = try requireAlarm(id: alarmId)
        let cal = Calendar.autoupdatingCurrent
        let draft = BypassAlarms.draft(from: startDay, to: endDay, target: .alarm(alarmId), calendar: cal)
        let rangeStart = draft.startDate
        let rangeLast = BypassAlarms.lastCoveredDay(
            start: draft.startDate,
            end: draft.endDate,
            type: draft.type,
            calendar: cal
        )
        guard let rangeEndExclusive = cal.date(byAdding: .day, value: 1, to: rangeLast) else { return [] }

        let exception = AlarmException(
            group: nil,
            alarmId: alarmId,
            type: draft.type,
            startDate: draft.startDate,
            endDate: draft.endDate,
            action: .skip
        )
        modelContext.insert(exception)

        let all = try modelContext.fetch(FetchDescriptor<AlarmInstance>())
        let matching = all.filter {
            $0.alarm?.id == alarmId
                && $0.status == .pending
                && $0.scheduledDate >= rangeStart
                && $0.scheduledDate < rangeEndExclusive
        }
        return try cancel(instances: matching, reason: .exception)
    }

    @discardableResult
    public func bypassDay(groupId: UUID, day: Date) async throws -> [UUID] {
        try await bypassDays(groupId: groupId, from: day, to: day)
    }

    @discardableResult
    public func bypassDay(alarmId: UUID, day: Date) async throws -> [UUID] {
        try await bypassDays(alarmId: alarmId, from: day, to: day)
    }

    @discardableResult
    public func purgeExpiredExceptions(asOf now: Date = Date()) async throws -> Int {
        let cal = Calendar.autoupdatingCurrent
        let all = try modelContext.fetch(FetchDescriptor<AlarmException>())
        var removed = 0
        for exception in all {
            let past = BypassAlarms.isFullyPast(
                start: exception.startDate,
                end: exception.endDate,
                type: exception.type,
                asOf: now,
                calendar: cal
            )
            guard past else { continue }
            modelContext.delete(exception)
            removed += 1
        }
        if removed > 0 {
            try modelContext.save()
        }
        return removed
    }

    public func skipWeek(groupId: UUID, weekStart: Date) async throws {
        let group = try requireGroup(id: groupId)
        let cal = Calendar.autoupdatingCurrent
        let start = cal.startOfDay(for: weekStart)
        guard let end = cal.date(byAdding: .day, value: 7, to: start) else { return }

        let exception = AlarmException(
            group: group,
            type: .weeklyOverride,
            startDate: start,
            endDate: cal.date(byAdding: .second, value: -1, to: end),
            action: .skip
        )
        modelContext.insert(exception)

        let all = try modelContext.fetch(FetchDescriptor<AlarmInstance>())
        let now = Date()
        for instance in all where instance.alarm?.group?.id == groupId
            && instance.status == .pending
            && instance.scheduledDate >= start
            && instance.scheduledDate < end
        {
            instance.status = .cancelled
            instance.cancelledReason = .manualWeek
            instance.updatedAt = now
        }
        try modelContext.save()
    }

    public func scheduleException(_ draft: AlarmExceptionDraft) async throws {
        let group: AlarmGroup?
        if let groupId = draft.groupId {
            group = try requireGroup(id: groupId)
        } else {
            group = nil
        }
        if let alarmId = draft.alarmId {
            _ = try requireAlarm(id: alarmId)
        }
        let exception = AlarmException(
            id: draft.id,
            group: group,
            alarmId: draft.alarmId,
            type: draft.type,
            startDate: draft.startDate,
            endDate: draft.endDate,
            action: draft.action,
            replacementGroupId: draft.replacementGroupId
        )
        modelContext.insert(exception)
        try modelContext.save()
    }

    public func isDayBypassed(alarmId: UUID, groupId: UUID?, day: Date) async throws -> Bool {
        let exceptions = try modelContext.fetch(FetchDescriptor<AlarmException>())
        let tuples = exceptions.map {
            (
                alarmId: $0.alarmId,
                groupId: $0.group?.id,
                start: $0.startDate,
                end: $0.endDate,
                action: $0.action,
                type: $0.type
            )
        }
        return BypassAlarms.isSkipped(
            day: day,
            alarmId: alarmId,
            groupId: groupId,
            exceptions: tuples
        )
    }

    @discardableResult
    public func handleWakeEvent(groupId: UUID, source: WakeSource, timestamp: Date) async throws -> [UUID] {
        let cal = Calendar.autoupdatingCurrent
        let dayStart = cal.startOfDay(for: timestamp)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return [] }

        let groupExists = try fetchGroup(id: groupId) != nil
        guard groupExists else { return [] }

        let all = try modelContext.fetch(FetchDescriptor<AlarmInstance>())
        let pending = all.filter {
            $0.alarm?.group?.id == groupId
                && $0.status == .pending
                && $0.scheduledDate >= dayStart
                && $0.scheduledDate < dayEnd
        }

        for instance in pending {
            instance.status = .cancelled
            instance.cancelledReason = .wakeWatch
            instance.updatedAt = timestamp
        }

        modelContext.insert(
            WakeEventLog(
                groupId: groupId,
                detectedAt: timestamp,
                source: source,
                confirmed: true
            )
        )
        try modelContext.save()
        return pending.map(\.id)
    }

    @discardableResult
    public func dismissAlarm(alarmId: UUID, instanceId: UUID, now: Date) async throws -> [UUID] {
        guard let instance = try fetchInstance(id: instanceId), instance.alarm?.id == alarmId else {
            // Missing locally (peer sync / already purged) — still report id for notification cancel.
            return [instanceId]
        }
        if instance.status == .cancelled || instance.status == .snoozed {
            return [instance.id]
        }
        instance.status = .cancelled
        instance.cancelledReason = .userDismiss
        instance.updatedAt = now
        try modelContext.save()
        return [instance.id]
    }

    public func snoozeAlarm(alarmId: UUID, instanceId: UUID, now: Date) async throws -> AlarmSchedule {
        let instance = try requireInstance(alarmId: alarmId, instanceId: instanceId)
        guard let alarm = instance.alarm else {
            throw SwiftDataAlarmRepositoryError.alarmNotFound
        }
        guard alarm.snoozeEnabled else {
            throw SwiftDataAlarmRepositoryError.snoozeDisabled
        }

        let fireDate = SnoozePolicy.fireDate(from: now, minutes: alarm.snoozeMinutes)
        return try materializeSnooze(
            instance: instance,
            alarm: alarm,
            fireDate: fireDate,
            now: now
        )
    }

    @discardableResult
    public func applyRemoteSnooze(
        alarmId: UUID,
        instanceId: UUID,
        fireDate: Date,
        now: Date
    ) async throws -> AlarmSchedule? {
        guard let instance = try fetchInstance(id: instanceId), instance.alarm?.id == alarmId else {
            return nil
        }
        if instance.status == .snoozed || instance.status == .cancelled {
            return nil
        }
        guard let alarm = instance.alarm else {
            throw SwiftDataAlarmRepositoryError.alarmNotFound
        }
        // Peer may snooze even if local snoozeEnabled was toggled off — honor the peer action.
        return try materializeSnooze(
            instance: instance,
            alarm: alarm,
            fireDate: fireDate,
            now: now
        )
    }

    private func materializeSnooze(
        instance: AlarmInstance,
        alarm: Alarm,
        fireDate: Date,
        now: Date
    ) throws -> AlarmSchedule {
        let calendar = Calendar.autoupdatingCurrent
        let day = calendar.startOfDay(for: fireDate)
        let comps = calendar.dateComponents([.hour, .minute], from: fireDate)
        let time = ClockTime(hour: comps.hour ?? 0, minute: comps.minute ?? 0)

        instance.status = .snoozed
        instance.cancelledReason = .snoozed
        instance.updatedAt = now

        let snoozed = AlarmInstance(
            scheduledDate: day,
            scheduledTime: time,
            status: .pending,
            updatedAt: now
        )
        snoozed.alarm = alarm
        modelContext.insert(snoozed)
        try modelContext.save()

        return AlarmSchedule(
            instanceId: snoozed.id,
            alarmId: alarm.id,
            fireDate: fireDate,
            soundId: alarm.soundId,
            soundVolume: alarm.soundVolume
        )
    }

    @discardableResult
    public func cancel(scope: BulkCancelScope, reason: CancelReason, now: Date) async throws -> [UUID] {
        switch scope {
        case .groupToday(let groupId):
            return try cancelGroupToday(groupId: groupId, reason: reason, now: now)
        case .allToday:
            return try cancelAllToday(reason: reason, now: now)
        case .allNextHours:
            let calendar = Calendar.autoupdatingCurrent
            let all = try modelContext.fetch(FetchDescriptor<AlarmInstance>())
            let matching = all.filter { instance in
                guard instance.status == .pending else { return false }
                guard let fire = AlarmFireDate.make(
                    day: instance.scheduledDate,
                    time: instance.scheduledTime,
                    calendar: calendar
                ) else { return false }
                return scope.includesFireDate(fire, now: now)
            }
            if matching.isEmpty { return [] }
            return try cancel(instances: matching, reason: reason, at: now)
        }
    }

    public func setWakeScheduleAlarm(alarmId: UUID?) async throws {
        let alarms = try modelContext.fetch(FetchDescriptor<Alarm>())
        let currentWakeId = alarms.first(where: \.isWakeSchedule)?.id
        let stamp = Date()

        if let alarmId {
            _ = try requireAlarm(id: alarmId)
            let selected = WakeSchedulePolicy.applying(selectedId: alarmId, currentWakeId: currentWakeId)
            for alarm in alarms {
                let shouldWake = alarm.id == selected
                if alarm.isWakeSchedule != shouldWake {
                    alarm.isWakeSchedule = shouldWake
                    alarm.updatedAt = stamp
                }
            }
        } else {
            for alarm in alarms where alarm.isWakeSchedule {
                alarm.isWakeSchedule = false
                alarm.updatedAt = stamp
            }
        }
        try modelContext.save()
    }

    public func todayContext() async throws -> TodayContext {
        let cal = Calendar.autoupdatingCurrent
        let now = Date()
        let today = cal.startOfDay(for: now)
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: today) else {
            return TodayContext(date: today, activeGroups: [])
        }

        let groups = try modelContext.fetch(FetchDescriptor<AlarmGroup>())
        var summaries: [ActiveGroupSummary] = []
        for group in groups where group.isActive {
            let remaining = group.alarms
                .flatMap(\.instances)
                .filter {
                    $0.status == .pending
                        && $0.scheduledDate >= today
                        && $0.scheduledDate < tomorrow
                }
                .sorted { $0.scheduledTime < $1.scheduledTime }
                .compactMap { instance -> InstanceSummary? in
                    guard let alarmId = instance.alarm?.id else { return nil }
                    return InstanceSummary(
                        id: instance.id,
                        alarmId: alarmId,
                        time: instance.scheduledTime,
                        status: instance.status
                    )
                }
            if !remaining.isEmpty {
                summaries.append(
                    ActiveGroupSummary(id: group.id, name: group.name, remainingInstances: remaining)
                )
            }
        }

        let alarms = try modelContext.fetch(FetchDescriptor<Alarm>())
        let wake = alarms.first(where: { $0.isActive && $0.isWakeSchedule })
        let nextWake = wake.flatMap {
            WakeScheduleFireDate.next(time: $0.time, now: now, calendar: cal)
        }
        return TodayContext(
            date: today,
            activeGroups: summaries,
            wakeAlarmId: wake?.id,
            wakeGroupId: wake?.group?.id,
            nextWakeFireDate: nextWake
        )
    }

    public func fetchActiveAlarms() async throws -> [AlarmSummary] {
        let alarms = try modelContext.fetch(FetchDescriptor<Alarm>())
        return alarms.filter(\.isActive).map { alarm in
            AlarmSummary(
                id: alarm.id,
                title: alarm.title,
                time: alarm.time,
                daysOfWeek: alarm.daysOfWeek,
                soundId: alarm.soundId,
                soundVolume: alarm.soundVolume,
                isActive: alarm.isActive,
                snoozeEnabled: alarm.snoozeEnabled,
                snoozeMinutes: alarm.snoozeMinutes,
                isWakeSchedule: alarm.isWakeSchedule,
                groupId: alarm.group?.id,
                groupName: alarm.group?.name
            )
        }
    }

    public func fetchActiveGroups() async throws -> [AlarmGroupSummary] {
        let groups = try modelContext.fetch(FetchDescriptor<AlarmGroup>())
        return groups.filter(\.isActive).map {
            AlarmGroupSummary(
                id: $0.id,
                name: $0.name,
                isActive: $0.isActive,
                alarmCount: $0.alarms.count
            )
        }
    }

    public func instances(on day: Date) async throws -> [DayAlarmItem] {
        let cal = Calendar.autoupdatingCurrent
        let dayStart = cal.startOfDay(for: day)
        let alarms = try modelContext.fetch(FetchDescriptor<Alarm>())
        let exceptions = try fetchExceptionTuples()
        let statusMap = try statusMapByAlarmAndDay(calendar: cal)

        let snapshots = alarms.map(Self.snapshot(from:))
        let occurrences = AlarmOccurrenceExpander.expand(
            alarms: snapshots,
            exceptions: exceptions,
            from: dayStart,
            to: dayStart,
            statuses: statusMap,
            calendar: cal
        )

        return occurrences.map { occ in
            let resolvedId = (try? instanceId(alarmId: occ.alarmId, day: occ.dayStart, calendar: cal)) ?? occ.alarmId
            return DayAlarmItem(
                instanceId: resolvedId,
                alarmId: occ.alarmId,
                groupId: occ.groupId,
                title: occ.title,
                time: occ.time,
                status: occ.status,
                groupName: occ.groupName
            )
        }
    }

    @discardableResult
    public func extendOpenEndedSchedules(
        horizonDays: Int = AlarmHorizon.notificationDays,
        calendar: Calendar = .autoupdatingCurrent,
        now: Date = Date()
    ) async throws -> [AlarmSchedule] {
        let alarms = try modelContext.fetch(FetchDescriptor<Alarm>()).filter(\.isActive)
        return try materializeUpcoming(
            for: alarms,
            horizonDays: horizonDays,
            calendar: calendar,
            now: now
        )
    }

    private func materializeUpcoming(
        for alarms: [Alarm],
        horizonDays: Int,
        calendar: Calendar,
        now: Date
    ) throws -> [AlarmSchedule] {
        guard horizonDays > 0 else { return [] }
        var cal = calendar
        cal.timeZone = calendar.timeZone
        let start = cal.startOfDay(for: now)
        guard let lastDay = cal.date(byAdding: .day, value: horizonDays - 1, to: start) else { return [] }

        let exceptions = try fetchExceptionTuples()
        var newSchedules: [AlarmSchedule] = []
        let stamp = now

        for alarm in alarms where alarm.isActive {
            let snapshot = Self.snapshot(from: alarm)
            let existingDays = Set(alarm.instances.map { cal.startOfDay(for: $0.scheduledDate) })
            let occurrences = AlarmOccurrenceExpander.expand(
                alarms: [snapshot],
                exceptions: exceptions,
                from: start,
                to: lastDay,
                calendar: cal
            )
            for occ in occurrences where !existingDays.contains(occ.dayStart) {
                let instance = AlarmInstance(
                    scheduledDate: occ.dayStart,
                    scheduledTime: alarm.time,
                    status: .pending,
                    updatedAt: stamp
                )
                instance.alarm = alarm
                modelContext.insert(instance)
                if let fire = AlarmFireDate.make(day: occ.dayStart, time: alarm.time, calendar: cal), fire > now {
                    newSchedules.append(AlarmSchedule(
                        instanceId: instance.id,
                        alarmId: alarm.id,
                        fireDate: fire,
                        soundId: alarm.soundId,
                        soundVolume: alarm.soundVolume
                    ))
                }
            }
        }

        if !newSchedules.isEmpty {
            try modelContext.save()
        }
        return newSchedules
    }

    private func fetchExceptionTuples() throws -> [BypassExceptionTuple] {
        try modelContext.fetch(FetchDescriptor<AlarmException>()).map {
            (
                alarmId: $0.alarmId,
                groupId: $0.group?.id,
                start: $0.startDate,
                end: $0.endDate,
                action: $0.action,
                type: $0.type
            )
        }
    }

    private func statusMapByAlarmAndDay(calendar: Calendar) throws -> [UUID: [Date: AlarmStatus]] {
        var map: [UUID: [Date: AlarmStatus]] = [:]
        let all = try modelContext.fetch(FetchDescriptor<AlarmInstance>())
        for instance in all {
            guard let alarmId = instance.alarm?.id else { continue }
            let day = calendar.startOfDay(for: instance.scheduledDate)
            map[alarmId, default: [:]][day] = instance.status
        }
        return map
    }

    private func instanceId(alarmId: UUID, day: Date, calendar: Calendar) throws -> UUID? {
        let dayStart = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
        return try modelContext.fetch(FetchDescriptor<AlarmInstance>()).first {
            $0.alarm?.id == alarmId
                && $0.scheduledDate >= dayStart
                && $0.scheduledDate < end
        }?.id
    }

    private static func snapshot(from alarm: Alarm) -> AlarmPatternSnapshot {
        AlarmPatternSnapshot(
            id: alarm.id,
            title: alarm.title,
            time: alarm.time,
            daysOfWeek: alarm.daysOfWeek,
            isActive: alarm.isActive,
            endsOn: alarm.endsOn,
            createdAt: alarm.createdAt,
            groupId: alarm.group?.id,
            groupName: alarm.group?.name
        )
    }

    /// Matches `cancelToday(groupId:)`: inserts a group skip exception for `now`'s day, then cancels pending.
    private func cancelGroupToday(groupId: UUID, reason: CancelReason, now: Date) throws -> [UUID] {
        let group = try requireGroup(id: groupId)
        let cal = Calendar.autoupdatingCurrent
        let start = cal.startOfDay(for: now)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }

        modelContext.insert(
            AlarmException(
                group: group,
                alarmId: nil,
                type: .singleDay,
                startDate: start,
                action: .skip
            )
        )

        let all = try modelContext.fetch(FetchDescriptor<AlarmInstance>())
        let matching = all.filter { instance in
            instance.alarm?.group?.id == groupId
                && instance.status == .pending
                && instance.scheduledDate >= start
                && instance.scheduledDate < end
        }
        if matching.isEmpty {
            try modelContext.save()
            return []
        }
        return try cancel(instances: matching, reason: reason, at: now)
    }

    /// Matches `cancelToday(alarmId:)`: inserts an alarm skip exception for `now`'s day, then cancels pending.
    private func cancelAlarmToday(alarmId: UUID, reason: CancelReason, now: Date) throws -> [UUID] {
        _ = try requireAlarm(id: alarmId)
        let cal = Calendar.autoupdatingCurrent
        let start = cal.startOfDay(for: now)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }

        modelContext.insert(
            AlarmException(
                group: nil,
                alarmId: alarmId,
                type: .singleDay,
                startDate: start,
                action: .skip
            )
        )

        let all = try modelContext.fetch(FetchDescriptor<AlarmInstance>())
        let matching = all.filter { instance in
            instance.alarm?.id == alarmId
                && instance.status == .pending
                && instance.scheduledDate >= start
                && instance.scheduledDate < end
        }
        if matching.isEmpty {
            try modelContext.save()
            return []
        }
        return try cancel(instances: matching, reason: reason, at: now)
    }

    /// Cancels all pending instances on `now`'s calendar day and inserts skip exceptions
    /// (group-level for grouped alarms, alarm-level for ungrouped) so rematerialization stays bypassed.
    private func cancelAllToday(reason: CancelReason, now: Date) throws -> [UUID] {
        let cal = Calendar.autoupdatingCurrent
        let start = cal.startOfDay(for: now)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }

        let all = try modelContext.fetch(FetchDescriptor<AlarmInstance>())
        let matching = all.filter { instance in
            instance.status == .pending
                && instance.scheduledDate >= start
                && instance.scheduledDate < end
        }

        var seenGroupIds = Set<UUID>()
        var seenUngroupedAlarmIds = Set<UUID>()
        for instance in matching {
            if let group = instance.alarm?.group {
                guard seenGroupIds.insert(group.id).inserted else { continue }
                modelContext.insert(
                    AlarmException(
                        group: group,
                        alarmId: nil,
                        type: .singleDay,
                        startDate: start,
                        action: .skip
                    )
                )
            } else if let alarmId = instance.alarm?.id {
                guard seenUngroupedAlarmIds.insert(alarmId).inserted else { continue }
                modelContext.insert(
                    AlarmException(
                        group: nil,
                        alarmId: alarmId,
                        type: .singleDay,
                        startDate: start,
                        action: .skip
                    )
                )
            }
        }

        if matching.isEmpty {
            return []
        }
        return try cancel(instances: matching, reason: reason, at: now)
    }

    private func cancel(
        instances: [AlarmInstance],
        reason: CancelReason = .manualToday,
        at now: Date = Date()
    ) throws -> [UUID] {
        var cancelledIds: [UUID] = []
        for instance in instances {
            instance.status = .cancelled
            instance.cancelledReason = reason
            instance.updatedAt = now
            cancelledIds.append(instance.id)
        }
        try modelContext.save()
        return cancelledIds
    }

    private func fetchGroup(id: UUID) throws -> AlarmGroup? {
        try modelContext.fetch(FetchDescriptor<AlarmGroup>()).first { $0.id == id }
    }

    private func fetchAlarm(id: UUID) throws -> Alarm? {
        try modelContext.fetch(FetchDescriptor<Alarm>()).first { $0.id == id }
    }

    private func fetchInstance(id: UUID) throws -> AlarmInstance? {
        try modelContext.fetch(FetchDescriptor<AlarmInstance>()).first { $0.id == id }
    }

    private func requireGroup(id: UUID) throws -> AlarmGroup {
        guard let group = try fetchGroup(id: id) else {
            throw SwiftDataAlarmRepositoryError.groupNotFound
        }
        return group
    }

    private func requireAlarm(id: UUID) throws -> Alarm {
        guard let alarm = try fetchAlarm(id: id) else {
            throw SwiftDataAlarmRepositoryError.alarmNotFound
        }
        return alarm
    }

    private func requireInstance(alarmId: UUID, instanceId: UUID) throws -> AlarmInstance {
        guard let instance = try fetchInstance(id: instanceId), instance.alarm?.id == alarmId else {
            throw SwiftDataAlarmRepositoryError.instanceNotFound
        }
        return instance
    }
}
