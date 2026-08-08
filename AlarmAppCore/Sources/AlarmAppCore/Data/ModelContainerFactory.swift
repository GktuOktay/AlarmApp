import Foundation
import SwiftData

public enum ModelContainerFactory {
    public static func schema() -> Schema {
        Schema([
            AlarmGroup.self,
            Alarm.self,
            AlarmInstance.self,
            AlarmException.self,
            WakeEventLog.self
        ])
    }

    public static func makeInMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema(), configurations: [configuration])
    }

    public static func makeOnDisk(url: URL? = nil) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(url: url)
        } else {
            configuration = ModelConfiguration()
        }
        do {
            return try ModelContainer(for: schema(), configurations: [configuration])
        } catch {
            AppLog.error(.swiftdata, "makeOnDisk open failed; wiping incompatible store", error: error)
            // 0.0.x: wipe incompatible store after schema breaks (e.g. new AlarmException.alarmId).
            let storeURL = configuration.url
            let fm = FileManager.default
            for suffix in ["", "-wal", "-shm"] {
                let file = URL(fileURLWithPath: storeURL.path + suffix)
                try? fm.removeItem(at: file)
            }
            // Also clear default Application Support folder siblings if named differently
            if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                if let contents = try? fm.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) {
                    for file in contents where file.lastPathComponent.contains("default")
                        || file.pathExtension == "store"
                        || file.lastPathComponent.contains("SwiftData")
                    {
                        try? fm.removeItem(at: file)
                    }
                }
            }
            do {
                return try ModelContainer(for: schema(), configurations: [configuration])
            } catch {
                AppLog.error(.swiftdata, "makeOnDisk recovery open failed", error: error)
                throw error
            }
        }
    }
}
