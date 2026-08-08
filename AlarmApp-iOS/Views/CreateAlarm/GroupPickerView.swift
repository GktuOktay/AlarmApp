import SwiftUI
import SwiftData
import AlarmAppCore

struct GroupPickerView: View {
    @Binding var groupSelection: CreateAlarmView.GroupSelection
    @Binding var newGroupName: String
    let groups: [AlarmGroup]

    var body: some View {
        Form {
            Section {
                Picker("detail.group", selection: $groupSelection) {
                    Text("create.group_none").tag(CreateAlarmView.GroupSelection.none)
                    ForEach(groups, id: \.id) { group in
                        Text(group.name).tag(CreateAlarmView.GroupSelection.existing(group.id))
                    }
                    Text("create.group_new").tag(CreateAlarmView.GroupSelection.createNew)
                }
                if groupSelection == .createNew {
                    TextField("create.group_new_name", text: $newGroupName)
                }
            }
        }
        .navigationTitle(Text("create.group_section"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
