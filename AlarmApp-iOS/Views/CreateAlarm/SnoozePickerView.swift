import SwiftUI
import AlarmAppCore

struct SnoozePickerView: View {
    @Binding var snoozeEnabled: Bool
    @Binding var snoozeMinutes: Int

    private var snoozeMinuteOptions: [Int] {
        Array(SnoozePolicy.minMinutes...SnoozePolicy.maxMinutes)
    }

    var body: some View {
        Form {
            Section {
                Toggle("create.snooze", isOn: $snoozeEnabled)
                    .tint(AlarmColors.success)
                if snoozeEnabled {
                    Picker("create.snooze_duration", selection: $snoozeMinutes) {
                        ForEach(snoozeMinuteOptions, id: \.self) { minutes in
                            Text(
                                String(
                                    format: String(localized: "create.snooze_minutes"),
                                    minutes
                                )
                            )
                            .tag(minutes)
                            .foregroundStyle(AlarmColors.warn)
                        }
                    }
                    .tint(AlarmColors.warn)
                }
            }
        }
        .navigationTitle(Text("create.snooze"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SnoozePickerView(snoozeEnabled: .constant(true), snoozeMinutes: .constant(SnoozePolicy.defaultMinutes))
    }
}
