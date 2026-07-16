import Foundation
import SwiftData

enum TaskQueries {
    static func incomplete(from tasks: [TodoTask]) -> [TodoTask] {
        tasks.filter { !$0.isCompleted && $0.parent == nil }
    }

    static func overdue(from tasks: [TodoTask], now: Date = .now) -> [TodoTask] {
        incomplete(from: tasks)
            .filter { $0.isOverdue(relativeTo: now) }
            .sorted { ($0.dueAt ?? .distantPast) < ($1.dueAt ?? .distantPast) }
    }

    static func today(from tasks: [TodoTask], now: Date = .now) -> [TodoTask] {
        incomplete(from: tasks)
            .filter { $0.isDueToday(relativeTo: now) && !$0.isOverdue(relativeTo: now) }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    static func scheduled(on day: Date, from tasks: [TodoTask]) -> [TodoTask] {
        tasks
            .filter { !$0.isCompleted && $0.parent == nil && $0.isScheduled(on: day) }
            .sorted { ($0.scheduledStart ?? .distantPast) < ($1.scheduledStart ?? .distantPast) }
    }

    /// Tasks due at a specific time that day without their own time block —
    /// they still occupy a slot on the schedule.
    static func dueTimed(on day: Date, from tasks: [TodoTask], calendar: Calendar = .current) -> [TodoTask] {
        incomplete(from: tasks)
            .filter { task in
                guard task.scheduledStart == nil, task.dueHasTime, let due = task.dueAt else { return false }
                return calendar.isDate(due, inSameDayAs: day)
            }
            .sorted { ($0.dueAt ?? .distantPast) < ($1.dueAt ?? .distantPast) }
    }

    /// Date-only tasks due that day (no time of day) — shown with all-day events.
    static func dateOnly(on day: Date, from tasks: [TodoTask], calendar: Calendar = .current) -> [TodoTask] {
        incomplete(from: tasks)
            .filter { task in
                guard !task.dueHasTime, let due = task.dueAt else { return false }
                return calendar.isDate(due, inSameDayAs: day)
            }
            .sorted { $0.sortIndex < $1.sortIndex }
    }
}

struct TimelineBlock: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let colorHex: String
    var isCalendarEvent: Bool = false

    var durationMinutes: Int {
        Int(end.timeIntervalSince(start) / 60)
    }
}

enum TimelineLayout {
    static func blocks(from tasks: [TodoTask], on day: Date, calendar: Calendar = .current) -> [TimelineBlock] {
        let scheduled = TaskQueries.scheduled(on: day, from: tasks).compactMap { task -> TimelineBlock? in
            guard let start = task.scheduledStart else { return nil }
            return block(for: task, start: start)
        }
        // Tasks due at a time also occupy a slot, alongside calendar events.
        let dueTimed = TaskQueries.dueTimed(on: day, from: tasks, calendar: calendar).compactMap { task -> TimelineBlock? in
            guard let start = task.dueAt else { return nil }
            return block(for: task, start: start)
        }
        return merged(scheduled, dueTimed)
    }

    private static func block(for task: TodoTask, start: Date) -> TimelineBlock {
        let minutes = task.durationMinutes ?? 30
        return TimelineBlock(
            id: task.id.uuidString,
            title: task.title,
            start: start,
            end: start.addingTimeInterval(TimeInterval(minutes * 60)),
            colorHex: task.project?.colorHex ?? "3380F5"
        )
    }

    static func blocks(from events: [GoogleCalendarEvent], on day: Date, calendar: Calendar = .current) -> [TimelineBlock] {
        events
            .filter { !$0.isAllDay && calendar.isDate($0.start, inSameDayAs: day) }
            .map { event in
                TimelineBlock(
                    id: event.id,
                    title: event.title,
                    start: event.start,
                    end: event.end,
                    colorHex: event.colorHex,
                    isCalendarEvent: true
                )
            }
    }

    /// Tasks and calendar events interleaved in start order (what the
    /// timeline and gap layout both expect).
    static func merged(_ lhs: [TimelineBlock], _ rhs: [TimelineBlock]) -> [TimelineBlock] {
        (lhs + rhs).sorted { $0.start < $1.start }
    }

    /// Fraction 0...1 of day between dayStartHour and dayEndHour.
    static func fraction(of date: Date, dayStartHour: Int = 7, dayEndHour: Int = 20, calendar: Calendar = .current) -> CGFloat {
        let start = calendar.date(bySettingHour: dayStartHour, minute: 0, second: 0, of: date) ?? date
        let end = calendar.date(bySettingHour: dayEndHour, minute: 0, second: 0, of: date) ?? date
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        let offset = date.timeIntervalSince(start)
        return CGFloat(min(max(offset / total, 0), 1))
    }

    static func currentEventCaption(blocks: [TimelineBlock], now: Date = .now) -> String? {
        if let active = blocks.first(where: { now >= $0.start && now < $0.end }) {
            return "\(active.title) ends \(DateFormatting.time.string(from: active.end))"
        }
        if let next = blocks.first(where: { $0.start > now }) {
            return "\(next.title) starts \(DateFormatting.time.string(from: next.start))"
        }
        return nil
    }
}

struct ScheduleGap: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date

    var minutes: Int { Int(end.timeIntervalSince(start) / 60) }
}

enum ScheduleLayout {
    static func gaps(between blocks: [TimelineBlock], minimumMinutes: Int = 30) -> [ScheduleGap] {
        guard blocks.count >= 2 else { return [] }
        var result: [ScheduleGap] = []
        for i in 0..<(blocks.count - 1) {
            let a = blocks[i]
            let b = blocks[i + 1]
            let minutes = Int(b.start.timeIntervalSince(a.end) / 60)
            if minutes >= minimumMinutes {
                result.append(ScheduleGap(start: a.end, end: b.start))
            }
        }
        return result
    }
}
