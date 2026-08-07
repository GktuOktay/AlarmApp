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

                Section {
                    Toggle(isOn: autoWakeBinding) {
                        Text("settings.autoWakePrompt")
                    }
                    .disabled(preferences.healthKitSleepDenied)

                    if preferences.healthKitSleepDenied {
                        Text("settings.autoWakePrompt.healthKitRequired")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("settings.autoWakePrompt.footer")
                }
            }
            .navigationTitle("settings.title")
            .task {
                preferences.refreshHealthKitStatus()
            }
        }
    }

    private var autoWakeBinding: Binding<Bool> {
        Binding(
            get: { preferences.autoWakePromptEnabled },
            set: { newValue in
                preferences.autoWakePromptEnabled = newValue
                if newValue {
                    Task {
                        await preferences.requestHealthKitSleepAccessIfNeeded()
                        if preferences.healthKitSleepDenied {
                            preferences.autoWakePromptEnabled = false
                        }
                    }
                }
            }
        )
    }
}

#Preview {
    SettingsView(preferences: AppPreferences())
}
