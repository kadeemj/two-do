import SwiftUI
import SwiftData

@main
struct TwoDoApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let container: ModelContainer

    init() {
        container = ModelContainerFactory.make()
        NotificationScheduler.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .task {
                    await NotificationScheduler.shared.requestAuthorizationIfNeeded()
                    #if DEBUG
                    // UI-test hook: seed a task due shortly so the smoke test
                    // can observe a real notification banner.
                    if ProcessInfo.processInfo.environment["TWODO_SMOKE_TEST"] == "1" {
                        let task = TodoTask(
                            title: "Smoke test task",
                            dueAt: .now.addingTimeInterval(60)
                        )
                        container.mainContext.insert(task)
                        try? container.mainContext.save()
                    }
                    #endif
                    await NotificationScheduler.shared.resync(container: container)
                }
                .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
                    NotificationScheduler.shared.scheduleResync(container: container)
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            // Foreground resync picks up changes that synced in from the
            // user's other devices via CloudKit while backgrounded.
            if phase == .active {
                NotificationScheduler.shared.scheduleResync(container: container)
            }
        }
    }
}
