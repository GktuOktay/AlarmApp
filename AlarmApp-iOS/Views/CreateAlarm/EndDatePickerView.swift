import SwiftUI

struct EndDatePickerView: View {
    @Binding var hasEndDate: Bool
    @Binding var endDate: Date

    var body: some View {
        Form {
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
                Text(hasEndDate ? "create.end_footer_on" : "create.end_footer_off")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(Text("create.end_toggle"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        EndDatePickerView(hasEndDate: .constant(true), endDate: .constant(Date()))
    }
}
