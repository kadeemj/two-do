import EventKit
import XCTest
@testable import TwoDo

@MainActor
final class DeviceCalendarServiceTests: XCTestCase {
    func testOvernightCalendarEventAppearsOnBothDaysWithoutAllDayDuplication() {
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let event = DeviceCalendarEvent(id: "overnight", title: "Overnight", start: day.addingTimeInterval(-3600),
            end: day.addingTimeInterval(7200), isAllDay: false, colorHex: "3380F5", calendarName: "Work")
        let allDay = DeviceCalendarEvent(id: "allDay", title: "Holiday", start: day,
            end: day.addingTimeInterval(86400), isAllDay: true, colorHex: "3380F5", calendarName: "Work")
        let blocks = TimelineLayout.blocks(from: [event, allDay], on: day, calendar: calendar)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks.first?.start, day)
        XCTAssertEqual(blocks.first?.end, event.end)
        XCTAssertNil(blocks.first?.taskID)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: day)!
        XCTAssertEqual(TimelineLayout.blocks(from: [event], on: yesterday, calendar: calendar).first?.end, day)
    }

    private func withService(_ body: (DeviceCalendarService, TestCalendarStore, UserDefaults) async throws -> Void) async rethrows {
        let name = "DeviceCalendarServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = TestCalendarStore()
        let service = DeviceCalendarService(store: store, defaults: defaults)
        try await body(service, store, defaults)
    }

    func testStartupDoesNotRequestPermissionOrReadCalendars() async {
        await withService { service, store, _ in
            XCTAssertFalse(service.isConnected)
            XCTAssertEqual(store.requestCount, 0)
            XCTAssertEqual(store.calendarReadCount, 0)
            XCTAssertEqual(store.eventReadCount, 0)
        }
    }

    func testConnectionRequiresExplicitCalendarSelection() async {
        await withService { service, store, _ in
            await service.connect()
            XCTAssertTrue(service.isConnected)
            XCTAssertEqual(service.calendars.count, 2)
            XCTAssertTrue(service.events.isEmpty)
            XCTAssertEqual(store.eventReadCount, 0)
            service.setSelected(true, calendarID: "work")
            XCTAssertEqual(store.lastSelectedIDs, ["work"])
            XCTAssertEqual(service.events.map(\.title), ["Meeting"])
            service.setSelected(false, calendarID: "work")
            XCTAssertTrue(service.events.isEmpty)
            XCTAssertEqual(store.eventReadCount, 1, "An empty selection must not query all calendars")
        }
    }

    func testDisconnectClearsEventsAndPersistsAcrossLaunches() async {
        await withService { service, store, defaults in
            await service.connect()
            service.setSelected(true, calendarID: "work")
            service.disconnect()
            XCTAssertTrue(service.events.isEmpty)
            XCTAssertTrue(service.calendars.isEmpty)
            let relaunched = DeviceCalendarService(store: store, defaults: defaults)
            XCTAssertFalse(relaunched.isConnected)
            XCTAssertTrue(relaunched.events.isEmpty)
            await relaunched.connect()
            XCTAssertEqual(relaunched.selectedCalendarIDs, ["work"])
            XCTAssertEqual(relaunched.events.count, 1)
        }
    }

    func testRevokedAndWriteOnlyPermissionsClearPreviouslyVisibleEvents() async {
        await withService { service, store, _ in
            await service.connect()
            service.setSelected(true, calendarID: "work")
            for status in [EKAuthorizationStatus.denied, .restricted, .writeOnly] {
                store.authorizationStatus = .fullAccess
                service.refresh()
                XCTAssertFalse(service.events.isEmpty)
                store.authorizationStatus = status
                let reads = store.eventReadCount
                service.refresh()
                XCTAssertFalse(service.isConnected)
                XCTAssertTrue(service.events.isEmpty)
                XCTAssertTrue(service.calendars.isEmpty)
                XCTAssertEqual(store.eventReadCount, reads)
            }
        }
    }

    func testDeniedPermissionLeavesTaskOnlyMode() async {
        await withService { service, store, _ in
            store.grantsAccess = false
            await service.connect()
            XCTAssertEqual(service.authorizationStatus, .denied)
            XCTAssertFalse(service.isEnabled)
            XCTAssertFalse(service.isRequestingAccess)
            XCTAssertEqual(store.calendarReadCount, 0)
            XCTAssertEqual(store.eventReadCount, 0)
        }
    }

    func testPermissionErrorCanBeRetried() async {
        await withService { service, store, _ in
            store.failsRequest = true
            await service.connect()
            XCTAssertNotNil(service.lastError)
            XCTAssertFalse(service.isEnabled)
            XCTAssertFalse(service.isRequestingAccess)
            store.failsRequest = false
            await service.connect()
            XCTAssertNil(service.lastError)
            XCTAssertTrue(service.isConnected)
        }
    }

    func testRemovedCalendarDoesNotFallBackToAnotherCalendar() async {
        await withService { service, store, _ in
            await service.connect()
            service.setSelected(true, calendarID: "work")
            store.options.removeAll { $0.id == "work" }
            service.refresh()
            XCTAssertTrue(service.events.isEmpty)
            XCTAssertEqual(store.eventReadCount, 1)
        }
    }

    func testDayChangesUseLocalMidnightBoundaries() async {
        await withService { service, store, _ in
            await service.connect()
            service.setSelected(true, calendarID: "work")
            let day = Date(timeIntervalSince1970: 1_800_000_000)
            service.loadEvents(for: day)
            let start = Calendar.current.startOfDay(for: day)
            XCTAssertEqual(store.lastStart, start)
            XCTAssertEqual(store.lastEnd, Calendar.current.date(byAdding: .day, value: 1, to: start))
        }
    }
}

@MainActor
private final class TestCalendarStore: DeviceCalendarStore {
    var authorizationStatus: EKAuthorizationStatus = .notDetermined
    var grantsAccess = true
    var failsRequest = false
    var requestCount = 0
    var calendarReadCount = 0
    var eventReadCount = 0
    var lastSelectedIDs: Set<String> = []
    var lastStart: Date?
    var lastEnd: Date?
    var options = [
        DeviceCalendarOption(id: "work", title: "Work", source: "iCloud", colorHex: "3380F5"),
        DeviceCalendarOption(id: "personal", title: "Personal", source: "Google", colorHex: "F4511E")
    ]
    func requestAccess() async throws -> Bool {
        requestCount += 1
        if failsRequest { throw NSError(domain: "Test", code: 1) }
        authorizationStatus = grantsAccess ? .fullAccess : .denied
        return grantsAccess
    }
    func calendars() -> [DeviceCalendarOption] {
        calendarReadCount += 1
        return options
    }
    func events(from start: Date, to end: Date, calendarIDs: Set<String>) -> [DeviceCalendarEvent] {
        eventReadCount += 1
        lastSelectedIDs = calendarIDs
        lastStart = start
        lastEnd = end
        return [DeviceCalendarEvent(id: "event", title: "Meeting", start: start, end: end,
                                    isAllDay: false, colorHex: "3380F5", calendarName: "Work")]
    }
}
