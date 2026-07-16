import Foundation
import SwiftData

enum ModelContainerFactory {
    static let cloudKitContainerID = "iCloud.com.kadeem.twodo"

    static func make() -> ModelContainer {
        let schema = Schema([TodoTask.self, Project.self, Tag.self])

        // Prefer CloudKit when available; fall back to local-only so the app
        // still runs on simulators / unsigned-iCloud accounts.
        let cloudConfig = ModelConfiguration(
            "TwoDo",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private(cloudKitContainerID)
        )

        do {
            return try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            let localConfig = ModelConfiguration(
                "TwoDoLocal",
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            do {
                return try ModelContainer(for: schema, configurations: [localConfig])
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
    }

    @MainActor
    static func makePreview() -> ModelContainer {
        let schema = Schema([TodoTask.self, Project.self, Tag.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            SampleData.seedIfNeeded(in: container.mainContext, force: true)
            return container
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }
}
