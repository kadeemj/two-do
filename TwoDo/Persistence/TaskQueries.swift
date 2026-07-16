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
}

struct TimelineBlock: Identifiable {
    let id: UUID
    let title: String
    let start: Date
    let end: Date
    let colorHex: String

    var durationMinutes: Int {
        Int(end.timeIntervalSince(start) / 60)
    }
}

enum TimelineLayout {
    static func blocks(from tasks: [TodoTask], on day: Date, calendar: Calendar = .current) -> [TimelineBlock] {
        TaskQueries.scheduled(on: day, from: tasks).compactMap { task in
            guard let start = task.scheduledStart else { return nil }
            let minutes = task.durationMinutes ?? 30
            let end = start.addingTimeInterval(TimeInterval(minutes * 60))
            return TimelineBlock(
                id: task.id,
                title: task.title,
                start: start,
                end: end,
                colorHex: task.project?.colorHex ?? "3380F5"
            )
        }
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
