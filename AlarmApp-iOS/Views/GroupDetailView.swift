import SwiftUI
import SwiftData
import AlarmAppCore

struct GroupDetailView: View {
    @Bindable var group: AlarmGroup

    private var sortedInstances: [AlarmInstance] {
        group.instances.sorted { lhs, rhs in
            if lhs.scheduledDate != rhs.scheduledDate {
                return lhs.scheduledDate < rhs.scheduledDate
            }
            return lhs.scheduledTime < rhs.scheduledTime
        }
    }

    var body: some View {
        List {
            Section("Özet") {
                LabeledContent("Aralık", value: "\(format(group.timeStart)) – \(format(group.timeEnd))")
                LabeledContent("Sıklık", value: "\(group.intervalMinutes) dk")
                LabeledContent("Durum", value: group.isActive ? "Aktif" : "Pasif")
            }

            Section("Alarmlar (\(sortedInstances.count))") {
                ForEach(sortedInstances, id: \.id) { instance in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dayLabel(instance.scheduledDate))
                                .font(.subheadline)
                            Text(format(instance.scheduledTime))
                                .font(.body.monospacedDigit().weight(.semibold))
                        }
                        Spacer()
                        Text(statusLabel(instance.status))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(statusColor(instance.status))
                    }
                }
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func format(_ time: ClockTime) -> String {
        String(format: "%02d:%02d", time.hour, time.minute)
    }

    private func dayLabel(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    private func statusLabel(_ status: AlarmStatus) -> String {
        switch status {
        case .pending: return "Bekliyor"
        case .fired: return "Çaldı"
        case .cancelled: return "İptal"
        case .snoozed: return "Ertelendi"
        }
    }

    private func statusColor(_ status: AlarmStatus) -> Color {
        switch status {
        case .pending: return .primary
        case .fired: return .secondary
        case .cancelled: return .orange
        case .snoozed: return .blue
        }
    }
}
