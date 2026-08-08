import SwiftUI
import SwiftData
import AlarmAppCore

struct WatchRingingSession: Identifiable, Equatable, Sendable {
    var id: UUID { instanceId }
    let alarmId: UUID
    let instanceId: UUID
    let groupId: UUID?
    let title: String
    let timeText: String
    let snoozeEnabled: Bool
}

enum WatchRingingPrimaryAction {
    case dismiss
    case snooze
    case more
}

enum WatchRingingBulkAction {
    case groupToday
    case nextThreeHours
    case allToday
}

struct AlarmRingingView: View {
    let session: WatchRingingSession
    var onFinished: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showsMore = false
    @State private var showsPostDismissOffer = false
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var confirmTrigger = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if showsPostDismissOffer {
                    postDismissOffer
                } else {
                    Text(session.timeText)
                        .font(.system(size: 34, weight: .ultraLight))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    Text(session.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if showsMore {
                        moreActions
                    } else {
                        primaryActions
                    }

                    Button("action.cancel") {
                        onFinished()
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .disabled(isBusy)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(
            showsPostDismissOffer ? String(localized: "watch.title_wake") : (showsMore ? String(localized: "ringing.more") : String(localized: "watch.title_alarm"))
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsMore, !showsPostDismissOffer {
                ToolbarItem(placement: .topBarLeading) {
                    Button("ringing.back") { showsMore = false }
                        .disabled(isBusy)
                }
            }
        }
        .alert("error.generic_title", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("action.done", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sensoryFeedback(.success, trigger: confirmTrigger)
        .animation(
            reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.3, dampingFraction: 1),
            value: showsMore || showsPostDismissOffer
        )
    }

    private var primaryActions: some View {
        VStack(spacing: 8) {
            watchButton(title: String(localized: "ringing.dismiss"), systemImage: "stop.circle.fill") {
                await perform(.dismiss)
            }
            if session.snoozeEnabled {
                watchButton(title: String(localized: "ringing.snooze"), systemImage: "zzz", tint: .orange) {
                    await perform(.snooze)
                }
            }
            watchButton(title: String(localized: "ringing.more"), systemImage: "ellipsis.circle") {
                showsMore = true
            }
        }
    }

    private var moreActions: some View {
        VStack(spacing: 8) {
            if session.groupId != nil {
                watchButton(title: String(localized: "ringing.group_today"), systemImage: "rectangle.3.group") {
                    await performBulk(.groupToday)
                }
            }
            watchButton(title: String(localized: "ringing.next_three_hours"), systemImage: "clock.badge.xmark") {
                await performBulk(.nextThreeHours)
            }
            watchButton(title: String(localized: "ringing.all_today"), systemImage: "calendar.badge.minus") {
                await performBulk(.allToday)
            }
        }
    }

    private var postDismissOffer: some View {
        VStack(spacing: 12) {
            Text("wake.prompt.title")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("wake.prompt.message")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            watchButton(title: String(localized: "wake.prompt.yes"), systemImage: "checkmark.circle.fill", tint: .orange.opacity(0.85)) {
                await confirmPostDismissGroupCancel()
            }
            watchButton(title: String(localized: "wake.prompt.no"), systemImage: "xmark.circle") {
                onFinished()
            }
        }
    }

    private func watchButton(
        title: String,
        systemImage: String,
        tint: Color = .white.opacity(0.16),
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .padding(.horizontal, 6)
                .background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .opacity(isBusy ? 0.5 : 1)
    }

    private func perform(_ action: WatchRingingPrimaryAction) async {
        switch action {
        case .more:
            showsMore = true
        case .dismiss:
            await dismissThenMaybeOffer()
        case .snooze:
            await runConfirmed {
                let repo = SwiftDataAlarmRepository(modelContainer: modelContext.container)
                let schedule = try await repo.snoozeAlarm(
                    alarmId: session.alarmId,
                    instanceId: session.instanceId,
                    now: Date()
                )
                let scheduler = LocalNotificationScheduler()
                await scheduler.cancelPending(instanceIds: [session.instanceId])
                try await scheduler.schedule(
                    instanceId: schedule.instanceId,
                    alarmId: schedule.alarmId,
                    fireDate: schedule.fireDate,
                    title: session.title,
                    body: String(format: String(localized: "notif.alarm_body"), session.timeText),
                    soundId: schedule.soundId,
                    soundVolume: schedule.soundVolume
                )
                WatchSyncBootstrap.shared.send(
                    .snoozeApplied(
                        alarmId: session.alarmId,
                        instanceId: session.instanceId,
                        fireDate: schedule.fireDate
                    )
                )
            }
        }
    }

    private func dismissThenMaybeOffer() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let repo = SwiftDataAlarmRepository(modelContainer: modelContext.container)
            let cancelled = try await repo.dismissAlarm(
                alarmId: session.alarmId,
                instanceId: session.instanceId,
                now: Date()
            )
            await LocalNotificationScheduler().cancelPending(instanceIds: cancelled)
            WatchSyncBootstrap.shared.send(
                .dismissApplied(alarmId: session.alarmId, instanceId: session.instanceId)
            )
            confirmTrigger.toggle()

            if let groupId = session.groupId {
                let remaining = try await repo.countPendingInGroupToday(groupId: groupId, now: Date())
                if PostDismissWakeOfferPolicy.shouldOffer(
                    groupId: groupId,
                    remainingPendingInGroupToday: remaining
                ) {
                    showsPostDismissOffer = true
                    return
                }
            }
            onFinished()
        } catch {
            AppLog.error(.wake, "watch dismiss failed", error: error)
            errorMessage = error.localizedDescription
        }
    }

    private func confirmPostDismissGroupCancel() async {
        guard let groupId = session.groupId else {
            onFinished()
            return
        }
        await runConfirmed {
            let repo = SwiftDataAlarmRepository(modelContainer: modelContext.container)
            let now = Date()
            let scope = BulkCancelScope.groupToday(groupId)
            let cancelled = try await repo.cancel(scope: scope, reason: .wakePrompt, now: now)
            await LocalNotificationScheduler().cancelPending(instanceIds: cancelled)
            WatchSyncBootstrap.shared.send(
                .bulkCancelApplied(scope: scope, timestamp: now)
            )
        }
    }

    private func performBulk(_ action: WatchRingingBulkAction) async {
        await runConfirmed {
            let repo = SwiftDataAlarmRepository(modelContainer: modelContext.container)
            let now = Date()
            let scope: BulkCancelScope
            let reason: CancelReason
            switch action {
            case .groupToday:
                guard let groupId = session.groupId else { return }
                scope = .groupToday(groupId)
                reason = .manualToday
            case .nextThreeHours:
                scope = .allNextHours(3)
                reason = .nextHoursWindow
            case .allToday:
                scope = .allToday
                reason = .manualToday
            }
            let cancelled = try await repo.cancel(scope: scope, reason: reason, now: now)
            await LocalNotificationScheduler().cancelPending(instanceIds: cancelled)
            WatchSyncBootstrap.shared.send(
                .bulkCancelApplied(scope: scope, timestamp: now)
            )
        }
    }

    private func runConfirmed(_ work: () async throws -> Void) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await work()
            confirmTrigger.toggle()
            onFinished()
        } catch {
            AppLog.error(.wake, "watch ringing action failed", error: error)
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        AlarmRingingView(
            session: WatchRingingSession(
                alarmId: UUID(),
                instanceId: UUID(),
                groupId: UUID(),
                title: "Sabah",
                timeText: "06:30",
                snoozeEnabled: true
            ),
            onFinished: {}
        )
    }
    .modelContainer(try! ModelContainerFactory.makeInMemory())
}
