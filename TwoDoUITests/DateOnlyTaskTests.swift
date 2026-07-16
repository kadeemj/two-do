import XCTest

/// Creates a task with a date-only due date (Time toggle off), verifies it
/// appears without a time, and that the setting persists when reopened.
final class DateOnlyTaskTests: XCTestCase {

    @MainActor
    func testCreateDateOnlyTask() throws {
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

        let timeToggle = app.switches["Time"]
        XCTAssertTrue(timeToggle.waitForExistence(timeout: 3), "Time toggle should appear under Due date")
        timeToggle.tap()

        app.buttons["Save"].tap()

        // Task rows collapse into one accessibility element — match by label.
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", taskTitle))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Saved task should appear in the list")

        // Reopen the editor and confirm the date-only choice persisted.
        row.tap()
        let reopenedToggle = app.switches["Time"]
        XCTAssertTrue(reopenedToggle.waitForExistence(timeout: 5), "Editor should reopen with Time toggle")
        XCTAssertEqual(
            reopenedToggle.value as? String, "0",
            "Time toggle should still be off for a date-only task"
        )
    }
}
