import Foundation
import SwiftData

public enum SwiftDataAlarmRepositoryError: Error, Sendable {
    case groupNotFound
    case alarmNotFound
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
        let group = try requireGroup(id: groupId)
        let cal = Calendar.autoupdatingCurrent
        let start = cal.startOfDay(for: Date())
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
        return try cancel(instances: matching, reason: .manualToday)
    }

    @discardableResult
    public func cancelToday(alarmId: UUID) async throws -> [UUID] {
        _ = try requireAlarm(id: alarmId)
        let cal = Calendar.autoupdatingCurrent
        let start = cal.startOfDay(for: Date())
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
        return try cancel(instances: matching, reason: .manualToday)
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

    public func handleWakeEvent(groupId: UUID, source: WakeSource, timestamp: Date) async throws {
        let cal = Calendar.autoupdatingCurrent
        let dayStart = cal.startOfDay(for: timestamp)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return }

        let groupExists = try fetchGroup(id: groupId) != nil
        guard groupExists else { return }

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
    }

    public func todayContext() async throws -> TodayContext {
        let cal = Calendar.autoupdatingCurrent
        let today = cal.startOfDay(for: Date())
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
                .map { InstanceSummary(id: $0.id, time: $0.scheduledTime, status: $0.status) }
            if !remaining.isEmpty {
                summaries.append(
                    ActiveGroupSummary(id: group.id, name: group.name, remainingInstances: remaining)
                )
            }
        }
        return TodayContext(date: today, activeGroups: summaries)
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

    private func cancel(instances: [AlarmInstance], reason: CancelReason = .manualToday) throws -> [UUID] {
        let now = Date()
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
}
