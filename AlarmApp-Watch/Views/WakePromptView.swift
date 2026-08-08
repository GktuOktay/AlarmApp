import SwiftUI
import SwiftData
import AlarmAppCore

/// Apple Sleep Focus–style early wake confirmation. Hayır / dismiss = no-op.
struct WakePromptView: View {
    let context: WakeDetectionCoordinator.WakePromptContext
    var onFinished: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showsBulkOptions = false
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var confirmTrigger = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if showsBulkOptions {
                    bulkOptions
                } else {
                    promptContent
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(showsBulkOptions ? String(localized: "watch.title_close") : String(localized: "watch.title_wake"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsBulkOptions {
                ToolbarItem(placement: .topBarLeading) {
                    Button("ringing.back") { showsBulkOptions = false }
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
            value: showsBulkOptions
        )
    }

    private var promptContent: some View {
        VStack(spacing: 12) {
            Text("wake.prompt.title")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("wake.prompt.message")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                WakeDetectionCoordinator.shared.acknowledgePromptShowingOptions()
                showsBulkOptions = true
            } label: {
                Text("wake.prompt.yes")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(Color.orange.opacity(0.85), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isBusy)

            Button {
                WakeDetectionCoordinator.shared.dismissPromptWithoutAction()
                onFinished()
            } label: {
                Text("wake.prompt.no")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
        }
    }

    private var bulkOptions: some View {
        VStack(spacing: 8) {
            if context.groupId != nil {
                watchButton(title: String(localized: "ringing.group_today"), systemImage: "rectangle.3.group") {
                    await performDefaultOrBulk(.groupToday)
                }
            } else {
                watchButton(title: String(localized: "watch.wake_alarm_today"), systemImage: "alarm") {
                    await cancelWakeAlarmToday()
                }
            }
            watchButton(title: String(localized: "ringing.next_three_hours"), systemImage: "clock.badge.xmark") {
                await performDefaultOrBulk(.nextThreeHours)
            }
            watchButton(title: String(localized: "ringing.all_today"), systemImage: "calendar.badge.minus") {
                await performDefaultOrBulk(.allToday)
            }
            Button("action.cancel") {
                WakeDetectionCoordinator.shared.dismissPromptWithoutAction()
                onFinished()
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .disabled(isBusy)
        }
    }

    private func watchButton(
        title: String,
        systemImage: String,
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
                .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .opacity(isBusy ? 0.5 : 1)
    }

    private enum BulkChoice {
        case groupToday
        case nextThreeHours
        case allToday
    }

    private func performDefaultOrBulk(_ choice: BulkChoice) async {
        await runConfirmed {
            let repo = SwiftDataAlarmRepository(modelContainer: modelContext.container)
            let now = Date()
            let scope: BulkCancelScope
            switch choice {
            case .groupToday:
                guard let groupId = context.groupId else { return }
                scope = .groupToday(groupId)
            case .nextThreeHours:
                scope = .allNextHours(3)
            case .allToday:
                scope = .allToday
            }
            let cancelled = try await repo.cancel(scope: scope, reason: .wakePrompt, now: now)
            await LocalNotificationScheduler().cancelPending(instanceIds: cancelled)
            WatchSyncBootstrap.shared.send(
                .bulkCancelApplied(scope: scope, timestamp: now)
            )
            WakeDetectionCoordinator.shared.clearPrompt()
        }
    }

    private func cancelWakeAlarmToday() async {
        await runConfirmed {
            let repo = SwiftDataAlarmRepository(modelContainer: modelContext.container)
            let cancelled = try await repo.cancelToday(alarmId: context.wakeAlarmId)
            await LocalNotificationScheduler().cancelPending(instanceIds: cancelled)
            for instanceId in cancelled {
                WatchSyncBootstrap.shared.send(
                    .dismissApplied(alarmId: context.wakeAlarmId, instanceId: instanceId)
                )
            }
            WakeDetectionCoordinator.shared.clearPrompt()
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
            AppLog.error(.wake, "wake prompt action failed", error: error)
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        WakePromptView(
            context: .init(
                wakeAlarmId: UUID(),
                groupId: UUID(),
                title: "Uyanma",
                offeredAt: Date()
            ),
            onFinished: {}
        )
    }
    .modelContainer(try! ModelContainerFactory.makeInMemory())
}
