import AppIntents
import Foundation

struct CaptureTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick Capture Task"
    static let description = IntentDescription("Adds a task to TwoDo without opening the app.")

    @Parameter(title: "Task")
    var taskTitle: String

    @Parameter(title: "Notes")
    var notes: String?

    @Parameter(title: "Due Date")
    var dueDate: Date?

    @Parameter(title: "Flagged", default: false)
    var isFlagged: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$taskTitle)") {
            \.$notes
            \.$dueDate
            \.$isFlagged
        }
    }

    init() {
        taskTitle = ""
        notes = nil
        dueDate = nil
        isFlagged = false
    }

    init(
        taskTitle: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        isFlagged: Bool = false
    ) {
        self.taskTitle = taskTitle
        self.notes = notes
        self.dueDate = dueDate
        self.isFlagged = isFlagged
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmedTitle = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw $taskTitle.needsValueError("Enter a task title.")
        }

        _ = try await TaskCaptureService.shared.capture(
            title: trimmedTitle,
            notes: notes ?? "",
            dueAt: dueDate,
            isFlagged: isFlagged
        )

        return .result(dialog: "Added \(trimmedTitle) to TwoDo.")
    }
}

struct TwoDoAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaptureTaskIntent(),
            phrases: [
                "Add a task in \(.applicationName)",
                "Quick capture with \(.applicationName)"
            ],
            shortTitle: "Quick Capture",
            systemImageName: "plus.circle.fill"
        )
    }
}

enum CaptureTaskDonation {
    static func donate(
        title: String,
        notes: String = "",
        dueDate: Date? = nil,
        isFlagged: Bool = false
    ) {
        let intent = CaptureTaskIntent(
            taskTitle: title,
            notes: notes.isEmpty ? nil : notes,
            dueDate: dueDate,
            isFlagged: isFlagged
        )

        Task {
            try? await IntentDonationManager.shared.donate(intent: intent)
        }
    }
}
