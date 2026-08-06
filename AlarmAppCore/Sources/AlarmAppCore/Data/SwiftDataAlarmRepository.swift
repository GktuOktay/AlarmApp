import Foundation
import SwiftData

public enum SwiftDataAlarmRepositoryError: Error, Sendable {
    case groupNotFound
}

@ModelActor
public actor SwiftDataAlarmRepository: AlarmRepository {
    public func createGroup(from prepared: PreparedAlarmGroup) async throws -> CreateAlarmGroupResult {
        let group = AlarmGroup(
            id: prepared.id,
            name: prepared.name,
            timeStart: prepared.timeStart,
            timeEnd: prepared.timeEnd,
            intervalMinutes: prepared.intervalMinutes,
            daysOfWeek: prepared.daysOfWeek,
            soundId: prepared.soundId,
            createdAt: prepared.createdAt,
            updatedAt: prepared.updatedAt
        )
        modelContext.insert(group)

        for spec in prepared.instances {
            let instance = AlarmInstance(
                scheduledDate: spec.scheduledDate,
                scheduledTime: spec.scheduledTime,
                status: .pending,
                updatedAt: prepared.updatedAt
            )
            instance.group = group
            modelContext.insert(instance)
        }

        try modelContext.save()
        return CreateAlarmGroupResult(
            groupId: group.id,
            instanceCount: prepared.instances.count,
            clockTimesPerDay: try AlarmInstanceGenerator.clockTimes(
                start: prepared.timeStart,
                end: prepared.timeEnd,
                intervalMinutes: prepared.intervalMinutes
            )
        )
    }

    public func cancelToday(groupId: UUID) async throws {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return }

        let all = try modelContext.fetch(FetchDescriptor<AlarmInstance>())
        let matching = all.filter { instance in
            instance.group?.id == groupId
                && instance.status == .pending
                && instance.scheduledDate >= start
                && instance.scheduledDate < end
        }
        let groupExists = try fetchGroup(id: groupId) != nil
        guard !matching.isEmpty || groupExists else {
            throw SwiftDataAlarmRepositoryError.groupNotFound
        }
        let now = Date()
        for instance in matching {
            instance.status = .cancelled
            instance.cancelledReason = .manualToday
            instance.updatedAt = now
        }
        try modelContext.save()
    }

    public func skipWeek(groupId: UUID, weekStart: Date) async throws {
        let group = try requireGroup(id: groupId)
        let cal = Calendar.current
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
        for instance in all where instance.group?.id == groupId
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
        let exception = AlarmException(
            id: draft.id,
            group: group,
            type: draft.type,
            startDate: draft.startDate,
            endDate: draft.endDate,
            action: draft.action,
            replacementGroupId: draft.replacementGroupId
        )
        modelContext.insert(exception)
        try modelContext.save()
    }

    public func handleWakeEvent(groupId: UUID, source: WakeSource, timestamp: Date) async throws {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: timestamp)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return }

        let all = try modelContext.fetch(FetchDescriptor<AlarmInstance>())
        let pending = all.filter {
            $0.group?.id == groupId
                && $0.status == .pending
                && $0.scheduledDate >= dayStart
                && $0.scheduledDate < dayEnd
        }
        let groupExists = try fetchGroup(id: groupId) != nil
        guard !pending.isEmpty || groupExists else { return }

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
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: today) else {
            return TodayContext(date: today, activeGroups: [])
        }

        let groups = try modelContext.fetch(FetchDescriptor<AlarmGroup>())
        var summaries: [ActiveGroupSummary] = []
        for group in groups where group.isActive {
            let remaining = group.instances
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

    public func fetchActiveGroups() async throws -> [AlarmGroupSummary] {
        let groups = try modelContext.fetch(FetchDescriptor<AlarmGroup>())
        return groups.filter(\.isActive).map {
            AlarmGroupSummary(
                id: $0.id,
                name: $0.name,
                timeStart: $0.timeStart,
                timeEnd: $0.timeEnd,
                intervalMinutes: $0.intervalMinutes,
                daysOfWeek: $0.daysOfWeek,
                soundId: $0.soundId,
                isActive: $0.isActive
            )
        }
    }

    private func fetchGroup(id: UUID) throws -> AlarmGroup? {
        try modelContext.fetch(FetchDescriptor<AlarmGroup>()).first { $0.id == id }
    }

    private func requireGroup(id: UUID) throws -> AlarmGroup {
        guard let group = try fetchGroup(id: id) else {
            throw SwiftDataAlarmRepositoryError.groupNotFound
        }
        return group
    }
}
