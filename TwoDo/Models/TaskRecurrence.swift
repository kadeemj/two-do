import Foundation
import SwiftData

enum RecurrenceKind: String, CaseIterable, Identifiable {
    case daily
    case weekdays
    case weekly
    case monthly
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily:
            return "Daily"
        case .weekdays:
            return "Weekdays"
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        case .custom:
            return "Custom"
        }
    }
}

enum RecurrenceUnit: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    func label(for interval: Int) -> String {
        let base: String
        switch self {
        case .day:
            base = "day"
        case .week:
            base = "week"
        case .month:
            base = "month"
        }
        return interval == 1 ? base : "\(base)s"
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .day:
            return .day
        case .week:
            return .weekOfYear
        case .month:
            return .month
        }
    }
}

struct TaskRecurrence: Equatable {
    let kind: RecurrenceKind
    let interval: Int
    let unit: RecurrenceUnit

    init(kind: RecurrenceKind, interval: Int = 1, unit: RecurrenceUnit = .day) {
        self.kind = kind
        self.interval = max(interval, 1)
        self.unit = unit
    }

    var displayName: String {
        switch kind {
        case .daily:
            return "Daily"
        case .weekdays:
            return "Every weekday"
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        case .custom:
            return "Every \(interval) \(unit.label(for: interval))"
        }
    }

    func nextEligibleDate(
        after anchor: Date,
        laterThan cutoff: Date,
        dateOnly: Bool,
        calendar: Calendar = .current
    ) -> Date? {
        let threshold = dateOnly ? calendar.startOfDay(for: cutoff) : cutoff
        var candidate = nextDate(after: anchor, calendar: calendar)

        // Recurrences skip missed dates so completing an old task never creates
        // a backlog of already-overdue occurrences.
        for _ in 0..<10_000 {
            guard let value = candidate else { return nil }
            let comparedValue = dateOnly ? calendar.startOfDay(for: value) : value
            if comparedValue > threshold {
                return value
            }
            candidate = nextDate(after: value, calendar: calendar)
        }
        return nil
    }

    func nextDate(after date: Date, calendar: Calendar = .current) -> Date? {
        switch kind {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekdays:
            return nextWeekday(after: date, calendar: calendar)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        case .custom:
            return calendar.date(byAdding: unit.calendarComponent, value: interval, to: date)
        }
    }

    private func nextWeekday(after date: Date, calendar: Calendar) -> Date? {
        var candidate = date
        for _ in 0..<7 {
            guard let next = calendar.date(byAdding: .day, value: 1, to: candidate) else {
                return nil
            }
            candidate = next
            let weekday = calendar.component(.weekday, from: candidate)
            if weekday != 1 && weekday != 7 {
                return candidate
            }
        }
        return nil
    }
}

extension TodoTask {
    var recurrence: TaskRecurrence? {
        get {
            guard let recurrenceKindRaw,
                  let kind = RecurrenceKind(rawValue: recurrenceKindRaw) else {
                return nil
            }
            let unit = recurrenceUnitRaw.flatMap(RecurrenceUnit.init(rawValue:)) ?? .day
            return TaskRecurrence(kind: kind, interval: recurrenceInterval, unit: unit)
        }
        set {
            recurrenceKindRaw = newValue?.kind.rawValue
            recurrenceInterval = newValue?.interval ?? 1
            recurrenceUnitRaw = newValue?.unit.rawValue
            if newValue != nil, recurrenceSeriesID == nil {
                recurrenceSeriesID = UUID()
            }
        }
    }
}

@MainActor
enum TaskCompletion {
    @discardableResult
    static func toggle(
        _ task: TodoTask,
        in context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> TodoTask? {
        if task.isCompleted {
            task.isCompleted = false
            task.completedAt = nil
            task.updatedAt = now
            try context.save()
            return nil
        }

        task.isCompleted = true
        task.completedAt = now
        task.updatedAt = now
        let successor = createSuccessorIfNeeded(
            for: task,
            in: context,
            now: now,
            calendar: calendar
        )
        try context.save()
        return successor
    }

    private static func createSuccessorIfNeeded(
        for task: TodoTask,
        in context: ModelContext,
        now: Date,
        calendar: Calendar
    ) -> TodoTask? {
        guard task.parent == nil,
              task.generatedNextOccurrenceID == nil,
              let recurrence = task.recurrence else {
            return nil
        }

        let nextDueAt: Date?
        if let dueAt = task.dueAt {
            nextDueAt = recurrence.nextEligibleDate(
                after: dueAt,
                laterThan: now,
                dateOnly: true,
                calendar: calendar
            )
        } else if task.scheduledStart == nil {
            let today = calendar.startOfDay(for: now)
            nextDueAt = recurrence.nextEligibleDate(
                after: today,
                laterThan: today,
                dateOnly: true,
                calendar: calendar
            )
        } else {
            nextDueAt = nil
        }

        let nextScheduledStart = task.scheduledStart.flatMap {
            recurrence.nextEligibleDate(
                after: $0,
                laterThan: now,
                dateOnly: false,
                calendar: calendar
            )
        }

        guard nextDueAt != nil || nextScheduledStart != nil else {
            return nil
        }

        let seriesID = task.recurrenceSeriesID ?? UUID()
        task.recurrenceSeriesID = seriesID

        let successor = TodoTask(
            title: task.title,
            notes: task.notes,
            dueAt: nextDueAt,
            dueHasTime: false,
            scheduledStart: nextScheduledStart,
            durationMinutes: task.durationMinutes,
            sortIndex: now.timeIntervalSince1970,
            hasLocation: task.hasLocation,
            hasPhone: task.hasPhone,
            isFlagged: task.isFlagged,
            locationName: task.locationName,
            phoneLabel: task.phoneLabel,
            createdAt: now,
            updatedAt: now,
            project: task.project
        )
        successor.tags = task.tags
        successor.recurrence = recurrence
        successor.recurrenceSeriesID = seriesID
        context.insert(successor)

        for (index, subtask) in (task.subtasks ?? [])
            .sorted(by: { $0.sortIndex < $1.sortIndex })
            .enumerated() {
            let copiedSubtask = TodoTask(
                title: subtask.title,
                notes: subtask.notes,
                sortIndex: Double(index),
                hasLocation: subtask.hasLocation,
                hasPhone: subtask.hasPhone,
                isFlagged: subtask.isFlagged,
                locationName: subtask.locationName,
                phoneLabel: subtask.phoneLabel,
                createdAt: now,
                updatedAt: now,
                project: subtask.project ?? task.project,
                parent: successor
            )
            copiedSubtask.tags = subtask.tags
            context.insert(copiedSubtask)
        }

        task.generatedNextOccurrenceID = successor.id
        return successor
    }
}
