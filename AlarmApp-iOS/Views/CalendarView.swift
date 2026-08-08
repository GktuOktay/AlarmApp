import SwiftUI
import SwiftData
import AlarmAppCore

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppPreferences.self) private var preferences
    @Query(sort: \Alarm.timeMinutes) private var alarms: [Alarm]
    @Query private var exceptions: [AlarmException]
    @Query private var instances: [AlarmInstance]
    @State private var visibleMonth: Date = Date()
    @State private var selectedDay: Date?
    @State private var toastMessage: String?
    @State private var errorMessage: String?
    // Phase 7 — opt-in EventKit bypass day suggestions.
    @State private var calendarSuggestionService = CalendarBypassSuggestionService()
    @State private var nonWorkDaySuggestions: Set<Date> = []

    private var calendar: Calendar { .autoupdatingCurrent }

    private var monthTitle: String {
        visibleMonth.formatted(.dateTime.year().month(.wide))
    }

    private var exceptionTuples: [BypassExceptionTuple] {
        exceptions.map {
            (
                alarmId: $0.alarmId,
                groupId: $0.group?.id,
                start: $0.startDate,
                end: $0.endDate,
                action: $0.action,
                type: $0.type
            )
        }
    }

    private var patternSnapshots: [AlarmPatternSnapshot] {
        alarms.map {
            AlarmPatternSnapshot(
                id: $0.id,
                title: $0.title,
                time: $0.time,
                daysOfWeek: $0.daysOfWeek,
                isActive: $0.isActive,
                endsOn: $0.endsOn,
                createdAt: $0.createdAt,
                groupId: $0.group?.id,
                groupName: $0.group?.name
            )
        }
    }

    private var statusMap: [UUID: [Date: AlarmStatus]] {
        var map: [UUID: [Date: AlarmStatus]] = [:]
        for instance in instances {
            guard let alarmId = instance.alarm?.id else { continue }
            let day = calendar.startOfDay(for: instance.scheduledDate)
            map[alarmId, default: [:]][day] = instance.status
        }
        return map
    }

    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth),
              let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday
        else { return [] }

        let mondayBased = (firstWeekday + 5) % 7
        var cells: [Date?] = Array(repeating: nil, count: mondayBased)

        var day = monthInterval.start
        while day < monthInterval.end {
            cells.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }

    private var monthOccurrences: [AlarmOccurrence] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth) else { return [] }
        let last = calendar.date(byAdding: .day, value: -1, to: monthInterval.end) ?? monthInterval.start
        return AlarmOccurrenceExpander.expand(
            alarms: patternSnapshots,
            exceptions: exceptionTuples,
            from: monthInterval.start,
            to: last,
            statuses: statusMap,
            calendar: calendar
        )
    }

    private var daysWithAlarms: Set<DateComponents> {
        var set = Set<DateComponents>()
        for occ in monthOccurrences where occ.status == .pending {
            set.insert(calendar.dateComponents([.year, .month, .day], from: occ.dayStart))
        }
        return set
    }

    private var selectedDayItems: [AlarmOccurrence] {
        guard let selectedDay else { return [] }
        let day = calendar.startOfDay(for: selectedDay)
        return monthOccurrences.filter { calendar.isDate($0.dayStart, inSameDayAs: day) }
    }

    /// Phase 7 — pending occurrences on the selected day that a calendar-detected
    /// non-work day (e.g. "izin"/"tatil"/vacation) suggests bypassing.
    private var calendarSuggestionForSelectedDay: [AlarmOccurrence] {
        guard preferences.calendarSuggestionsEnabled, let selectedDay else { return [] }
        let day = calendar.startOfDay(for: selectedDay)
        guard nonWorkDaySuggestions.contains(day) else { return [] }
        return selectedDayItems.filter { $0.status == .pending }
    }

    private func refreshCalendarSuggestions() async {
        guard preferences.calendarSuggestionsEnabled,
              let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth)
        else {
            nonWorkDaySuggestions = []
            return
        }
        let days = await calendarSuggestionService.likelyNonWorkDays(in: monthInterval)
        nonWorkDaySuggestions = Set(days.map { calendar.startOfDay(for: $0) })
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    monthHeader
                    weekdayHeaderRow
                    calendarGrid
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                .listRowSeparator(.hidden)

                if let selectedDay {
                    Section(selectedDay.formatted(.dateTime.weekday(.wide).day().month().year())) {
                        if selectedDayItems.isEmpty {
                            Text("calendar.no_alarms_day")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(selectedDayItems) { occurrence in
                                dayAlarmRow(occurrence, on: selectedDay)
                            }
                        }
                    }

                    if !calendarSuggestionForSelectedDay.isEmpty {
                        Section("calendar.suggestion.section_title") {
                            ForEach(calendarSuggestionForSelectedDay) { occurrence in
                                calendarSuggestionRow(occurrence, on: selectedDay)
                            }
                        }
                    }
                } else {
                    Section {
                        Text("calendar.pick_day")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .onAppear {
                if selectedDay == nil {
                    selectedDay = calendar.startOfDay(for: Date())
                }
            }
            .task(id: visibleMonth) {
                await refreshCalendarSuggestions()
            }
            .task(id: preferences.calendarSuggestionsEnabled) {
                await refreshCalendarSuggestions()
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
        }
    }

    private var monthHeader: some View {
        HStack {
            Button { animatedShiftMonth(-1) } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("calendar.previous_month"))
            Spacer()
            Text(monthTitle)
                .font(.headline)
            Spacer()
            Button { animatedShiftMonth(1) } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("calendar.next_month"))
        }
    }

    private var weekdayHeaderRow: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(Array(weekdayHeaders.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, day in
                if let day {
                    let comps = calendar.dateComponents([.year, .month, .day], from: day)
                    let hasAlarm = daysWithAlarms.contains(comps)
                    let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false
                    let isToday = calendar.isDateInToday(day)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 1)) {
                            selectedDay = day
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text("\(calendar.component(.day, from: day))")
                                .font(.body.monospacedDigit())
                                .foregroundStyle(isSelected ? Color.white : Color.primary)
                            Circle()
                                .fill(hasAlarm ? (isSelected ? Color.white.opacity(0.9) : Color.accentColor) : Color.clear)
                                .frame(width: 6, height: 6)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            isSelected ? Color.accentColor : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.accentColor, lineWidth: isToday && !isSelected ? 1.5 : 0)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(day.formatted(.dateTime.weekday(.wide).day().month())))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                } else {
                    Color.clear.frame(minHeight: 44)
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.width < -50 {
                        animatedShiftMonth(1)
                    } else if value.translation.width > 50 {
                        animatedShiftMonth(-1)
                    }
                }
        )
        .sensoryFeedback(.selection, trigger: visibleMonth)
    }

    @ViewBuilder
    private func dayAlarmRow(_ occurrence: AlarmOccurrence, on day: Date) -> some View {
        HStack {
            Text(String(
                format: "%02d:%02d",
                occurrence.time.hour,
                occurrence.time.minute
            ))
            .font(.body.monospacedDigit().weight(.semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text(occurrence.title)
                if let group = occurrence.groupName {
                    Text(group)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(statusLabel(occurrence.status))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .swipeActions(edge: .trailing) {
            if occurrence.status == .pending {
                Button("bypass.skip_alarm") {
                    Task { await bypass(day: day, alarmId: occurrence.alarmId, groupId: nil) }
                }
                .tint(AlarmColors.warn)
                if let groupId = occurrence.groupId {
                    Button("bypass.skip_group") {
                        Task { await bypass(day: day, alarmId: nil, groupId: groupId) }
                    }
                    .tint(AlarmColors.danger)
                }
            }
        }
    }

    /// Phase 7 — lightweight suggestion row offering a one-tap bypass for a
    /// calendar-detected non-work day. Calls the same `bypass(day:alarmId:groupId:)`
    /// used by the swipe actions above; no new bypass-execution logic.
    @ViewBuilder
    private func calendarSuggestionRow(_ occurrence: AlarmOccurrence, on day: Date) -> some View {
        HStack {
            Image(systemName: "calendar.badge.exclamationmark")
                .foregroundStyle(AlarmColors.warn)
            VStack(alignment: .leading, spacing: 2) {
                Text(occurrence.title)
                Text("calendar.suggestion.row_subtitle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("calendar.suggestion.bypass_button") {
                Task { await bypass(day: day, alarmId: occurrence.alarmId, groupId: nil) }
            }
            .buttonStyle(.bordered)
            .tint(AlarmColors.warn)
        }
    }

    private func bypass(day: Date, alarmId: UUID?, groupId: UUID?) async {
        do {
            let repo = SwiftDataAlarmRepository(modelContainer: modelContext.container)
            let cancelled: [UUID]
            if let alarmId {
                cancelled = try await repo.bypassDay(alarmId: alarmId, day: day)
            } else if let groupId {
                cancelled = try await repo.bypassDay(groupId: groupId, day: day)
            } else {
                return
            }
            await HybridAlarmScheduler().cancelPending(instanceIds: cancelled)
            await MainActor.run {
                toastMessage = String(localized: "bypass.done")
            }
        } catch {
            await MainActor.run { errorMessage = String(localized: "bypass.failed") }
        }
    }

    private func shiftMonth(_ delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: visibleMonth) {
            visibleMonth = next
        }
    }

    private func animatedShiftMonth(_ delta: Int) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.9)) {
            shiftMonth(delta)
        }
    }

    private var weekdayHeaders: [String] {
        let symbols = calendar.shortWeekdaySymbols
        guard symbols.count == 7 else {
            return ["M", "T", "W", "T", "F", "S", "S"]
        }
        return Array(symbols[1...]) + [symbols[0]]
    }

    private func statusLabel(_ status: AlarmStatus) -> String {
        switch status {
        case .pending: return String(localized: "status.pending")
        case .fired: return String(localized: "status.fired")
        case .cancelled: return String(localized: "status.cancelled")
        case .snoozed: return String(localized: "status.snoozed")
        }
    }
}

#Preview {
    CalendarView()
        .environment(AppPreferences())
        .modelContainer(try! ModelContainerFactory.makeInMemory())
}
