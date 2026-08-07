import SwiftUI
import SwiftData
import AlarmAppCore

struct AlarmListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Alarm.timeMinutes) private var alarms: [Alarm]
    @State private var isCreating = false
    @State private var createAsWakeSchedule = false
    @State private var errorMessage: String?
    @State private var toastMessage: String?
    @State private var wakeDetailId: UUID?

    private var wakeAlarm: Alarm? {
        alarms.first(where: \.isWakeSchedule)
    }

    private var otherAlarms: [Alarm] {
        alarms.filter { !$0.isWakeSchedule }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    wakeScheduleRow
                } header: {
                    Label("alarms.sleep_wake_section", systemImage: "bed.double.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }

                Section {
                    if otherAlarms.isEmpty {
                        Text("alarms.other_empty")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(otherAlarms, id: \.id) { alarm in
                            otherAlarmRow(alarm)
                        }
                    }
                } header: {
                    Text("alarms.other_section")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("alarms.title")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        createAsWakeSchedule = false
                        isCreating = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("alarms.create"))
                }
            }
            .sheet(isPresented: $isCreating) {
                NavigationStack {
                    CreateAlarmView(preferWakeSchedule: createAsWakeSchedule) {
                        isCreating = false
                        createAsWakeSchedule = false
                    }
                }
            }
            .navigationDestination(item: $wakeDetailId) { id in
                if let alarm = alarms.first(where: { $0.id == id }) {
                    AlarmDetailView(alarm: alarm)
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
            .overlay(alignment: .bottom) {
                if let toastMessage {
                    Text(toastMessage)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 1), value: toastMessage)
        }
    }

    @ViewBuilder
    private var wakeScheduleRow: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if let wakeAlarm {
                    Text(formatTime(wakeAlarm.time))
                        .font(.system(size: 44, weight: .light))
                        .monospacedDigit()
                        .foregroundStyle(wakeAlarm.isActive ? .primary : .secondary)
                    Text(alarmMeta(wakeAlarm))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("alarms.no_wake")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("alarms.no_wake_subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 8)

            Button {
                if let wakeAlarm {
                    wakeDetailId = wakeAlarm.id
                } else {
                    createAsWakeSchedule = true
                    isCreating = true
                }
            } label: {
                Text("alarms.change")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("alarms.change"))
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            if let wakeAlarm {
                wakeDetailId = wakeAlarm.id
            }
        }
    }

    @ViewBuilder
    private func otherAlarmRow(_ alarm: Alarm) -> some View {
        HStack(spacing: 12) {
            NavigationLink {
                AlarmDetailView(alarm: alarm)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatTime(alarm.time))
                        .font(.system(size: 40, weight: .light))
                        .monospacedDigit()
                        .foregroundStyle(alarm.isActive ? .primary : .secondary)
                    Text(alarmMeta(alarm))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Toggle(
                "",
                isOn: Binding(
                    get: { alarm.isActive },
                    set: { newValue in
                        alarm.isActive = newValue
                        alarm.updatedAt = Date()
                        try? modelContext.save()
                    }
                )
            )
            .labelsHidden()
            .tint(.green)
            .sensoryFeedback(.selection, trigger: alarm.isActive)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("action.stop_today") {
                Task { await cancelToday(alarm: alarm) }
            }
            .tint(.orange)
        }
    }

    private func alarmMeta(_ alarm: Alarm) -> String {
        var parts: [String] = [alarm.title]
        let days = alarm.daysOfWeek
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.shortLabel)
            .joined(separator: " ")
        if !days.isEmpty {
            parts.append(days)
        }
        if let groupName = alarm.group?.name {
            parts.append(groupName)
        }
        return parts.joined(separator: ", ")
    }

    private func formatTime(_ time: ClockTime) -> String {
        String(format: "%02d:%02d", time.hour, time.minute)
    }

    private func cancelToday(alarm: Alarm) async {
        do {
            let repo = SwiftDataAlarmRepository(modelContainer: modelContext.container)
            let cancelled: [UUID]
            if let groupId = alarm.group?.id {
                cancelled = try await repo.cancelToday(groupId: groupId)
            } else {
                cancelled = try await repo.cancelToday(alarmId: alarm.id)
            }
            await LocalNotificationScheduler().cancelPending(instanceIds: cancelled)
            let name = alarm.title
            await MainActor.run {
                toastMessage = String(format: String(localized: "toast.stopped_today"), name)
                Task {
                    try? await Task.sleep(for: .seconds(8))
                    if toastMessage?.contains(name) == true {
                        toastMessage = nil
                    }
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = String(localized: "error.stop_today")
            }
        }
    }
}

#Preview {
    AlarmListView()
        .modelContainer(try! ModelContainerFactory.makeInMemory())
}
