import SwiftUI
import UserNotifications
import AlarmAppCore

struct SettingsView: View {
    @Bindable var preferences: AppPreferences
    @State private var notificationStatus: UNAuthorizationStatus?

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
                    .sensoryFeedback(.selection, trigger: preferences.autoWakePromptEnabled)

                    if preferences.healthKitSleepDenied {
                        Text("settings.autoWakePrompt.healthKitRequired")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("settings.autoWakePrompt.footer")
                }

                Section {
                    Toggle(isOn: calendarSuggestionsBinding) {
                        Text("settings.calendar_suggestions")
                    }
                    .disabled(preferences.calendarAccessDenied)
                    .sensoryFeedback(.selection, trigger: preferences.calendarSuggestionsEnabled)

                    if preferences.calendarAccessDenied {
                        Text("settings.calendar_suggestions.access_required")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("settings.calendar_suggestions.footer")
                }

                Section("settings.notifications") {
                    LabeledContent("settings.notifications.status") {
                        Text(LocalizedStringKey(notificationStatusLocalizationKey))
                            .foregroundStyle(.secondary)
                    }

                    if notificationStatus == .denied {
                        Button("settings.notifications.openSettings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }
                .task {
                    notificationStatus = await LocalNotificationScheduler().currentAuthorizationStatus()
                }

                // App Icon picker: add CFBundleIcons alternate icons to project.yml + supply artwork,
                // then build a Section here calling UIApplication.shared.setAlternateIconName(_:).

                Section("settings.about") {
                    LabeledContent("settings.version") {
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("settings.build") {
                        Text(buildNumber)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("settings.title")
            .animation(.spring(response: 0.3, dampingFraction: 1), value: preferences.healthKitSleepDenied)
            .animation(.spring(response: 0.3, dampingFraction: 1), value: preferences.calendarAccessDenied)
            .task {
                preferences.refreshHealthKitStatus()
            }
        }
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "—"
    }

    private var buildNumber: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "—"
    }

    private var notificationStatusLocalizationKey: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            return "status.authorized"
        case .denied:
            return "status.denied"
        case .notDetermined, .none:
            return "status.not_determined"
        @unknown default:
            return "status.not_determined"
        }
    }

    private var autoWakeBinding: Binding<Bool> {
        Binding(
            get: { preferences.autoWakePromptEnabled },
            set: { newValue in
                preferences.autoWakePromptEnabled = newValue
                Task {
                    if newValue {
                        await preferences.requestHealthKitSleepAccessIfNeeded()
                        if preferences.healthKitSleepDenied {
                            preferences.autoWakePromptEnabled = false
                        }
                    }
                    // Mirror S7 toggle to Watch via application context (TodayContext).
                    await WatchSyncBootstrap.shared.pushTodayContext()
                }
            }
        )
    }

    /// Phase 7 — opt-in EventKit bypass day suggestions toggle; mirrors `autoWakeBinding`'s
    /// permission-request-on-enable / denial-tracking pattern.
    private var calendarSuggestionsBinding: Binding<Bool> {
        Binding(
            get: { preferences.calendarSuggestionsEnabled },
            set: { newValue in
                preferences.calendarSuggestionsEnabled = newValue
                Task {
                    if newValue {
                        let granted = await CalendarBypassSuggestionService().requestAccess()
                        preferences.calendarAccessDenied = !granted
                        if !granted {
                            preferences.calendarSuggestionsEnabled = false
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
