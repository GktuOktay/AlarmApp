import Foundation
import SwiftData

public enum ModelContainerFactory {
    /// In-memory container for tests and early scaffolding (empty schema until domain models land).
    public static func makeInMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Schema([]), configurations: [configuration])
    }
}
