import SwiftUI
import AlarmAppCore

@main
struct AlarmApp_WatchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        Text("AlarmApp \(AlarmAppCoreModule.version)")
    }
}

#Preview {
    ContentView()
}
