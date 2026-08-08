import SwiftUI
import AlarmAppCore

struct WakeSchedulePickerView: View {
    @Binding var isWakeSchedule: Bool

    var body: some View {
        Form {
            Section {
                Toggle("create.wake_schedule", isOn: $isWakeSchedule)
                    .tint(AlarmColors.success)
                Text("create.wake_schedule_footer")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(Text("create.wake_schedule"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        WakeSchedulePickerView(isWakeSchedule: .constant(true))
    }
}
