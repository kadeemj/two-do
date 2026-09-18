import Foundation

enum TaskSmartList: String, CaseIterable, Identifiable {
    case all
    case today
    case upcoming
    case flagged
    case completed
    case noDate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .today: return "Today"
        case .upcoming: return "Upcoming"
        case .flagged: return "Flagged"
        case .completed: return "Completed"
        case .noDate: return "No Date"
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "tray.full"
        case .today: return "sun.max"
        case .upcoming: return "calendar"
        case .flagged: return "flag.fill"
        case .completed: return "checkmark.circle.fill"
        case .noDate: return "calendar.badge.minus"
        }
    }

    func tasks(
        from tasks: [TodoTask],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [TodoTask] {
        let roots = tasks.filter { $0.parent == nil }
        let startOfToday = calendar.startOfDay(for: now)

        let filtered = roots.filter { task in
            switch self {
            case .all:
                return !task.isCompleted
            case .today:
                return !task.isCompleted && task.isDueToday(relativeTo: now, calendar: calendar)
            case .upcoming:
                guard !task.isCompleted, let date = task.dueAt ?? task.scheduledStart else {
                    return false
                }
                return calendar.startOfDay(for: date) > startOfToday
            case .flagged:
                return !task.isCompleted && task.isFlagged
            case .completed:
                return task.isCompleted
            case .noDate:
                return !task.isCompleted && task.dueAt == nil && task.scheduledStart == nil
            }
        }

        return filtered.sorted { lhs, rhs in
            if self == .completed {
                return (lhs.completedAt ?? .distantPast) > (rhs.completedAt ?? .distantPast)
            }

            let lhsDate = lhs.dueAt ?? lhs.scheduledStart ?? .distantFuture
            let rhsDate = rhs.dueAt ?? rhs.scheduledStart ?? .distantFuture
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            return lhs.sortIndex < rhs.sortIndex
        }
    }
}

enum TaskSearchScope: String, CaseIterable, Identifiable {
    case everything
    case titles
    case notes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .everything: return "Everything"
        case .titles: return "Titles"
        case .notes: return "Notes"
        }
    }
}

enum TaskSearch {
    static func results(
        in tasks: [TodoTask],
        query: String,
        scope: TaskSearchScope
    ) -> [TodoTask] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return tasks }

        return tasks.filter { task in
            switch scope {
            case .titles:
                return task.title.localizedCaseInsensitiveContains(normalizedQuery)
            case .notes:
                return task.notes.localizedCaseInsensitiveContains(normalizedQuery)
            case .everything:
                return task.title.localizedCaseInsensitiveContains(normalizedQuery)
                    || task.notes.localizedCaseInsensitiveContains(normalizedQuery)
                    || (task.project?.name.localizedCaseInsensitiveContains(normalizedQuery) ?? false)
                    || (task.tags?.contains {
                        $0.name.localizedCaseInsensitiveContains(normalizedQuery)
                    } ?? false)
                    || (task.locationName?.localizedCaseInsensitiveContains(normalizedQuery) ?? false)
                    || (task.phoneLabel?.localizedCaseInsensitiveContains(normalizedQuery) ?? false)
            }
        }
    }
}
