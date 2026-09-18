import SwiftUI
import SwiftData

@main
struct TwoDoApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var router = AppRouter()
    private let container: ModelContainer

    init() {
        container = ModelContainerFactory.make()
        TaskCaptureService.shared.configure(container: container)
        NotificationScheduler.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(router: router)
                .task {
                    await NotificationScheduler.shared.requestAuthorizationIfNeeded()
                    #if DEBUG
                    // UI-test hook: seed a time block starting shortly so the
                    // smoke test can observe a real notification banner.
                    // (Due-date notifications fire at 9 AM, so only time
                    // blocks can be scheduled at an arbitrary near moment.)
                    if ProcessInfo.processInfo.environment["TWODO_SMOKE_TEST"] == "1" {
                        let task = TodoTask(
                            title: "Smoke test task",
                            scheduledStart: .now.addingTimeInterval(60),
                            durationMinutes: 15
                        )
                        container.mainContext.insert(task)
                        try? container.mainContext.save()
                    }
                    #endif
                    await NotificationScheduler.shared.resync(container: container)
                    WidgetSnapshotExporter.shared.export(container: container)
                }
                .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
                    NotificationScheduler.shared.scheduleResync(container: container)
                    WidgetSnapshotExporter.shared.scheduleExport(container: container)
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            // Foreground resync picks up changes that synced in from the
            // user's other devices via CloudKit while backgrounded.
            if phase == .active {
                NotificationScheduler.shared.scheduleResync(container: container)
                WidgetSnapshotExporter.shared.scheduleExport(container: container)
            }
        }
    }
}
