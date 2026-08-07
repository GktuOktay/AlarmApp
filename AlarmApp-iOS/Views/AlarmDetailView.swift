import SwiftUI
import SwiftData
import AlarmAppCore

struct AlarmDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var alarm: Alarm
    @Query private var exceptions: [AlarmException]

    @State private var bypassStart = Date()
    @State private var bypassEnd = Date()
    @State private var showBypassConfirm = false
    @State private var toastMessage: String?
    @State private var errorMessage: String?

    private var calendar: Calendar { .autoupdatingCurrent }

    private var daysText: String {
        alarm.daysOfWeek
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.shortLabel)
            .joined(separator: " ")
    }

    private var isOneShot: Bool {
        if let endsOn = alarm.endsOn,
           calendar.isDate(endsOn, inSameDayAs: alarm.createdAt),
           alarm.daysOfWeek.count == 1
        {
            return true
        }
        return false
    }

    private var patternSummary: String {
        if isOneShot {
            return String(localized: "detail.pattern_once")
        }
        let days = daysText
        if let endsOn = alarm.endsOn {
            return String(
                format: String(localized: "detail.pattern_until"),
                days,
                endsOn.formatted(date: .abbreviated, time: .omitted)
            )
        }
        return String(format: String(localized: "detail.pattern_weekly"), days)
    }

    private var soundDisplayName: String {
        String(
            localized: String.LocalizationValue(
                AlarmSoundCatalog.resolve(alarm.soundId).displayNameKey
            )
        )
    }

    private var soundVolumePercentText: String {
        "\(Int((alarm.soundVolume * 100).rounded()))%"
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
                LabeledContent("detail.time", value: format(alarm.time))
                LabeledContent("detail.days", value: daysText)
                LabeledContent("detail.pattern", value: patternSummary)
                LabeledContent(
                    "detail.status",
                    value: String(localized: alarm.isActive ? "status.active" : "status.inactive")
                )
                if let groupName = alarm.group?.name {
                    LabeledContent("detail.group", value: groupName)
                } else {
                    LabeledContent("detail.group", value: String(localized: "detail.group_none"))
                }
                if let endsOn = alarm.endsOn {
                    LabeledContent(
                        "detail.ends",
                        value: endsOn.formatted(date: .abbreviated, time: .omitted)
                    )
                } else {
                    LabeledContent("detail.ends", value: String(localized: "detail.ends_none"))
                }
                LabeledContent("detail.sound", value: soundDisplayName)
                LabeledContent("detail.sound_volume", value: soundVolumePercentText)
            }

            Section {
                Toggle("detail.snooze", isOn: Binding(
                    get: { alarm.snoozeEnabled },
                    set: { newValue in
                        alarm.snoozeEnabled = newValue
                        alarm.updatedAt = Date()
                        try? modelContext.save()
                    }
                ))
                .tint(.green)

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
                    .tint(.orange)
                }

                Toggle("detail.wake_schedule", isOn: Binding(
                    get: { alarm.isWakeSchedule },
                    set: { newValue in
                        let previous = alarm.isWakeSchedule
                        alarm.isWakeSchedule = newValue
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
                .tint(.green)
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
        .confirmationDialog("bypass.confirm_alarm", isPresented: $showBypassConfirm, titleVisibility: .visible) {
            Button("bypass.confirm_action", role: .destructive) {
                Task { await performBypass() }
            }
            Button("action.cancel", role: .cancel) {}
        }
        .overlay(alignment: .bottom) {
            if let toastMessage {
                Text(toastMessage)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 24)
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
    }

    private func performBypass() async {
        do {
            let repo = SwiftDataAlarmRepository(modelContainer: modelContext.container)
            let cancelled = try await repo.bypassDays(
                alarmId: alarm.id,
                from: bypassStart,
                to: bypassEnd
            )
            await LocalNotificationScheduler().cancelPending(instanceIds: cancelled)
            await MainActor.run {
                toastMessage = String(localized: "bypass.done")
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    toastMessage = nil
                }
            }
        } catch {
            await MainActor.run { errorMessage = String(localized: "bypass.failed") }
        }
    }

    private func format(_ time: ClockTime) -> String {
        String(format: "%02d:%02d", time.hour, time.minute)
    }

    private func dayLabel(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}
