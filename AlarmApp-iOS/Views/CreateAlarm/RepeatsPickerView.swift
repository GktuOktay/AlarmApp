import SwiftUI
import AlarmAppCore

struct RepeatsPickerView: View {
    @Binding var repeats: Bool
    @Binding var selectedDays: Set<Weekday>

    var body: some View {
        Form {
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
                Text(repeats ? "create.repeats_on_footer" : "create.repeats_off_footer")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(Text("create.repeats"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        RepeatsPickerView(repeats: .constant(true), selectedDays: .constant([.monday, .tuesday]))
    }
}
