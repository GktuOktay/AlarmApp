import SwiftUI
import SwiftData
import AlarmAppCore

enum AppTab: Hashable {
    case calendar
    case alarms
    case groups
    case settings
}

struct RootTabView: View {
    @Bindable var preferences: AppPreferences
    @State private var selectedTab: AppTab = .calendar

    var body: some View {
        TabView(selection: $selectedTab) {
            CalendarView()
                .environment(preferences)
                .tabItem { Label("tab.calendar", systemImage: "calendar") }
                .tag(AppTab.calendar)

            AlarmListView()
                .tabItem { Label("tab.alarms", systemImage: "alarm") }
                .tag(AppTab.alarms)

            GroupListView()
                .tabItem { Label("tab.groups", systemImage: "rectangle.3.group") }
                .tag(AppTab.groups)

            SettingsView(preferences: preferences)
                .tabItem { Label("tab.settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .environment(\.locale, preferences.locale)
        .preferredColorScheme(preferences.appearance.preferredColorScheme)
        .fullScreenCover(
            isPresented: Binding(
                get: { !preferences.hasCompletedOnboarding },
                set: { newValue in preferences.hasCompletedOnboarding = !newValue }
            )
        ) {
            OnboardingContainerView(onFinished: {
                preferences.hasCompletedOnboarding = true
            })
        }
    }
}

#Preview {
    RootTabView(preferences: AppPreferences())
        .modelContainer(try! ModelContainerFactory.makeInMemory())
}
