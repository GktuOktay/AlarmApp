import SwiftUI
import SwiftData
import AlarmAppCore

@main
struct AlarmApp_WatchApp: App {
    private let container: ModelContainer
    @StateObject private var ringing = WatchRingingPresenter.shared

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
                    } else {
                        WatchHomeView()
                    }
                }
            }
            .modelContainer(container)
            .environmentObject(ringing)
            .task {
                WatchSyncBootstrap.shared.start(container: container)
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
