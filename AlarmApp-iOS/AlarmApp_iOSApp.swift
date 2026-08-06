import SwiftUI
import AlarmAppCore

@main
struct AlarmApp_iOSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        Text("AlarmApp \(AlarmAppCoreModule.version)")
            .padding()
    }
}

#Preview {
    ContentView()
}
