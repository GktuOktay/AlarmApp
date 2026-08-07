import SwiftUI
import SwiftData
import AlarmAppCore

@main
struct AlarmApp_WatchApp: App {
    private let container: ModelContainer
    @StateObject private var ringing = WatchRingingPresenter.shared
    @StateObject private var wakeDetection = WakeDetectionCoordinator.shared

    init() {
        do {
            container = try ModelContainerFactory.makeOnDisk()
        } catch {
            fatalError("SwiftData container oluşturulamadı: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                Group {
                    if let session = ringing.session {
                        AlarmRingingView(session: session) {
                            ringing.dismiss()
                        }
                    } else if let prompt = wakeDetection.promptContext {
                        WakePromptView(context: prompt) {
                            wakeDetection.clearPrompt()
                        }
                    } else {
                        WatchHomeView()
                    }
                }
            }
            .modelContainer(container)
            .environmentObject(ringing)
            .environmentObject(wakeDetection)
            .task {
                WatchSyncBootstrap.shared.start(container: container)
                let enabled = UserDefaults.standard.object(forKey: "app.autoWakePromptEnabled") as? Bool ?? true
                wakeDetection.start(container: container, isEnabled: enabled)
            }
        }
    }
}

@MainActor
final class WatchRingingPresenter: ObservableObject {
    static let shared = WatchRingingPresenter()

    @Published var session: WatchRingingSession?

    func present(_ session: WatchRingingSession) {
        self.session = session
    }

    func dismiss() {
        session = nil
    }
}

struct WatchHomeView: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("AlarmApp")
                .font(.headline)
            Text("Gruplar telefonda yönetilir. Çalan alarm burada kapatılır veya ertelenir.")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Alarm")
    }
}

#Preview {
    WatchHomeView()
}
