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
    @State private var stopTodayPulse = false

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
                        ContentUnavailableView(
                            String(localized: "alarms.empty.title"),
                            systemImage: "alarm",
                            description: Text("alarms.empty.subtitle")
                        )
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
            .toast($toastMessage, duration: 8)
            .sensoryFeedback(.success, trigger: stopTodayPulse)
        }
    }

    @ViewBuilder
    private var wakeScheduleRow: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if let wakeAlarm {
                    AlarmTimeText(formatTime(wakeAlarm.time), style: .listRow)
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
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(wakeAlarm != nil ? .isButton : [])

            Spacer(minLength: 8)

            Button("alarms.change") {
                if let wakeAlarm {
                    wakeDetailId = wakeAlarm.id
                } else {
                    createAsWakeSchedule = true
                    isCreating = true
                }
            }
            .buttonStyle(.borderless)
            .tint(AlarmColors.warn)
            .font(.subheadline.weight(.semibold))
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
                    AlarmTimeText(formatTime(alarm.time), style: .listRowSecondary)
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
                        withAnimation(.spring(response: 0.3, dampingFraction: 1)) {
                            alarm.isActive = newValue
                        }
                        alarm.updatedAt = Date()
                        try? modelContext.save()
                    }
                )
            )
            .labelsHidden()
            .tint(AlarmColors.success)
            .accessibilityLabel(Text("\(alarm.title) \(formatTime(alarm.time))"))
            .sensoryFeedback(.selection, trigger: alarm.isActive)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("action.stop_today") {
                Task { await cancelToday(alarm: alarm) }
            }
            .tint(AlarmColors.warn)
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
            await HybridAlarmScheduler().cancelPending(instanceIds: cancelled)
            let name = alarm.title
            await MainActor.run {
                toastMessage = String(format: String(localized: "toast.stopped_today"), name)
                stopTodayPulse.toggle()
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
