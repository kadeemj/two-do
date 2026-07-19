import XCTest
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
