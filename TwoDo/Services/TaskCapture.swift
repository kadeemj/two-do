import Foundation
import SwiftData

enum TaskCaptureError: LocalizedError {
    case emptyTitle

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "Enter a task title."
        }
    }
}

enum TaskCapture {
    @MainActor
    @discardableResult
    static func create(
        title: String,
        notes: String = "",
        dueAt: Date? = nil,
        isFlagged: Bool = false,
        in context: ModelContext,
        calendar: Calendar = .current
    ) throws -> TodoTask {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw TaskCaptureError.emptyTitle
        }

        let existingTasks = try context.fetch(FetchDescriptor<TodoTask>())
        let nextSortIndex = (existingTasks.map(\.sortIndex).max() ?? -1) + 1
        let task = TodoTask(
            title: trimmedTitle,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            dueAt: dueAt.map(calendar.startOfDay(for:)),
            sortIndex: nextSortIndex,
            isFlagged: isFlagged
        )

        context.insert(task)
        try context.save()
        return task
    }
}

@MainActor
final class TaskCaptureService {
    static let shared = TaskCaptureService()

    private var container: ModelContainer?

    private init() {}

    func configure(container: ModelContainer) {
        self.container = container
    }

    func capture(
        title: String,
        notes: String = "",
        dueAt: Date? = nil,
        isFlagged: Bool = false
    ) throws -> UUID {
        let resolvedContainer: ModelContainer
        if let container {
            resolvedContainer = container
        } else {
            let container = ModelContainerFactory.make()
            self.container = container
            resolvedContainer = container
        }

        let task = try TaskCapture.create(
            title: title,
            notes: notes,
            dueAt: dueAt,
            isFlagged: isFlagged,
            in: resolvedContainer.mainContext
        )
        return task.id
    }
}
