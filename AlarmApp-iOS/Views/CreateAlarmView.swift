import SwiftUI
import SwiftData
import AlarmAppCore

struct CreateAlarmView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \AlarmGroup.name) private var groups: [AlarmGroup]

    var preselectedGroupId: UUID? = nil
    var preferWakeSchedule: Bool = false
    var onFinished: () -> Void

    @State private var title = "Sabah"
    @State private var timeDate = Calendar.current.date(
        bySettingHour: 6, minute: 0, second: 0, of: Date()
    ) ?? Date()
    @State private var selectedDays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    @State private var repeats = false
    @State private var hasEndDate = false
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var groupSelection: GroupSelection = .none
    @State private var newGroupName = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var overlapWarning: String?
    @State private var didApplyPreselection = false
    @State private var soundId = "default"
    @State private var soundVolumePercent: Double = 100
    @State private var soundPreview = AlarmSoundPreview()
    @State private var savedPulse = false
    @State private var snoozeEnabled = true
    @State private var snoozeMinutes = SnoozePolicy.defaultMinutes
    @State private var isWakeSchedule = false
    @FocusState private var isNameFieldFocused: Bool

    enum GroupSelection: Hashable {
        case none
        case existing(UUID)
        case createNew
    }

    private struct OverlapKey: Equatable {
        let time: Date
        let days: Set<Weekday>
        let repeats: Bool
    }

    private var repeatsSummary: String {
        guard repeats else { return String(localized: "create.off") }
        if selectedDays.isEmpty { return String(localized: "create.off") }
        return selectedDays
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.shortLabel)
            .joined(separator: " ")
    }

    private var endDateSummary: String {
        guard repeats, hasEndDate else { return String(localized: "detail.ends_none") }
        return endDate.formatted(date: .abbreviated, time: .omitted)
    }

    private var snoozeSummary: String {
        guard snoozeEnabled else { return String(localized: "create.off") }
        return String(format: String(localized: "create.snooze_minutes"), snoozeMinutes)
    }

    private var wakeScheduleSummary: String {
        isWakeSchedule ? String(localized: "create.wake_schedule") : String(localized: "create.off")
    }

    private var groupSummary: String {
        switch groupSelection {
        case .none:
            return String(localized: "create.group_none")
        case .existing(let id):
            return groups.first(where: { $0.id == id })?.name ?? String(localized: "create.group_none")
        case .createNew:
            return newGroupName.isEmpty ? String(localized: "create.group_new") : newGroupName
        }
    }

    private var soundSummary: String {
        let sound = AlarmSoundCatalog.all.first { $0.id == soundId } ?? AlarmSoundCatalog.all[0]
        return String(localized: String.LocalizationValue(sound.displayNameKey))
    }

    var body: some View {
        Form {
            Section {
                DatePicker(
                    "create.time",
                    selection: $timeDate,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .accessibilityLabel(Text("create.time"))
            }

            Section {
                TextField("create.name", text: $title)
                    .focused($isNameFieldFocused)
            }

            if let overlapWarning {
                Section {
                    Text(overlapWarning)
                        .font(.footnote)
                        .foregroundStyle(AlarmColors.warn)
                }
            }

            Section {
                NavigationLink {
                    RepeatsPickerView(repeats: $repeats, selectedDays: $selectedDays)
                } label: {
                    LabeledContent("create.repeats", value: repeatsSummary)
                }

                if repeats {
                    NavigationLink {
                        EndDatePickerView(hasEndDate: $hasEndDate, endDate: $endDate)
                    } label: {
                        LabeledContent("create.end_toggle", value: endDateSummary)
                    }
                }

                NavigationLink {
                    SnoozePickerView(snoozeEnabled: $snoozeEnabled, snoozeMinutes: $snoozeMinutes)
                } label: {
                    LabeledContent("create.snooze", value: snoozeSummary)
                }

                NavigationLink {
                    WakeSchedulePickerView(isWakeSchedule: $isWakeSchedule)
                } label: {
                    LabeledContent("create.wake_schedule", value: wakeScheduleSummary)
                }

                NavigationLink {
                    GroupPickerView(groupSelection: $groupSelection, newGroupName: $newGroupName, groups: groups)
                } label: {
                    LabeledContent("create.group_section", value: groupSummary)
                }

                NavigationLink {
                    SoundPickerView(soundId: $soundId, soundVolumePercent: $soundVolumePercent, soundPreview: soundPreview)
                } label: {
                    LabeledContent("create.sound_section", value: soundSummary)
                }
            }
        }
        .task(id: OverlapKey(time: timeDate, days: selectedDays, repeats: repeats)) {
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            await refreshOverlapWarning()
        }
        .animation(.spring(response: 0.3, dampingFraction: 1), value: overlapWarning)
        .animation(.spring(response: 0.3, dampingFraction: 1), value: repeats)
        .sensoryFeedback(.success, trigger: savedPulse)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("action.done") { isNameFieldFocused = false }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("action.cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("action.save") {
                    Task { await save() }
                }
                .disabled(
                    isSaving
                        || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || (repeats && selectedDays.isEmpty)
                        || (groupSelection == .createNew
                            && newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                )
            }
        }
        .alert("create.save_failed_title", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("action.done", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            if !didApplyPreselection {
                if let preselectedGroupId {
                    groupSelection = .existing(preselectedGroupId)
                }
                if preferWakeSchedule {
                    isWakeSchedule = true
                }
                didApplyPreselection = true
            }
        }
        .onDisappear {
            soundPreview.stop()
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let repo = SwiftDataAlarmRepository(modelContainer: modelContext.container)
            let groupId: UUID?
            switch groupSelection {
            case .none:
                groupId = nil
            case .existing(let id):
                groupId = id
            case .createNew:
                groupId = try await repo.createGroup(name: newGroupName)
            }

            let time = clockTime(from: timeDate)
            let clampedSnooze = SnoozePolicy.clampMinutes(snoozeMinutes)
            let request = CreateAlarmRequest(
                title: title,
                time: time,
                daysOfWeek: Array(selectedDays),
                soundId: soundId,
                soundVolume: soundVolumePercent / 100.0,
                groupId: groupId,
                repeats: repeats,
                horizonDays: AlarmHorizon.notificationDays,
                endDate: (repeats && hasEndDate) ? endDate : nil,
                snoozeEnabled: snoozeEnabled,
                snoozeMinutes: clampedSnooze,
                isWakeSchedule: false
            )
            let prepared = try CreateAlarm().prepare(request)

            overlapWarning = try await computeOverlapWarning(
                repo: repo,
                days: prepared.daysOfWeek,
                time: prepared.time
            )

            let result = try await repo.createAlarm(from: prepared)
            if isWakeSchedule {
                try await repo.setWakeScheduleAlarm(alarmId: result.alarmId)
            }

            let scheduler = HybridAlarmScheduler()
            let authorized = try await scheduler.requestAuthorization()
            if authorized {
                let now = Date()
                for schedule in result.schedules where schedule.fireDate > now {
                    let timeText = String(
                        format: "%02d:%02d",
                        Calendar.autoupdatingCurrent.component(.hour, from: schedule.fireDate),
                        Calendar.autoupdatingCurrent.component(.minute, from: schedule.fireDate)
                    )
                    try await scheduler.schedule(
                        instanceId: schedule.instanceId,
                        alarmId: schedule.alarmId,
                        fireDate: schedule.fireDate,
                        title: result.title,
                        body: String(format: String(localized: "notif.alarm_body"), timeText),
                        soundId: schedule.soundId,
                        soundVolume: schedule.soundVolume
                    )
                }
            }

            savedPulse.toggle()
            onFinished()
            dismiss()
        } catch {
            AppLog.error(.swiftdata, "createAlarm save failed", error: error)
            errorMessage = String(localized: "create.save_failed")
        }
    }

    private func refreshOverlapWarning() async {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            overlapWarning = nil
            return
        }
        let repo = SwiftDataAlarmRepository(modelContainer: modelContext.container)
        let time = clockTime(from: timeDate)
        let todayWeekday = Weekday.from(calendarWeekday: Calendar.autoupdatingCurrent.component(.weekday, from: Date())) ?? .monday
        let days = repeats ? Array(selectedDays) : [todayWeekday]
        do {
            overlapWarning = try await computeOverlapWarning(repo: repo, days: days, time: time)
        } catch {
            // Non-fatal: reactive check failures are silently ignored; save() still guards.
        }
    }

    private func computeOverlapWarning(
        repo: SwiftDataAlarmRepository,
        days: [Weekday],
        time: ClockTime
    ) async throws -> String? {
        let existing = try await repo.fetchActiveAlarms()
        let overlaps = AlarmOverlapDetector.overlaps(
            candidateDays: days,
            candidateTime: time,
            existing: existing.map {
                (id: $0.id, title: $0.title, days: $0.daysOfWeek, time: $0.time)
            }
        )
        guard let first = overlaps.first else { return nil }
        return String(
            format: String(localized: "create.overlap"),
            first.existingAlarmTitle,
            first.weekday.shortLabel,
            format(first.time)
        )
    }

    private func clockTime(from date: Date) -> ClockTime {
        let comps = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
        return ClockTime(hour: comps.hour ?? 0, minute: comps.minute ?? 0)
    }

    private func format(_ time: ClockTime) -> String {
        String(format: "%02d:%02d", time.hour, time.minute)
    }
}

#Preview {
    NavigationStack {
        CreateAlarmView(onFinished: {})
    }
    .modelContainer(try! ModelContainerFactory.makeInMemory())
}
