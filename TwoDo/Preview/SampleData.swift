import Foundation
import SwiftData

enum SampleData {
    static let seededKey = "hasSeededDemoData"

    static func seedIfNeeded(in context: ModelContext, force: Bool = false) {
        if !force {
            let already = UserDefaults.standard.bool(forKey: seededKey)
            if already { return }

            var descriptor = FetchDescriptor<TodoTask>()
            descriptor.fetchLimit = 1
            if let count = try? context.fetch(descriptor), !count.isEmpty {
                UserDefaults.standard.set(true, forKey: seededKey)
                return
            }
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let dayStart = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: today) ?? today

        func at(hour: Int, minute: Int, on day: Date = today) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        func daysAgo(_ n: Int) -> Date {
            calendar.date(byAdding: .day, value: -n, to: today) ?? today
        }

        let work = Project(name: "Work", colorHex: "F58C38", sortIndex: 0)
        let personal = Project(name: "Personal", colorHex: "598FE8", sortIndex: 1)
        let deepWork = Project(name: "Deep Work", colorHex: "8BC85A", sortIndex: 2)
        let home = Project(name: "Home", colorHex: "9E7AE6", sortIndex: 3)
        let errands = Project(name: "Errands", colorHex: "F2C73F", sortIndex: 4)

        [work, personal, deepWork, home, errands].forEach { context.insert($0) }

        // Scheduled today
        let callJeremy = TodoTask(
            title: "Call with Jeremy",
            dueAt: at(hour: 10, minute: 30),
            scheduledStart: at(hour: 10, minute: 0),
            durationMinutes: 30,
            sortIndex: 0,
            hasPhone: true,
            project: personal
        )

        let budget = TodoTask(
            title: "Submit Q2 budget notes",
            dueAt: at(hour: 7, minute: 0),
            scheduledStart: at(hour: 9, minute: 0),
            durationMinutes: 60,
            sortIndex: 1,
            isFlagged: true,
            project: work
        )

        let grocery = TodoTask(
            title: "Grocery run",
            dueAt: at(hour: 12, minute: 0),
            scheduledStart: at(hour: 11, minute: 30),
            durationMinutes: 45,
            sortIndex: 2,
            hasLocation: true,
            locationName: "Market",
            project: errands
        )

        let deepFocus = TodoTask(
            title: "Deep work: roadmap",
            dueAt: at(hour: 15, minute: 0),
            scheduledStart: at(hour: 13, minute: 0),
            durationMinutes: 120,
            sortIndex: 3,
            isFlagged: true,
            project: deepWork
        )

        let designReview = TodoTask(
            title: "Design review sync",
            dueAt: at(hour: 16, minute: 30),
            scheduledStart: at(hour: 16, minute: 0),
            durationMinutes: 30,
            sortIndex: 4,
            project: work
        )

        let wrap = TodoTask(
            title: "Ship release notes",
            dueAt: at(hour: 18, minute: 0),
            scheduledStart: nil,
            durationMinutes: 30,
            sortIndex: 5,
            project: work
        )

        // Overdue
        let overdue1 = TodoTask(
            title: "Reply to vendor quote",
            dueAt: daysAgo(4).addingTimeInterval(10 * 3600),
            durationMinutes: 30,
            sortIndex: 10,
            hasPhone: true,
            isFlagged: true,
            project: work
        )

        let overdue2 = TodoTask(
            title: "Call Alex",
            dueAt: daysAgo(1).addingTimeInterval(14 * 3600),
            durationMinutes: 20,
            sortIndex: 11,
            hasPhone: true,
            project: personal
        )

        let launchVideo = TodoTask(
            title: "Product launch video",
            dueAt: daysAgo(1),
            durationMinutes: 60,
            sortIndex: 0,
            project: work,
            parent: overdue2
        )

        let overdue3 = TodoTask(
            title: "Book dentist",
            dueAt: daysAgo(2).addingTimeInterval(9 * 3600),
            durationMinutes: 15,
            sortIndex: 12,
            hasLocation: true,
            locationName: "Clinic",
            project: home
        )

        let all = [callJeremy, budget, grocery, deepFocus, designReview, wrap, overdue1, overdue2, launchVideo, overdue3]
        all.forEach { context.insert($0) }

        try? context.save()
        UserDefaults.standard.set(true, forKey: seededKey)
        _ = dayStart
    }
}
