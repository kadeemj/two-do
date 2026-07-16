import XCTest

/// End-to-end check that task notifications work: grants the permission
/// prompt, lets the app seed a task due in ~60s (TWODO_SMOKE_TEST hook),
/// backgrounds the app, and waits for the banner to arrive.
final class NotificationSmokeTests: XCTestCase {

    @MainActor
    func testTaskNotificationFires() throws {
        let app = XCUIApplication()
        app.launchEnvironment["TWODO_SMOKE_TEST"] = "1"
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) {
            allow.tap()
        }

        // Give the app time to seed the smoke-test task and resync
        // its pending notifications (resync is debounced by 500ms).
        sleep(5)
        XCUIDevice.shared.press(.home)

        // The seeded task fires ~60s after launch.
        let banner = springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'Smoke test'"))
            .firstMatch
        XCTAssertTrue(
            banner.waitForExistence(timeout: 90),
            "Expected the seeded task's notification banner to appear"
        )
    }
}
