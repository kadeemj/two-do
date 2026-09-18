import XCTest
import Testing
import SwiftData
@testable import TwoDo

final class WidgetTaskTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testSnapshotStoreRoundTripsEnvelope() throws {
        let suiteName = "WidgetTaskTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let envelope = WidgetSnapshotEnvelope(generatedAt: date(hour: 9), tasks: [task(id: 1)])

        XCTAssertTrue(WidgetSnapshotStore.save(envelope, defaults: defaults))
        XCTAssertEqual(WidgetSnapshotStore.load(defaults: defaults), envelope)
    }

    func testFocusPrefersActiveThenNextScheduled() {
        let now = date(hour: 10)
        let active = task(id: 1, dueAt: date(), start: date(hour: 9, minute: 30), end: date(hour: 10, minute: 30))
        let next = task(id: 2, dueAt: date(), start: date(hour: 11), end: date(hour: 12))
        let overdue = task(id: 3, dueAt: date(day: 17))

        XCTAssertEqual(WidgetTaskSelection.focus(from: [overdue, next, active], now: now)?.id, active.id)
        XCTAssertEqual(WidgetTaskSelection.focus(from: [overdue, next], now: now)?.id, next.id)
    }

    func testFocusFallsBackThroughOverdueTodayFutureAndUndated() {
        let now = date(hour: 10)
        let overdue = task(id: 1, dueAt: date(day: 17))
        let today = task(id: 2, dueAt: date())
        let future = task(id: 3, dueAt: date(day: 19))
        let undated = task(id: 4)

        XCTAssertEqual(WidgetTaskSelection.focus(from: [undated, future, today, overdue], now: now)?.id, overdue.id)
        XCTAssertEqual(WidgetTaskSelection.focus(from: [undated, future, today], now: now)?.id, today.id)
        XCTAssertEqual(WidgetTaskSelection.focus(from: [undated, future], now: now)?.id, future.id)
        XCTAssertEqual(WidgetTaskSelection.focus(from: [undated], now: now)?.id, undated.id)
    }

    func testTodayIncludesOverdueAndDeduplicatesScheduledDueTask() {
        let now = date(hour: 10)
        let overdue = task(id: 1, dueAt: date(day: 17))
        let scheduledAndDue = task(id: 2, dueAt: date(), start: date(hour: 11), end: date(hour: 12))
        let result = WidgetTaskSelection.today(from: [scheduledAndDue, overdue], now: now)

        XCTAssertEqual(result.map(\.id), [overdue.id, scheduledAndDue.id])
        XCTAssertEqual(Set(result.map(\.id)).count, result.count)
    }

    func testUpcomingSortsByScheduledTimeThenDueDate() {
        let now = date(hour: 10)
        let laterToday = task(id: 1, dueAt: date(day: 20), start: date(hour: 12), end: date(hour: 13))
        let tomorrow = task(id: 2, dueAt: date(day: 19))
        let later = task(id: 3, dueAt: date(day: 22))

        XCTAssertEqual(
            WidgetTaskSelection.upcoming(from: [later, tomorrow, laterToday], now: now).map(\.id),
            [laterToday.id, tomorrow.id, later.id]
        )
    }

    func testScheduledEndUsesTaskDuration() {
        let model = TodoTask(title: "Timed", scheduledStart: date(hour: 10), durationMinutes: 45)
        XCTAssertEqual(model.scheduledEnd, date(hour: 10, minute: 45))
    }

    func testTransitionDatesContainStartEndAndMidnight() {
        let now = date(hour: 10)
        let scheduled = task(id: 1, start: date(hour: 11), end: date(hour: 12))
        let transitions = WidgetTaskSelection.transitionDates(from: [scheduled], now: now, calendar: calendar)

        XCTAssertTrue(transitions.contains(date(hour: 11)))
        XCTAssertTrue(transitions.contains(date(hour: 12)))
        XCTAssertTrue(transitions.contains(date(day: 19, hour: 0)))
    }

    func testDeepLinksParseAndRejectUnknownURLs() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000123")!
        XCTAssertEqual(TwoDoDeepLink(url: WidgetConstants.taskURL(id: id)), .task(id))
        XCTAssertEqual(TwoDoDeepLink(url: WidgetConstants.todayURL), .today)
        XCTAssertEqual(TwoDoDeepLink(url: WidgetConstants.createTaskURL), .createTask)
        XCTAssertNil(TwoDoDeepLink(url: URL(string: "https://example.com/task/\(id)")!))
        XCTAssertNil(TwoDoDeepLink(url: URL(string: "twodo://task/not-a-uuid")!))
    }

    @MainActor
    func testCreateTaskDeepLinkRoutesToComposer() {
        let router = AppRouter()
        router.selectedTab = .settings
        router.requestedTaskID = UUID()

        XCTAssertTrue(router.handle(url: WidgetConstants.createTaskURL))
        XCTAssertEqual(router.selectedTab, .today)
        XCTAssertNil(router.requestedTaskID)
        XCTAssertTrue(router.requestedCreateTask)
    }

    private func date(day: Int = 18, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    private func task(
        id: Int,
        dueAt: Date? = nil,
        start: Date? = nil,
        end: Date? = nil,
        sortIndex: Double = 0
    ) -> WidgetTaskSnapshot {
        WidgetTaskSnapshot(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!,
            title: "Task \(id)",
            dueAt: dueAt,
            scheduledStart: start,
            scheduledEnd: end,
            projectName: "Project",
            projectColorHex: "3380F5",
            isFlagged: false,
            sortIndex: sortIndex
        )
    }
}

