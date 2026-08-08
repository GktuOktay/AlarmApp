import SwiftUI
import SwiftData
import AlarmAppCore

struct AlarmDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var alarm: Alarm
    @Query(sort: \AlarmGroup.name) private var groups: [AlarmGroup]
    @Query private var exceptions: [AlarmException]

    @State private var bypassStart = Date()
    @State private var bypassEnd = Date()
    @State private var showBypassConfirm = false
    @State private var toastMessage: String?
    @State private var errorMessage: String?

    @State private var title = ""
    @State private var timeDate = Date()
    @State private var selectedDays: Set<Weekday> = []
    @State private var repeats = false
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var groupSelection: CreateAlarmView.GroupSelection = .none
    @State private var newGroupName = ""
    @State private var soundId = "default"
    @State private var soundVolumePercent: Double = 100
    @State private var soundPreview = AlarmSoundPreview()
    @State private var didLoadEditableFields = false
    @State private var showSavedIndicator = false
    @State private var savedIndicatorTask: Task<Void, Never>?
    @FocusState private var isNameFieldFocused: Bool

    private var calendar: Calendar { .autoupdatingCurrent }

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

    private var editableSoundSummary: String {
        String(localized: String.LocalizationValue(AlarmSoundCatalog.resolve(soundId).displayNameKey))
    }

    private var soundVolumePercentText: String {
        "\(Int(soundVolumePercent.rounded()))%"
    }

    private var nextOccurrences: [AlarmOccurrence] {
        let snapshot = AlarmPatternSnapshot(
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
        let tuples: [BypassExceptionTuple] = exceptions.map {
            (
                alarmId: $0.alarmId,
                groupId: $0.group?.id,
                start: $0.startDate,
                end: $0.endDate,
                action: $0.action,
                type: $0.type
            )
        }
        return AlarmOccurrenceExpander.nextOccurrences(
            alarm: snapshot,
            exceptions: tuples,
            from: Date(),
            limit: 5,
            calendar: calendar
        )
    }

    var body: some View {
        List {
            Section {
                TextField("create.name", text: $title)
                    .focused($isNameFieldFocused)
                    .onChange(of: title) { _, _ in scheduleSave() }

                DatePicker(
                    "create.time",
                    selection: $timeDate,
                    displayedComponents: .hourAndMinute
                )
                .onChange(of: timeDate) { _, _ in scheduleSave() }

                LabeledContent(
                    "detail.status",
                    value: String(localized: alarm.isActive ? "status.active" : "status.inactive")
                )
            }

            Section {
                NavigationLink {
                    RepeatsPickerView(repeats: $repeats, selectedDays: $selectedDays)
                        .onDisappear { scheduleSave() }
                } label: {
                    LabeledContent("create.repeats", value: repeatsSummary)
                }

                if repeats {
                    NavigationLink {
                        EndDatePickerView(hasEndDate: $hasEndDate, endDate: $endDate)
                            .onDisappear { scheduleSave() }
                    } label: {
                        LabeledContent("create.end_toggle", value: endDateSummary)
                    }
                }

                NavigationLink {
                    GroupPickerView(groupSelection: $groupSelection, newGroupName: $newGroupName, groups: groups)
                        .onDisappear { scheduleSave() }
                } label: {
                    LabeledContent("create.group_section", value: groupSummary)
                }

                NavigationLink {
                    SoundPickerView(soundId: $soundId, soundVolumePercent: $soundVolumePercent, soundPreview: soundPreview)
                        .onDisappear { scheduleSave() }
                } label: {
                    LabeledContent("create.sound_section", value: editableSoundSummary)
                }
                LabeledContent("detail.sound_volume", value: soundVolumePercentText)
            }

            Section {
                Toggle("detail.snooze", isOn: Binding(
                    get: { alarm.snoozeEnabled },
                    set: { newValue in
                        withAnimation(.spring(response: 0.3, dampingFraction: 1)) {
                            alarm.snoozeEnabled = newValue
                        }
                        alarm.updatedAt = Date()
                        try? modelContext.save()
                    }
                ))
                .tint(AlarmColors.success)

                if alarm.snoozeEnabled {
                    Picker("detail.snooze_duration", selection: Binding(
                        get: { alarm.snoozeMinutes },
                        set: { newValue in
                            alarm.snoozeMinutes = SnoozePolicy.clampMinutes(newValue)
                            alarm.updatedAt = Date()
                            try? modelContext.save()
                        }
                    )) {
                        ForEach(SnoozePolicy.minMinutes...SnoozePolicy.maxMinutes, id: \.self) { minutes in
                            Text(
                                String(
                                    format: String(localized: "create.snooze_minutes"),
                                    minutes
                                )
                            )
                            .tag(minutes)
                        }
                    }
                    .tint(AlarmColors.warn)
                }

                Toggle("detail.wake_schedule", isOn: Binding(
                    get: { alarm.isWakeSchedule },
                    set: { newValue in
                        let previous = alarm.isWakeSchedule
                        withAnimation(.spring(response: 0.3, dampingFraction: 1)) {
                            alarm.isWakeSchedule = newValue
                        }
                        alarm.updatedAt = Date()
                        Task {
                            do {
                                let repo = SwiftDataAlarmRepository(modelContainer: modelContext.container)
                                try await repo.setWakeScheduleAlarm(alarmId: newValue ? alarm.id : nil)
                            } catch {
                                await MainActor.run {
                                    alarm.isWakeSchedule = previous
                                    errorMessage = String(localized: "error.wake_schedule")
                                }
                            }
                        }
                    }
                ))
                .tint(AlarmColors.success)
            } footer: {
                Text("detail.wake_schedule_footer")
            }

            Section("bypass.section") {
                DatePicker(
                    "bypass.start",
                    selection: $bypassStart,
                    in: Date()...,
                    displayedComponents: .date
                )
                DatePicker(
                    "bypass.end",
                    selection: $bypassEnd,
                    in: bypassStart...,
                    displayedComponents: .date
                )
                .onChange(of: bypassStart) { _, newStart in
                    if bypassEnd < newStart { bypassEnd = newStart }
                }
                Button("bypass.skip_alarm") {
                    showBypassConfirm = true
                }
            }

            if !nextOccurrences.isEmpty {
                Section("detail.next") {
                    ForEach(nextOccurrences) { occurrence in
                        HStack {
                            Text(dayLabel(occurrence.dayStart))
                                .font(.subheadline)
                            Spacer()
                            Text(format(occurrence.time))
                                .font(.body.monospacedDigit().weight(.semibold))
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.spring(response: 0.3, dampingFraction: 1), value: repeats)
        .animation(.spring(response: 0.3, dampingFraction: 1), value: alarm.snoozeEnabled)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("action.done") { isNameFieldFocused = false }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if showSavedIndicator {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AlarmColors.success)
                        .transition(.opacity)
                        .accessibilityLabel(Text("detail.saved"))
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: showSavedIndicator)
        .confirmationDialog("bypass.confirm_alarm", isPresented: $showBypassConfirm, titleVisibility: .visible) {
            Button("bypass.confirm_action", role: .destructive) {
                Task { await performBypass() }
            }
            Button("action.cancel", role: .cancel) {}
        }
        .toast($toastMessage, duration: 3)
        .alert("error.generic_title", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("action.done", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear { loadEditableFields() }
        .onDisappear {
            soundPreview.stop()
            scheduleSave()
        }
    }

    private func loadEditableFields() {
        guard !didLoadEditableFields else { return }
        title = alarm.title
        timeDate = Calendar.current.date(
            bySettingHour: alarm.time.hour, minute: alarm.time.minute, second: 0, of: Date()
        ) ?? Date()
        selectedDays = Set(alarm.daysOfWeek)
        repeats = alarm.daysOfWeek.count > 1 || alarm.endsOn == nil
        hasEndDate = alarm.endsOn != nil
        endDate = alarm.endsOn ?? Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        groupSelection = alarm.group.map { .existing($0.id) } ?? .none
        soundId = alarm.soundId
        soundVolumePercent = alarm.soundVolume * 100
        didLoadEditableFields = true
    }

    private func scheduleSave() {
        guard didLoadEditableFields else { return }
        Task { await saveScheduleChanges() }
    }

    private func saveScheduleChanges() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        guard !repeats || !selectedDays.isEmpty else { return }

        do {
            let repo = SwiftDataAlarmRepository(modelContainer: modelContext.container)
            var groupId: UUID?
            switch groupSelection {
            case .none:
                groupId = nil
            case .existing(let id):
                groupId = id
            case .createNew:
                let trimmedGroupName = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedGroupName.isEmpty else { return }
                groupId = try await repo.createGroup(name: trimmedGroupName)
                await MainActor.run { groupSelection = .existing(groupId!) }
            }

            let staleInstanceIds = alarm.instances.filter { $0.status == .pending }.map(\.id)
            let time = clockTime(from: timeDate)
            let todayWeekday = Weekday.from(calendarWeekday: calendar.component(.weekday, from: Date())) ?? .monday
            let days = repeats ? Array(selectedDays) : [todayWeekday]
            let endsOn: Date? = repeats ? (hasEndDate ? endDate : nil) : calendar.startOfDay(for: Date())

            let result = try await repo.updateAlarmPattern(
                alarmId: alarm.id,
                title: trimmedTitle,
                time: time,
                daysOfWeek: days,
                endsOn: endsOn,
                soundId: soundId,
                soundVolume: soundVolumePercent / 100.0,
                groupId: groupId
            )

            await HybridAlarmScheduler().cancelPending(instanceIds: staleInstanceIds)

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
            await WatchSyncBootstrap.shared.pushTodayContext()
            await MainActor.run { flashSavedIndicator() }
        } catch {
            AppLog.error(.swiftdata, "updateAlarmPattern save failed", error: error)
            await MainActor.run {
                errorMessage = String(localized: "create.save_failed")
            }
        }
    }

    private func flashSavedIndicator() {
        savedIndicatorTask?.cancel()
        showSavedIndicator = true
        savedIndicatorTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            showSavedIndicator = false
        }
    }

    private func performBypass() async {
        do {
            let repo = SwiftDataAlarmRepository(modelContainer: modelContext.container)
            let cancelled = try await repo.bypassDays(
                alarmId: alarm.id,
                from: bypassStart,
                to: bypassEnd
            )
            await HybridAlarmScheduler().cancelPending(instanceIds: cancelled)
            await MainActor.run {
                toastMessage = String(localized: "bypass.done")
            }
        } catch {
            await MainActor.run { errorMessage = String(localized: "bypass.failed") }
        }
    }

    private func format(_ time: ClockTime) -> String {
        String(format: "%02d:%02d", time.hour, time.minute)
    }

    private func clockTime(from date: Date) -> ClockTime {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        return ClockTime(hour: comps.hour ?? 0, minute: comps.minute ?? 0)
    }

    private func dayLabel(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}
