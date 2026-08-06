import SwiftUI
import SwiftData
import AlarmAppCore

struct GroupListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AlarmGroup.createdAt, order: .reverse) private var groups: [AlarmGroup]
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var toastMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if groups.isEmpty {
                    ContentUnavailableView {
                        Label("Henüz alarm grubu yok", systemImage: "alarm")
                    } description: {
                        Text("Sabah aralığına yayılmış alarmlarını grupla. Uyanınca kalanları tek dokunuşla kapat.")
                    } actions: {
                        Button("Grup oluştur") { isCreating = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(groups, id: \.id) { group in
                            GroupRowView(group: group)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button("Bugün kapat") {
                                        Task { await cancelToday(groupId: group.id, name: group.name) }
                                    }
                                    .tint(.orange)
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Alarmlar")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isCreating = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Grup oluştur")
                }
            }
            .sheet(isPresented: $isCreating) {
                NavigationStack {
                    CreateGroupView {
                        isCreating = false
                    }
                }
            }
            .alert("Bir sorun oluştu", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("Tamam", role: .cancel) { errorMessage = nil }
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

    private func cancelToday(groupId: UUID, name: String) async {
        do {
            let repo = SwiftDataAlarmRepository(modelContainer: modelContext.container)
            try await repo.cancelToday(groupId: groupId)
            await MainActor.run {
                toastMessage = "\(name) bugün için kapatıldı"
                Task {
                    try? await Task.sleep(for: .seconds(8))
                    if toastMessage?.contains(name) == true {
                        toastMessage = nil
                    }
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Bugün kapatılamadı. Lütfen yeniden dene."
            }
        }
    }
}

private struct GroupRowView: View {
    let group: AlarmGroup

    private var timeRangeText: String {
        "\(format(group.timeStart)) – \(format(group.timeEnd))"
    }

    private var daysText: String {
        group.daysOfWeek
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.shortLabel)
            .joined(separator: " ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(group.name)
                    .font(.headline)
                Spacer()
                if !group.isActive {
                    Text("Pasif")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Text(timeRangeText)
                .font(.title3.monospacedDigit().weight(.semibold))
            Text("Her \(group.intervalMinutes) dk · \(daysText)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(group.instances.filter { $0.status == .pending }.count) bekleyen alarm")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func format(_ time: ClockTime) -> String {
        String(format: "%02d:%02d", time.hour, time.minute)
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
    GroupListView()
        .modelContainer(try! ModelContainerFactory.makeInMemory())
}
