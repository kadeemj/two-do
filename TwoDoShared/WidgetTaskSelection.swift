import Foundation

enum WidgetTaskSelection {
    static func active(from tasks: [WidgetTaskSnapshot], now: Date) -> WidgetTaskSnapshot? {
        tasks
            .filter { task in
                guard let start = task.scheduledStart, let end = task.scheduledEnd else { return false }
                return start <= now && now < end
            }
            .sorted { ($0.scheduledEnd ?? .distantFuture) < ($1.scheduledEnd ?? .distantFuture) }
            .first
    }

    static func focus(
        from tasks: [WidgetTaskSnapshot],
        now: Date,
        calendar: Calendar = .current
    ) -> WidgetTaskSnapshot? {
        if let active = active(from: tasks, now: now) { return active }

        if let scheduled = tasks
            .filter({ ($0.scheduledStart ?? .distantPast) > now })
            .sorted(by: chronologicalSort)
            .first {
            return scheduled
        }

        if let overdue = overdue(from: tasks, now: now, calendar: calendar).first {
            return overdue
        }

        if let today = today(from: tasks, now: now, calendar: calendar).first {
            return today
        }

        if let future = upcoming(from: tasks, now: now, calendar: calendar).first {
            return future
        }

        return tasks
            .filter { $0.dueAt == nil && $0.scheduledStart == nil }
            .sorted { $0.sortIndex < $1.sortIndex }
            .first
    }

    static func today(
        from tasks: [WidgetTaskSnapshot],
        now: Date,
        calendar: Calendar = .current
    ) -> [WidgetTaskSnapshot] {
        let startToday = calendar.startOfDay(for: now)
        return tasks
            .filter { task in
                let overdue = task.dueAt.map { $0 < startToday } ?? false
                let dueToday = task.dueAt.map { calendar.isDate($0, inSameDayAs: now) } ?? false
                let scheduledToday = task.scheduledStart.map { calendar.isDate($0, inSameDayAs: now) } ?? false
                return overdue || dueToday || scheduledToday
            }
            .sorted { lhs, rhs in
                let lhsRank = todayRank(lhs, now: now, calendar: calendar)
                let rhsRank = todayRank(rhs, now: now, calendar: calendar)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return chronologicalSort(lhs, rhs)
            }
    }

    static func upcoming(
        from tasks: [WidgetTaskSnapshot],
        now: Date,
        calendar: Calendar = .current
    ) -> [WidgetTaskSnapshot] {
        let startToday = calendar.startOfDay(for: now)
        return tasks
            .filter { task in
                let scheduledLater = task.scheduledStart.map { $0 > now } ?? false
                let dueLater = task.dueAt.map { calendar.startOfDay(for: $0) > startToday } ?? false
                return scheduledLater || dueLater
            }
            .sorted(by: chronologicalSort)
    }

    static func following(
        focus: WidgetTaskSnapshot?,
        from tasks: [WidgetTaskSnapshot],
        now: Date,
        calendar: Calendar = .current
    ) -> [WidgetTaskSnapshot] {
        let combined = today(from: tasks, now: now, calendar: calendar)
            + upcoming(from: tasks, now: now, calendar: calendar)
        var seen = Set<UUID>()
        if let focus { seen.insert(focus.id) }
        return combined.filter { seen.insert($0.id).inserted }
    }

    static func transitionDates(
        from tasks: [WidgetTaskSnapshot],
        now: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        let horizon = calendar.date(byAdding: .day, value: 2, to: now) ?? now.addingTimeInterval(172_800)
        var dates = tasks.flatMap { task in
            [task.scheduledStart, task.scheduledEnd].compactMap { $0 }
        }
        if let nextMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            dates.append(nextMidnight)
        }

        return Array(Set(dates.filter { $0 > now && $0 <= horizon }))
            .sorted()
            .prefix(32)
            .map { $0 }
    }

    static func isOverdue(
        _ task: WidgetTaskSnapshot,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard let dueAt = task.dueAt else { return false }
        return dueAt < calendar.startOfDay(for: now)
    }

    private static func todayRank(
        _ task: WidgetTaskSnapshot,
        now: Date,
        calendar: Calendar
    ) -> Int {
        if isOverdue(task, now: now, calendar: calendar) { return 0 }
        if task.scheduledStart != nil { return 1 }
        return 2
    }

    private static func chronologicalSort(_ lhs: WidgetTaskSnapshot, _ rhs: WidgetTaskSnapshot) -> Bool {
        let lhsDate = lhs.scheduledStart ?? lhs.dueAt ?? .distantFuture
        let rhsDate = rhs.scheduledStart ?? rhs.dueAt ?? .distantFuture
        if lhsDate != rhsDate { return lhsDate < rhsDate }
        return lhs.sortIndex < rhs.sortIndex
    }

    private static func overdue(
        from tasks: [WidgetTaskSnapshot],
        now: Date,
        calendar: Calendar
    ) -> [WidgetTaskSnapshot] {
        tasks
            .filter { isOverdue($0, now: now, calendar: calendar) }
            .sorted(by: chronologicalSort)
    }
}
