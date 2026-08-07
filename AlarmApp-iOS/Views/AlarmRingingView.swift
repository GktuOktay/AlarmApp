import SwiftUI
import SwiftData
import AlarmAppCore

struct AlarmRingingView: View {
    let session: RingingSession
    var onFinished: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showsMore = false
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var confirmPulse = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 28) {
                    Spacer(minLength: 24)

                    VStack(spacing: 8) {
                        Text(session.timeText)
                            .font(.system(size: 72, weight: .ultraLight, design: .default))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)

                        Text(session.title)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)

                    Spacer()

                    if showsMore {
                        moreActions
                            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    } else {
                        primaryActions
                            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    }

                    Button("action.cancel") {
                        onFinished()
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .disabled(isBusy)
                    .padding(.bottom, 12)
                }
                .padding(.horizontal, 24)
                .animation(
                    reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.32, dampingFraction: 1),
                    value: showsMore
                )
            }
            .toolbar {
                if showsMore {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("ringing.back") {
                            showsMore = false
                        }
                        .foregroundStyle(.orange)
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
            .sensoryFeedback(.success, trigger: confirmPulse)
            .interactiveDismissDisabled(isBusy)
        }
    }

    private var primaryActions: some View {
        VStack(spacing: 12) {
            ringingButton(
                titleKey: "ringing.dismiss",
                systemImage: "stop.circle.fill",
                tint: .white,
                foreground: .black
            ) {
                await perform(.dismiss)
            }

            if session.snoozeEnabled {
                ringingButton(
                    titleKey: "ringing.snooze",
                    systemImage: "zzz",
                    tint: .orange,
                    foreground: .white
                ) {
                    await perform(.snooze)
                }
            }

            ringingButton(
                titleKey: "ringing.more",
                systemImage: "ellipsis.circle.fill",
                tint: .white.opacity(0.18),
                foreground: .white
            ) {
                showsMore = true
            }
        }
    }

    private var moreActions: some View {
        VStack(spacing: 12) {
            if session.groupId != nil {
                ringingButton(
                    titleKey: "ringing.group_today",
                    systemImage: "rectangle.3.group.fill",
                    tint: .white.opacity(0.18),
                    foreground: .white
                ) {
                    await performBulk(.groupToday)
                }
            }

            ringingButton(
                titleKey: "ringing.next_three_hours",
                systemImage: "clock.badge.xmark",
                tint: .white.opacity(0.18),
                foreground: .white
            ) {
                await performBulk(.nextThreeHours)
            }

            ringingButton(
                titleKey: "ringing.all_today",
                systemImage: "calendar.badge.minus",
                tint: .white.opacity(0.18),
                foreground: .white
            ) {
                await performBulk(.allToday)
            }
        }
    }

    private func ringingButton(
        titleKey: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        foreground: Color,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            Label(titleKey, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .padding(.horizontal, 12)
                .background(tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(foreground)
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .opacity(isBusy ? 0.55 : 1)
    }

    private func perform(_ action: RingingPrimaryAction) async {
        switch action {
        case .more:
            showsMore = true
        case .dismiss:
            await runConfirmed {
                let repo = SwiftDataAlarmRepository(modelContainer: modelContext.container)
                let cancelled = try await repo.dismissAlarm(
                    alarmId: session.alarmId,
                    instanceId: session.instanceId,
                    now: Date()
                )
                await LocalNotificationScheduler().cancelPending(instanceIds: cancelled)
            }
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
                let timeText = String(
                    format: "%02d:%02d",
                    Calendar.autoupdatingCurrent.component(.hour, from: schedule.fireDate),
                    Calendar.autoupdatingCurrent.component(.minute, from: schedule.fireDate)
                )
                try await scheduler.schedule(
                    instanceId: schedule.instanceId,
                    alarmId: schedule.alarmId,
                    fireDate: schedule.fireDate,
                    title: session.title,
                    body: String(format: String(localized: "notif.alarm_body"), timeText),
                    soundId: schedule.soundId,
                    soundVolume: schedule.soundVolume
                )
            }
        }
    }

    private func performBulk(_ action: RingingBulkAction) async {
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
        }
    }

    private func runConfirmed(_ work: () async throws -> Void) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await work()
            confirmPulse.toggle()
            onFinished()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AlarmRingingView(
        session: RingingSession(
            alarmId: UUID(),
            instanceId: UUID(),
            groupId: UUID(),
            title: "Sabah",
            timeText: "06:30",
            snoozeEnabled: true
        ),
        onFinished: {}
    )
    .modelContainer(try! ModelContainerFactory.makeInMemory())
}
