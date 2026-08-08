import SwiftUI
import SwiftData
import AlarmAppCore

struct GroupListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AlarmGroup.createdAt, order: .reverse) private var groups: [AlarmGroup]
    @State private var isCreating = false
    @State private var newName = ""
    @State private var errorMessage: String?
    @State private var toastMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if groups.isEmpty {
                    ContentUnavailableView {
                        Label("groups.empty.title", systemImage: "rectangle.3.group")
                    } description: {
                        Text("groups.empty.subtitle")
                    } actions: {
                        Button("groups.create") { isCreating = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(groups, id: \.id) { group in
                            NavigationLink {
                                GroupDetailView(group: group)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(group.name)
                                        .font(.headline)
                                    Text(String(format: String(localized: "groups.alarm_count"), group.alarms.count))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("action.stop_today") {
                                    Task { await cancelToday(group: group) }
                                }
                                .tint(.orange)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isCreating = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("groups.create"))
                }
            }
            .alert("groups.new_title", isPresented: $isCreating) {
                TextField("create.name", text: $newName)
                Button("action.cancel", role: .cancel) {
                    newName = ""
                }
                Button("action.save") {
                    Task { await createGroup() }
                }
            } message: {
                Text("groups.new_message")
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
                }
            }
        }
    }

    private func createGroup() async {
        do {
            let repo = SwiftDataAlarmRepository(modelContainer: modelContext.container)
            _ = try await repo.createGroup(name: newName)
            await MainActor.run { newName = "" }
        } catch {
            await MainActor.run {
                errorMessage = String(localized: "groups.create_failed")
                newName = ""
            }
        }
    }

    private func cancelToday(group: AlarmGroup) async {
        do {
            let repo = SwiftDataAlarmRepository(modelContainer: modelContext.container)
            let cancelled = try await repo.cancelToday(groupId: group.id)
            await HybridAlarmScheduler().cancelPending(instanceIds: cancelled)
            let name = group.name
            await MainActor.run {
                toastMessage = String(format: String(localized: "toast.stopped_today"), name)
                Task {
                    try? await Task.sleep(for: .seconds(8))
                    if toastMessage?.contains(name) == true { toastMessage = nil }
                }
            }
        } catch {
            await MainActor.run { errorMessage = String(localized: "error.stop_today") }
        }
    }
}

struct GroupDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var group: AlarmGroup
    @Query(sort: \Alarm.timeMinutes) private var allAlarms: [Alarm]

    @State private var isAssigning = false
    @State private var isCreatingAlarm = false
    @State private var errorMessage: String?
    @State private var bypassStart = Date()
    @State private var bypassEnd = Date()
    @State private var showBypassConfirm = false
    @State private var toastMessage: String?

    private var sortedAlarms: [Alarm] {
        group.alarms.sorted { $0.timeMinutes < $1.timeMinutes }
    }

    private var assignableAlarms: [Alarm] {
        allAlarms.filter { $0.group?.id != group.id }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("detail.status", value: String(localized: group.isActive ? "status.active" : "status.inactive"))
                LabeledContent("groups.alarm_count_label", value: "\(group.alarms.count)")
            }

            Section {
                Button {
                    isAssigning = true
                } label: {
                    Label("groups.add_existing", systemImage: "plus.circle")
                }
                .disabled(assignableAlarms.isEmpty)

                Button {
                    isCreatingAlarm = true
                } label: {
                    Label("groups.add_new", systemImage: "alarm")
                }
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
                Button("bypass.skip_group") {
                    showBypassConfirm = true
                }
            }

            Section("tab.alarms") {
                if sortedAlarms.isEmpty {
                    Text("groups.no_alarms")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedAlarms, id: \.id) { alarm in
                        NavigationLink {
                            AlarmDetailView(alarm: alarm)
                        } label: {
                            HStack {
                                Text(String(format: "%02d:%02d", alarm.time.hour, alarm.time.minute))
                                    .font(.body.monospacedDigit().weight(.semibold))
                                Text(alarm.title)
                                Spacer()
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button("groups.remove", role: .destructive) {
                                Task { await removeFromGroup(alarm) }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $isAssigning) {
            NavigationStack {
                AssignAlarmsToGroupView(
                    group: group,
                    candidates: assignableAlarms
                ) {
                    isAssigning = false
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isCreatingAlarm) {
            NavigationStack {
                CreateAlarmView(preselectedGroupId: group.id) {
                    isCreatingAlarm = false
                }
            }
        }
        .confirmationDialog("bypass.confirm_group", isPresented: $showBypassConfirm, titleVisibility: .visible) {
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
                groupId: group.id,
                from: bypassStart,
                to: bypassEnd
            )
            await HybridAlarmScheduler().cancelPending(instanceIds: cancelled)
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

    private func removeFromGroup(_ alarm: Alarm) async {
        do {
            let repo = SwiftDataAlarmRepository(modelContainer: modelContext.container)
            try await repo.assignAlarm(alarmId: alarm.id, to: nil)
        } catch {
            await MainActor.run { errorMessage = String(localized: "groups.remove_failed") }
        }
    }
}

private struct AssignAlarmsToGroupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let group: AlarmGroup
    let candidates: [Alarm]
    var onFinished: () -> Void

    @State private var selectedIds: Set<UUID> = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if candidates.isEmpty {
                Text("groups.assign_empty")
                    .foregroundStyle(.secondary)
            } else {
                Section {
                    ForEach(candidates, id: \.id) { alarm in
                        Button {
                            if selectedIds.contains(alarm.id) {
                                selectedIds.remove(alarm.id)
                            } else {
                                selectedIds.insert(alarm.id)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(String(format: "%02d:%02d  %@", alarm.time.hour, alarm.time.minute, alarm.title))
                                        .foregroundStyle(.primary)
                                    if let other = alarm.group?.name {
                                        Text(String(format: String(localized: "groups.currently"), other))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("groups.ungrouped")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: selectedIds.contains(alarm.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedIds.contains(alarm.id) ? Color.accentColor : .secondary)
                            }
                        }
                    }
                } footer: {
                    Text("groups.assign_footer")
                }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("action.cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("action.add") {
                    Task { await assignSelected() }
                }
                .disabled(selectedIds.isEmpty || isSaving)
            }
        }
        .alert("groups.assign_failed_title", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("action.done", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func assignSelected() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let repo = SwiftDataAlarmRepository(modelContainer: modelContext.container)
            for id in selectedIds {
                try await repo.assignAlarm(alarmId: id, to: group.id)
            }
            onFinished()
            dismiss()
        } catch {
            errorMessage = String(localized: "groups.assign_failed")
        }
    }
}

#Preview {
    GroupListView()
        .modelContainer(try! ModelContainerFactory.makeInMemory())
}
