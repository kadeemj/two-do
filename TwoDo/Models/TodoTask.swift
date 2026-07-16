import Foundation
import SwiftData

@Model
final class TodoTask: Identifiable {
    var id: UUID
    var title: String
    var notes: String
    var dueAt: Date?
    var scheduledStart: Date?
    var durationMinutes: Int?
    var isCompleted: Bool
    var completedAt: Date?
    var sortIndex: Double
    var hasLocation: Bool
    var hasPhone: Bool
    var isFlagged: Bool
    var locationName: String?
    var phoneLabel: String?
    var createdAt: Date
    var updatedAt: Date

    var project: Project?

    var parent: TodoTask?

    @Relationship(deleteRule: .cascade, inverse: \TodoTask.parent)
    var subtasks: [TodoTask]?

    var tags: [Tag]?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        dueAt: Date? = nil,
        scheduledStart: Date? = nil,
        durationMinutes: Int? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        sortIndex: Double = 0,
        hasLocation: Bool = false,
        hasPhone: Bool = false,
        isFlagged: Bool = false,
        locationName: String? = nil,
        phoneLabel: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        project: Project? = nil,
        parent: TodoTask? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueAt = dueAt
        self.scheduledStart = scheduledStart
        self.durationMinutes = durationMinutes
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.sortIndex = sortIndex
        self.hasLocation = hasLocation
        self.hasPhone = hasPhone
        self.isFlagged = isFlagged
        self.locationName = locationName
        self.phoneLabel = phoneLabel
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.project = project
        self.parent = parent
    }
}

extension TodoTask {
    var scheduledEnd: Date? {
        guard let start = scheduledStart, let minutes = durationMinutes else { return nil }
        return start.addingTimeInterval(TimeInterval(minutes * 60))
    }

    var projectColor: ColorTokensCompatible {
        ColorTokensCompatible(hex: project?.colorHex ?? "3380F5")
    }

    func isOverdue(relativeTo date: Date = .now, calendar: Calendar = .current) -> Bool {
        guard !isCompleted, let due = dueAt else { return false }
        return due < calendar.startOfDay(for: date)
    }

    func isDueToday(relativeTo date: Date = .now, calendar: Calendar = .current) -> Bool {
        guard !isCompleted else { return false }
        if let due = dueAt, calendar.isDate(due, inSameDayAs: date) { return true }
        if let start = scheduledStart, calendar.isDate(start, inSameDayAs: date) { return true }
        return false
    }

    func isScheduled(on date: Date, calendar: Calendar = .current) -> Bool {
        guard let start = scheduledStart else { return false }
        return calendar.isDate(start, inSameDayAs: date)
    }
}

/// Lightweight color holder for model layer without importing SwiftUI in every call site.
struct ColorTokensCompatible {
    let hex: String
}
