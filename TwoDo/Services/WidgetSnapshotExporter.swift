import Foundation
import SwiftData
import WidgetKit

@MainActor
final class WidgetSnapshotExporter {
    static let shared = WidgetSnapshotExporter()

    private var pendingExport: Task<Void, Never>?

    private init() {}

    func scheduleExport(container: ModelContainer) {
        pendingExport?.cancel()
        pendingExport = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            export(container: container)
        }
    }

    func export(container: ModelContainer) {
        let descriptor = FetchDescriptor<TodoTask>(sortBy: [SortDescriptor(\TodoTask.sortIndex)])
        guard let tasks = try? container.mainContext.fetch(descriptor) else { return }

        let snapshots = tasks
            .filter { !$0.isCompleted && $0.parent == nil }
            .prefix(200)
            .map { task in
                WidgetTaskSnapshot(
                    id: task.id,
                    title: task.title,
                    dueAt: task.dueAt,
                    scheduledStart: task.scheduledStart,
                    scheduledEnd: task.scheduledEnd,
                    projectName: task.project?.name,
                    projectColorHex: task.project?.colorHex ?? "3380F5",
                    isFlagged: task.isFlagged,
                    sortIndex: task.sortIndex
                )
            }

        let envelope = WidgetSnapshotEnvelope(generatedAt: .now, tasks: snapshots)
        guard WidgetSnapshotStore.save(envelope) else { return }
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetConstants.widgetKind)
    }
}
