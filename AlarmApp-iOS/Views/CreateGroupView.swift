import SwiftUI
import SwiftData
import AlarmAppCore

struct CreateGroupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var onFinished: () -> Void

    @State private var name = "Sabah"
    @State private var startDate = Calendar.current.date(
        bySettingHour: 6, minute: 0, second: 0, of: Date()
    ) ?? Date()
    @State private var endDate = Calendar.current.date(
        bySettingHour: 7, minute: 0, second: 0, of: Date()
    ) ?? Date()
    @State private var intervalMinutes = 5
    @State private var selectedDays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var previewCount: Int = 13

    var body: some View {
        Form {
            Section("Grup") {
                TextField("Ad", text: $name)
            }

            Section("Zaman aralığı") {
                DatePicker("Başlangıç", selection: $startDate, displayedComponents: .hourAndMinute)
                DatePicker("Bitiş", selection: $endDate, displayedComponents: .hourAndMinute)
                Stepper("Aralık: \(intervalMinutes) dk", value: $intervalMinutes, in: 1...60)
            }

            Section("Tekrar günleri") {
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

            Section {
                Text("Her seçili günde yaklaşık \(previewCount) alarm üretilir.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Yeni grup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Vazgeç") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Kaydet") {
                    Task { await save() }
                }
                .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedDays.isEmpty)
            }
        }
        .onChange(of: startDate) { _, _ in refreshPreview() }
        .onChange(of: endDate) { _, _ in refreshPreview() }
        .onChange(of: intervalMinutes) { _, _ in refreshPreview() }
        .onAppear(perform: refreshPreview)
        .alert("Kaydedilemedi", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("Tamam", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func refreshPreview() {
        do {
            let times = try AlarmInstanceGenerator.clockTimes(
                start: clockTime(from: startDate),
                end: clockTime(from: endDate),
                intervalMinutes: intervalMinutes
            )
            previewCount = times.count
        } catch {
            previewCount = 0
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let request = CreateAlarmGroupRequest(
                name: name,
                timeStart: clockTime(from: startDate),
                timeEnd: clockTime(from: endDate),
                intervalMinutes: intervalMinutes,
                daysOfWeek: Array(selectedDays),
                soundId: "default",
                horizonDays: 14
            )
            let prepared = try CreateAlarmGroup().prepare(request)

            // Overlap warning (non-blocking for v0.0.3 — show as errorMessage soft warn later)
            let existing = try await SwiftDataAlarmRepository(modelContainer: modelContext.container)
                .fetchActiveGroups()
            let candidateTimes = try AlarmInstanceGenerator.clockTimes(
                start: prepared.timeStart,
                end: prepared.timeEnd,
                intervalMinutes: prepared.intervalMinutes
            )
            let overlaps = AlarmGroupOverlapDetector.overlaps(
                candidateDays: prepared.daysOfWeek,
                candidateTimes: candidateTimes,
                existing: existing.map {
                    (id: $0.id, name: $0.name, days: $0.daysOfWeek, times: candidateTimesForSummary($0))
                }
            )

            let repo = SwiftDataAlarmRepository(modelContainer: modelContext.container)
            _ = try await repo.createGroup(from: prepared)

            if !overlaps.isEmpty {
                // Saved anyway; toast-style feedback via error dialog is wrong — use print for now
            }

            onFinished()
            dismiss()
        } catch {
            errorMessage = "Grup oluşturulamadı. Aralık ve günleri kontrol et."
        }
    }

    private func candidateTimesForSummary(_ summary: AlarmGroupSummary) -> [ClockTime] {
        (try? AlarmInstanceGenerator.clockTimes(
            start: summary.timeStart,
            end: summary.timeEnd,
            intervalMinutes: summary.intervalMinutes
        )) ?? []
    }

    private func clockTime(from date: Date) -> ClockTime {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ClockTime(hour: comps.hour ?? 0, minute: comps.minute ?? 0)
    }
}

private extension Weekday {
    var shortLabel: String {
        switch self {
        case .monday: return "Pzt"
        case .tuesday: return "Sal"
        case .wednesday: return "Çar"
        case .thursday: return "Per"
        case .friday: return "Cum"
        case .saturday: return "Cmt"
        case .sunday: return "Paz"
        }
    }
}

#Preview {
    NavigationStack {
        CreateGroupView(onFinished: {})
    }
    .modelContainer(try! ModelContainerFactory.makeInMemory())
}