@Suite("Recurring tasks")
struct RecurringTaskTests {
    @Test("Weekday recurrence skips weekends")
    func weekdayRecurrenceSkipsWeekend() throws {
        let calendar = makeCalendar()
        let rule = TaskRecurrence(kind: .weekdays)
        let friday = date(year: 2026, month: 7, day: 17, calendar: calendar)
        let monday = date(year: 2026, month: 7, day: 20, calendar: calendar)

        let next = try #require(rule.nextDate(after: friday, calendar: calendar))
        #expect(next == monday)
    }

    @Test("Missed occurrences advance to the next future date")
    func missedOccurrencesAreSkipped() throws {
        let calendar = makeCalendar()
        let rule = TaskRecurrence(kind: .daily)
        let oldDueDate = date(year: 2026, month: 7, day: 14, calendar: calendar)
        let completionDate = date(year: 2026, month: 7, day: 18, hour: 10, calendar: calendar)
        let expected = date(year: 2026, month: 7, day: 19, calendar: calendar)

        let next = try #require(rule.nextEligibleDate(
            after: oldDueDate,
            laterThan: completionDate,
            dateOnly: true,
            calendar: calendar
        ))
        #expect(next == expected)
    }

    @Test("Custom recurrence respects its interval and unit")
    func customRecurrenceUsesInterval() throws {
        let calendar = makeCalendar()
        let rule = TaskRecurrence(kind: .custom, interval: 2, unit: .week)
        let start = date(year: 2026, month: 7, day: 6, calendar: calendar)
        let expected = date(year: 2026, month: 7, day: 20, calendar: calendar)

        let next = try #require(rule.nextDate(after: start, calendar: calendar))
        #expect(next == expected)
        #expect(rule.displayName == "Every 2 weeks")
    }

    @Test("Completing an occurrence creates only one successor")
    @MainActor
    func completionCreatesOneSuccessor() throws {
        let calendar = makeCalendar()
        let schema = Schema([TodoTask.self, Project.self, Tag.self])
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let now = date(year: 2026, month: 7, day: 18, hour: 10, calendar: calendar)
        let original = TodoTask(
            title: "Plan tomorrow",
            dueAt: date(year: 2026, month: 7, day: 18, calendar: calendar),
            durationMinutes: 30
        )
        original.recurrence = TaskRecurrence(kind: .daily)
        original.reminderOptions = [.eveningBefore, .morningOf]
        original.remindersEnabled = true
        context.insert(original)
        try context.save()

        let generated = try TaskCompletion.toggle(
            original,
            in: context,
            now: now,
            calendar: calendar
        )
        let successor = try #require(generated)

        #expect(original.isCompleted)
        #expect(successor.title == original.title)
        #expect(successor.dueAt == date(year: 2026, month: 7, day: 19, calendar: calendar))
        #expect(successor.recurrence == original.recurrence)
        #expect(successor.recurrenceSeriesID == original.recurrenceSeriesID)
        #expect(successor.remindersEnabled == original.remindersEnabled)
        #expect(successor.reminderOptions == original.reminderOptions)

        _ = try TaskCompletion.toggle(original, in: context, now: now, calendar: calendar)
        let duplicate = try TaskCompletion.toggle(original, in: context, now: now, calendar: calendar)
        let storedTasks = try context.fetch(FetchDescriptor<TodoTask>())

        #expect(duplicate == nil)
        #expect(storedTasks.count == 2)
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        calendar: Calendar
    ) -> Date {
        guard let value = calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        )) else {
            fatalError("Invalid test date")
        }
        return value
    }
}

