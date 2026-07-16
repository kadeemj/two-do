import Foundation
import SwiftData

enum ModelContainerFactory {
    static let cloudKitContainerID = "iCloud.com.kadeem.twodo"

    /// True when the store was opened with CloudKit sync enabled.
    private(set) static var isCloudBacked = false

    static func make() -> ModelContainer {
        let schema = Schema([TodoTask.self, Project.self, Tag.self])

        // Earlier builds always fell back to the local store, so keep using its
        // file — existing data is promoted into CloudKit on first sync.
        let storeURL = URL.applicationSupportDirectory.appending(path: "TwoDoLocal.store")

        // Prefer CloudKit when available; fall back to local-only so the app
        // still runs on simulators / unsigned-iCloud accounts.
        let cloudConfig = ModelConfiguration(
            "TwoDo",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .private(cloudKitContainerID)
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [cloudConfig])
            isCloudBacked = true
            return container
        } catch {
            print("TwoDo: CloudKit store unavailable (\(error)); using local-only store.")
            let localConfig = ModelConfiguration(
                "TwoDoLocal",
                schema: schema,
                url: storeURL,
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
