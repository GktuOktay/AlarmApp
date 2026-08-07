import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: AppPreferences

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $preferences.languageRaw) {
                        ForEach(AppLanguageCode.allCases) { code in
                            Text(LocalizedStringKey(code.localizationKey)).tag(code.rawValue)
                        }
                    } label: {
                        Text("settings.language")
                    }
                    .pickerStyle(.navigationLink)

                    Picker(selection: $preferences.appearanceRaw) {
                        ForEach(AppAppearanceMode.allCases) { mode in
                            Text(LocalizedStringKey(mode.localizationKey)).tag(mode.rawValue)
                        }
                    } label: {
                        Text("settings.appearance")
                    }
                    .pickerStyle(.navigationLink)
                }
            }
        }
    }
}

#Preview {
    SettingsView(preferences: AppPreferences())
}
