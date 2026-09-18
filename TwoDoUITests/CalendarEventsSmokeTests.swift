import XCTest

/// Verifies device calendar events populate the Calendar tab alongside tasks,
/// using the TWODO_SMOKE_CAL hook to stand in for a device calendar store.
final class CalendarEventsSmokeTests: XCTestCase {

    @MainActor
    func testRealCalendarPermissionCanBeDeniedAndGranted() throws {
        let app = XCUIApplication()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        app.resetAuthorizationStatus(for: .calendar)
        app.launch()
        let notifications = springboard.alerts.buttons["Allow"]
        if notifications.waitForExistence(timeout: 2) { notifications.tap() }
        app.tabBars.buttons["Settings"].tap()
        app.buttons["Connect Calendars"].tap()
        let deny = springboard.alerts.buttons["Don’t Allow"]
        XCTAssertTrue(deny.waitForExistence(timeout: 5))
        deny.tap()
        XCTAssertTrue(app.buttons["Open Calendar Permissions"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Tasks"].tap()
        XCTAssertTrue(app.textFields["Quickly add a task"].exists)

        app.terminate()
        app.resetAuthorizationStatus(for: .calendar)
        app.launch()
        app.tabBars.buttons["Settings"].tap()
        app.buttons["Connect Calendars"].tap()
        let allow = springboard.alerts.buttons["Allow Full Access"]
        XCTAssertTrue(allow.waitForExistence(timeout: 5))
        allow.tap()
        XCTAssertTrue(app.buttons["Choose Calendars"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Device Calendar Settings"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["Choose Calendars"].tap()
        XCTAssertTrue(app.navigationBars["Choose Calendars"].exists)
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["Disconnect Calendars"].tap()
    }

    @MainActor
    func testDeviceEventsAppearInCalendar() throws {
        let app = XCUIApplication()
        app.launchEnvironment["TWODO_SMOKE_CAL"] = "1"
        app.launch()

        // Fresh installs show the notification permission alert first.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons["Allow"]
        if allow.waitForExistence(timeout: 3) {
            allow.tap()
        }

        app.tabBars.buttons["Calendar"].tap()

        XCTAssertTrue(
            app.staticTexts["Design sync (Calendar)"].waitForExistence(timeout: 10),
            "Timed device calendar event should appear as a schedule block"
        )
        XCTAssertTrue(
            app.staticTexts["Launch day (Calendar)"].waitForExistence(timeout: 5),
            "All-day device calendar event should appear in the all-day row"
        )

        app.tabBars.buttons["Settings"].tap()
        XCTAssertFalse(app.staticTexts["Container"].exists)
        XCTAssertFalse(app.staticTexts["iCloud.com.kadeem.twodo"].exists)
        XCTAssertFalse(app.buttons["Sign in with Google Calendar"].exists)
        app.buttons["Choose Calendars"].tap()
        let calendarToggle = app.switches["calendar-selection-smoke"].firstMatch
        XCTAssertTrue(calendarToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(calendarToggle.value as? String, "1")
        calendarToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(calendarToggle.value as? String, "0")
        app.tabBars.buttons["Calendar"].tap()
        XCTAssertFalse(app.staticTexts["Launch day (Calendar)"].exists)
        XCTAssertFalse(app.staticTexts["Design sync (Calendar)"].exists)

        app.tabBars.buttons["Settings"].tap()
        calendarToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(calendarToggle.value as? String, "1")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["Disconnect Calendars"].tap()
        app.tabBars.buttons["Calendar"].tap()
        XCTAssertFalse(app.staticTexts["Launch day (Calendar)"].exists)
        app.tabBars.buttons["Settings"].tap()
        app.buttons["Connect Calendars"].tap()
        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.staticTexts["Launch day (Calendar)"].waitForExistence(timeout: 5))
    }
}
