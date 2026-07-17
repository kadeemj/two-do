import XCTest

/// Due dates are date-only: the editor offers no Time toggle, and a saved
/// task shows a plain date label with no time of day.
final class DateOnlyTaskTests: XCTestCase {

    @MainActor
    func testCreateTaskWithDueDateIsDateOnly() throws {
        let app = XCUIApplication()
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons["Allow"]
        if allow.waitForExistence(timeout: 3) {
            allow.tap()
        }

        let addButton = app.buttons["plus"].exists ? app.buttons["plus"] : app.buttons["Add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add-task button should exist")
        addButton.tap()

        // Unique title so reruns don't collide with earlier saved tasks.
        let taskTitle = "Errand \(Int(Date().timeIntervalSince1970) % 100_000)"
        let title = app.textFields["Title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText(taskTitle)

        // The due-date editor offers no time-of-day controls; the separate
        // Time block toggle is still there.
        XCTAssertTrue(app.switches["Time block"].waitForExistence(timeout: 3), "Time block toggle should exist")
        XCTAssertFalse(app.switches["Time"].exists, "Time toggle should be gone — due dates are date-only")

        app.buttons["Save"].tap()

        // The row's title is its own accessibility element — match by label.
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", taskTitle))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Saved task should appear in the list")

        // Timed dues used to render as "Today, 10:30 AM"; date-only dues
        // render as plain "Today", so no label anywhere carries a time.
        let timedDueLabels = app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Today,"))
        XCTAssertEqual(timedDueLabels.count, 0, "No due label should carry a time of day")

        // Reopening a task lands on the read-only view; Edit opens the form.
        row.tap()
        let editButton = app.buttons["Edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "Task should open in a read-only view with an Edit button")
        editButton.tap()
        let dueToggle = app.switches["Due date"]
        XCTAssertTrue(dueToggle.waitForExistence(timeout: 5), "Editor should reopen with Due date toggle")
        XCTAssertEqual(dueToggle.value as? String, "1", "Due date should still be on")
        XCTAssertFalse(app.switches["Time"].exists, "Time toggle should not reappear in edit mode")
    }
}