@Suite("Task reminders")
struct TaskReminderTests {
    @Test("Due-date reminders fire at 9 AM")
    func morningOfDueDate() throws {
        let calendar = makeCalendar()
        let dueAt = date(day: 18, calendar: calendar)
        let task = TodoTask(title: "Submit report", dueAt: dueAt)
        task.reminderOptions = [.morningOf]

        let occurrences = TaskReminderPlan.occurrences(
            for: task,
            now: date(day: 17, hour: 12, calendar: calendar),
            calendar: calendar
        )

        let reminder = try #require(occurrences.first)
        #expect(occurrences.count == 1)
        #expect(reminder.option == .morningOf)
        #expect(reminder.fireAt == date(day: 18, hour: 9, calendar: calendar))
        #expect(reminder.body == "Due today")
    }

    @Test("A time block supports multiple reminder offsets")
    func multipleTimeBlockReminders() {
        let calendar = makeCalendar()
        let start = date(day: 18, hour: 14, calendar: calendar)
        let task = TodoTask(title: "Design review", scheduledStart: start)
        task.reminderOptions = [.oneHourBefore, .thirtyMinutesBefore, .tenMinutesBefore, .atStart]

        let occurrences = TaskReminderPlan.occurrences(
            for: task,
            now: date(day: 18, hour: 8, calendar: calendar),
            calendar: calendar
        )

        #expect(occurrences.map(\.fireAt) == [
            date(day: 18, hour: 13, calendar: calendar),
            date(day: 18, hour: 13, minute: 30, calendar: calendar),
            date(day: 18, hour: 13, minute: 50, calendar: calendar),
            start
        ])
    }

    @Test("Rules that resolve to the same time produce one notification")
    func duplicateTimesAreDeduplicated() {
        let calendar = makeCalendar()
        let start = date(day: 18, hour: 9, calendar: calendar)
        let task = TodoTask(title: "Stand-up", dueAt: start, scheduledStart: start)
        task.reminderOptions = [.morningOf, .atStart]

        let occurrences = TaskReminderPlan.occurrences(
            for: task,
            now: date(day: 17, hour: 12, calendar: calendar),
            calendar: calendar
        )

        #expect(occurrences.count == 1)
        #expect(occurrences.first?.fireAt == start)
    }

    @Test("Disabled reminders produce no notifications")
    func disabledReminders() {
        let calendar = makeCalendar()
        let task = TodoTask(
            title: "Quiet task",
            dueAt: date(day: 18, calendar: calendar)
        )
        task.remindersEnabled = false
        task.reminderOptions = [.morningOf]

        let occurrences = TaskReminderPlan.occurrences(
            for: task,
            now: date(day: 17, calendar: calendar),
            calendar: calendar
        )

        #expect(occurrences.isEmpty)
    }

    @Test("Time-relative rules require a time block")
    func availableOptionsMatchTaskTiming() {
        let dueOnly = TaskReminderPlan.availableOptions(hasDue: true, hasSchedule: false)
        let scheduled = TaskReminderPlan.availableOptions(hasDue: false, hasSchedule: true)

        #expect(dueOnly == [.eveningBefore, .morningOf])
        #expect(scheduled.contains(.atStart))
        #expect(scheduled.contains(.tenMinutesBefore))
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        calendar: Calendar
    ) -> Date {
        guard let value = calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: day,
            hour: hour,
            minute: minute
        )) else {
            fatalError("Invalid test date")
        }
        return value
    }
}

