import SwiftUI
import AlarmAppCore

@main
struct AlarmApp_WatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchHomeView()
        }
    }
}

struct WatchHomeView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("AlarmApp")
                .font(.headline)
            Text("Gruplar telefonda yönetilir. “Uyandım” yakında.")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    WatchHomeView()
}
