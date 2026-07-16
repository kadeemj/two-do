import XCTest

/// Verifies Google Calendar events populate the Calendar tab alongside tasks,
/// using the TWODO_SMOKE_CAL hook to stand in for a live Google session.
final class CalendarEventsSmokeTests: XCTestCase {

    @MainActor
    func testGoogleEventsAppearInCalendar() throws {
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
            app.staticTexts["Design sync (Google)"].waitForExistence(timeout: 10),
            "Timed Google event should appear as a schedule block"
        )
        XCTAssertTrue(
            app.staticTexts["Launch day (Google)"].waitForExistence(timeout: 5),
            "All-day Google event should appear in the all-day row"
        )
    }
}
