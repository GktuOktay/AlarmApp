import Foundation
import SwiftData

public enum ModelContainerFactory {
    public static func schema() -> Schema {
        Schema([
            AlarmGroup.self,
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
        return try ModelContainer(for: schema(), configurations: [configuration])
    }
}
