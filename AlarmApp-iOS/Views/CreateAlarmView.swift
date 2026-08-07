import SwiftUI
import SwiftData
import AlarmAppCore

struct CreateAlarmView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \AlarmGroup.name) private var groups: [AlarmGroup]

    var onFinished: () -> Void
    var preselectedGroupId: UUID? = nil

    @State private var title = "Sabah"
    @State private var timeDate = Calendar.current.date(
        bySettingHour: 6, minute: 0, second: 0, of: Date()
    ) ?? Date()
    @State private var selectedDays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    @State private var repeats = true
    @State private var hasEndDate = false
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var groupSelection: GroupSelection = .none
    @State private var newGroupName = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var overlapWarning: String?
    @State private var didApplyPreselection = false

    private enum GroupSelection: Hashable {
        case none
        case existing(UUID)
        case createNew
    }

    var body: some View {
        Form {
            Section {
                TextField("create.name", text: $title)
                DatePicker("create.time", selection: $timeDate, displayedComponents: .hourAndMinute)
            }

            Section {
                Toggle("create.repeats", isOn: $repeats)
                if repeats {
                    Text("create.repeat_days")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                        ForEach(Weekday.allCases, id: \.self) { day in
                            let selected = selectedDays.contains(day)
                            Button(day.shortLabel) {
                                if selected {
                                    selectedDays.remove(day)
                                } else {
                                    selectedDays.insert(day)
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(selected ? .accentColor : .secondary)
                            .sensoryFeedback(.selection, trigger: selectedDays)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } footer: {
                Text(repeats ? "create.repeats_on_footer" : "create.repeats_off_footer")
            }

            if repeats {
                Section {
                    Toggle("create.end_toggle", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker(
                            "create.end_day",
                            selection: $endDate,
                            in: Date()...,
                            displayedComponents: .date
                        )
                    }
                } footer: {
                    Text(hasEndDate ? "create.end_footer_on" : "create.end_footer_off")
                }
            }

            Section("create.group_section") {
                Picker("detail.group", selection: $groupSelection) {
                    Text("create.group_none").tag(GroupSelection.none)
                    ForEach(groups, id: \.id) { group in
                        Text(group.name).tag(GroupSelection.existing(group.id))
                    }
                    Text("create.group_new").tag(GroupSelection.createNew)
                }
                if groupSelection == .createNew {
                    TextField("create.group_new_name", text: $newGroupName)
                }
            }

            if let overlapWarning {
                Section {
                    Text(overlapWarning)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        }
        .toolbar {
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
            guard !didApplyPreselection, let preselectedGroupId else { return }
            groupSelection = .existing(preselectedGroupId)
            didApplyPreselection = true
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
            let request = CreateAlarmRequest(
                title: title,
                time: time,
                daysOfWeek: Array(selectedDays),
                soundId: "default",
                groupId: groupId,
                repeats: repeats,
                horizonDays: AlarmHorizon.notificationDays,
                endDate: (repeats && hasEndDate) ? endDate : nil
            )
            let prepared = try CreateAlarm().prepare(request)

            let existing = try await repo.fetchActiveAlarms()
            let overlaps = AlarmOverlapDetector.overlaps(
                candidateDays: prepared.daysOfWeek,
                candidateTime: prepared.time,
                existing: existing.map {
                    (id: $0.id, title: $0.title, days: $0.daysOfWeek, time: $0.time)
                }
            )
            if let first = overlaps.first {
                overlapWarning = String(
                    format: String(localized: "create.overlap"),
                    first.existingAlarmTitle,
                    first.weekday.shortLabel,
                    format(first.time)
                )
            }

            let result = try await repo.createAlarm(from: prepared)

            let scheduler = LocalNotificationScheduler()
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
                        fireDate: schedule.fireDate,
                        title: result.title,
                        body: String(format: String(localized: "notif.alarm_body"), timeText),
                        soundId: schedule.soundId,
                        soundVolume: schedule.soundVolume
                    )
                }
            }

            onFinished()
            dismiss()
        } catch {
            errorMessage = String(localized: "create.save_failed")
        }
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
