import Foundation

enum TaskReminderOption: String, CaseIterable, Identifiable, Hashable {
    case eveningBefore
    case morningOf
    case oneHourBefore
    case thirtyMinutesBefore
    case tenMinutesBefore
    case atStart

    var id: String { rawValue }

    var title: String {
        switch self {
        case .eveningBefore:
            return "Evening before"
        case .morningOf:
            return "Morning of"
        case .oneHourBefore:
            return "1 hour before"
        case .thirtyMinutesBefore:
            return "30 minutes before"
        case .tenMinutesBefore:
            return "10 minutes before"
        case .atStart:
            return "At start"
        }
    }

    var detail: String {
        switch self {
        case .eveningBefore:
            return "6:00 PM the previous day"
        case .morningOf:
            return "9:00 AM on the task day"
        case .oneHourBefore, .thirtyMinutesBefore, .tenMinutesBefore:
            return "Before the time block"
        case .atStart:
            return "When the time block begins"
        }
    }

    var sortOrder: Int {
        switch self {
        case .eveningBefore:
            return 0
        case .morningOf:
            return 1
        case .oneHourBefore:
            return 2
        case .thirtyMinutesBefore:
            return 3
        case .tenMinutesBefore:
            return 4
        case .atStart:
            return 5
        }
    }

    var requiresTimeBlock: Bool {
        switch self {
        case .oneHourBefore, .thirtyMinutesBefore, .tenMinutesBefore, .atStart:
            return true
        case .eveningBefore, .morningOf:
            return false
        }
    }
}

struct TaskReminderOccurrence: Equatable {
    let option: TaskReminderOption
    let fireAt: Date
    let body: String
}

enum TaskReminderPlan {
    static func availableOptions(hasDue: Bool, hasSchedule: Bool) -> [TaskReminderOption] {
        TaskReminderOption.allCases
            .filter { option in
                if option.requiresTimeBlock {
                    return hasSchedule
                }
                return hasDue || hasSchedule
            }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    static func defaultOptions(hasDue: Bool, hasSchedule: Bool) -> Set<TaskReminderOption> {
        var options: Set<TaskReminderOption> = []
        if hasDue {
            options.insert(.morningOf)
        }
        if hasSchedule {
            options.insert(.atStart)
        }
        return options
    }

    static func occurrences(
        for task: TodoTask,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [TaskReminderOccurrence] {
        guard task.remindersEnabled, !task.isCompleted else { return [] }

        let available = Set(availableOptions(
            hasDue: task.dueAt != nil,
            hasSchedule: task.scheduledStart != nil
        ))
        let selected = task.reminderOptions.intersection(available)
        var occurrencesByDate: [Date: TaskReminderOccurrence] = [:]

        for option in selected.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            guard let occurrence = occurrence(
                for: option,
                task: task,
                calendar: calendar
            ), occurrence.fireAt > now else {
                continue
            }

            // Two rules can resolve to the same minute (for example, a 9 AM
            // block with both Morning of and At start). Schedule one alert.
            occurrencesByDate[occurrence.fireAt] = occurrence
        }

        return occurrencesByDate.values.sorted { $0.fireAt < $1.fireAt }
    }

    private static func occurrence(
        for option: TaskReminderOption,
        task: TodoTask,
        calendar: Calendar
    ) -> TaskReminderOccurrence? {
        switch option {
        case .atStart:
            guard let start = task.scheduledStart else { return nil }
            return TaskReminderOccurrence(
                option: option,
                fireAt: start,
                body: "Time block starting"
            )

        case .tenMinutesBefore:
            return timeBlockOccurrence(
                option: option,
                task: task,
                minutesBefore: 10
            )

        case .thirtyMinutesBefore:
            return timeBlockOccurrence(
                option: option,
                task: task,
                minutesBefore: 30
            )

        case .oneHourBefore:
            return timeBlockOccurrence(
                option: option,
                task: task,
                minutesBefore: 60
            )

        case .morningOf:
            guard let anchor = task.dueAt ?? task.scheduledStart,
                  let fireAt = calendar.date(
                    bySettingHour: 9,
                    minute: 0,
                    second: 0,
                    of: anchor
                  ) else {
                return nil
            }

            // For schedule-only tasks, never alert after the time block starts.
            if task.dueAt == nil, let start = task.scheduledStart, fireAt >= start {
                return nil
            }
            return TaskReminderOccurrence(
                option: option,
                fireAt: fireAt,
                body: task.dueAt == nil ? "Scheduled today" : "Due today"
            )

        case .eveningBefore:
            guard let anchor = task.dueAt ?? task.scheduledStart,
                  let previousDay = calendar.date(byAdding: .day, value: -1, to: anchor),
                  let fireAt = calendar.date(
                    bySettingHour: 18,
                    minute: 0,
                    second: 0,
                    of: previousDay
                  ) else {
                return nil
            }
            return TaskReminderOccurrence(
                option: option,
                fireAt: fireAt,
                body: task.dueAt == nil ? "Scheduled tomorrow" : "Due tomorrow"
            )
        }
    }

    private static func timeBlockOccurrence(
        option: TaskReminderOption,
        task: TodoTask,
        minutesBefore: Int
    ) -> TaskReminderOccurrence? {
        guard let start = task.scheduledStart else { return nil }
        let fireAt = start.addingTimeInterval(TimeInterval(-minutesBefore * 60))
        return TaskReminderOccurrence(
            option: option,
            fireAt: fireAt,
            body: "Time block starts in \(durationLabel(minutesBefore))"
        )
    }

    private static func durationLabel(_ minutes: Int) -> String {
        if minutes == 60 {
            return "1 hour"
        }
        return "\(minutes) minutes"
    }
}

extension TodoTask {
    var reminderOptions: Set<TaskReminderOption> {
        get {
            guard let reminderOptionsRaw else {
                return TaskReminderPlan.defaultOptions(
                    hasDue: dueAt != nil,
                    hasSchedule: scheduledStart != nil
                )
            }

            return Set(
                reminderOptionsRaw
                    .split(separator: ",")
                    .compactMap { TaskReminderOption(rawValue: String($0)) }
            )
        }
        set {
            reminderOptionsRaw = newValue
                .sorted(by: { $0.sortOrder < $1.sortOrder })
                .map(\.rawValue)
                .joined(separator: ",")
        }
    }

    var reminderSummary: String {
        guard remindersEnabled else { return "Off" }
        let available = Set(TaskReminderPlan.availableOptions(
            hasDue: dueAt != nil,
            hasSchedule: scheduledStart != nil
        ))
        let options = reminderOptions
            .intersection(available)
            .sorted { $0.sortOrder < $1.sortOrder }

        guard !options.isEmpty else { return "Off" }
        return options.map(\.title).joined(separator: ", ")
    }
}
