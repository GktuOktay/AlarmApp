import SwiftUI
import SwiftData
import AlarmAppCore

@main
struct AlarmApp_iOSApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainerFactory.makeOnDisk()
        } catch {
            fatalError("SwiftData container oluşturulamadı: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            GroupListView()
        }
        .modelContainer(container)
    }
}