@Suite("Smart lists and search")
struct TaskDiscoveryTests {
    @Test("Smart lists select their expected tasks")
    func smartLists() {
        let calendar = makeCalendar()
        let now = date(day: 18, hour: 12, calendar: calendar)
        let today = TodoTask(title: "Today", dueAt: date(day: 18, calendar: calendar))
        let future = TodoTask(title: "Future", dueAt: date(day: 20, calendar: calendar))
        let flagged = TodoTask(title: "Flagged", isFlagged: true)
        let completed = TodoTask(
            title: "Completed",
            isCompleted: true,
            completedAt: date(day: 17, calendar: calendar)
        )
        let tasks = [today, future, flagged, completed]

        #expect(TaskSmartList.all.tasks(from: tasks, now: now, calendar: calendar).count == 3)
        #expect(TaskSmartList.today.tasks(from: tasks, now: now, calendar: calendar).map(\.title) == ["Today"])
        #expect(TaskSmartList.upcoming.tasks(from: tasks, now: now, calendar: calendar).map(\.title) == ["Future"])
        #expect(TaskSmartList.flagged.tasks(from: tasks, now: now, calendar: calendar).map(\.title) == ["Flagged"])
        #expect(TaskSmartList.completed.tasks(from: tasks, now: now, calendar: calendar).map(\.title) == ["Completed"])
        #expect(TaskSmartList.noDate.tasks(from: tasks, now: now, calendar: calendar).map(\.title) == ["Flagged"])
    }

    @Test("Search scopes inspect the appropriate fields")
    func searchScopes() {
        let project = Project(name: "Launch", colorHex: "3380F5")
        let task = TodoTask(title: "Write announcement", notes: "Mention accessibility", project: project)
        let other = TodoTask(title: "Book room", notes: "Launch logistics")
        let tasks = [task, other]

        #expect(TaskSearch.results(in: tasks, query: "launch", scope: .everything).count == 2)
        #expect(TaskSearch.results(in: tasks, query: "launch", scope: .titles).isEmpty)
        #expect(TaskSearch.results(in: tasks, query: "accessibility", scope: .notes).map(\.title) == ["Write announcement"])
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(
        day: Int,
        hour: Int = 0,
        calendar: Calendar
    ) -> Date {
        guard let value = calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: day,
            hour: hour
        )) else {
            fatalError("Invalid test date")
        }
        return value
    }
}

@Suite("Quick capture")
struct TaskCaptureTests {
    @Test("Capture trims text, normalizes due dates, and appends ordering")
    @MainActor
    func createsTask() throws {
        let schema = Schema([TodoTask.self, Project.self, Tag.self])
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        context.insert(TodoTask(title: "Existing", sortIndex: 4))
        try context.save()

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let dueAt = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 18,
            hour: 16
        )))

        let captured = try TaskCapture.create(
            title: "  Follow up  ",
            notes: "  Bring notes  ",
            dueAt: dueAt,
            isFlagged: true,
            in: context,
            calendar: calendar
        )

        #expect(captured.title == "Follow up")
        #expect(captured.notes == "Bring notes")
        #expect(captured.dueAt == calendar.startOfDay(for: dueAt))
        #expect(captured.isFlagged)
        #expect(captured.sortIndex == 5)
        #expect(try context.fetch(FetchDescriptor<TodoTask>()).count == 2)
    }
}
