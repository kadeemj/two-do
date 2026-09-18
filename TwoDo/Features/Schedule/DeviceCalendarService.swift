import EventKit
import Observation
import UIKit

struct DeviceCalendarEvent: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let colorHex: String
    let calendarName: String
}

struct DeviceCalendarOption: Identifiable {
    let id: String
    let title: String
    let source: String
    let colorHex: String
}

/// The app deliberately exposes no calendar-writing operation.
@MainActor
protocol DeviceCalendarStore {
    var authorizationStatus: EKAuthorizationStatus { get }
    func requestAccess() async throws -> Bool
    func calendars() -> [DeviceCalendarOption]
    func events(from start: Date, to end: Date, calendarIDs: Set<String>) -> [DeviceCalendarEvent]
}

@MainActor
final class EventKitCalendarStore: DeviceCalendarStore {
    private let store = EKEventStore()

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    func requestAccess() async throws -> Bool {
        try await store.requestFullAccessToEvents()
    }

    func calendars() -> [DeviceCalendarOption] {
        store.calendars(for: .event).map {
            DeviceCalendarOption(id: $0.calendarIdentifier, title: $0.title,
                                 source: $0.source.title, colorHex: Self.hex($0.cgColor))
        }.sorted {
            ($0.source + $0.title).localizedStandardCompare($1.source + $1.title) == .orderedAscending
        }
    }

    func events(from start: Date, to end: Date, calendarIDs: Set<String>) -> [DeviceCalendarEvent] {
        let calendars = store.calendars(for: .event).filter { calendarIDs.contains($0.calendarIdentifier) }
        // EventKit treats nil calendars as all calendars; an empty selection must read none.
        guard !calendars.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return store.events(matching: predicate).compactMap { event in
            guard event.status != .canceled,
                  let calendar = event.calendar,
                  let start = event.startDate, let end = event.endDate else { return nil }
            // Recurring occurrences share identifiers, so include their start time.
            let id = "\(calendar.calendarIdentifier)/\(event.calendarItemIdentifier)/\(start.timeIntervalSinceReferenceDate)"
            return DeviceCalendarEvent(id: id, title: event.title ?? "(No title)", start: start, end: end,
                                       isAllDay: event.isAllDay, colorHex: Self.hex(calendar.cgColor),
                                       calendarName: calendar.title)
        }.sorted { $0.start < $1.start }
    }

    private static func hex(_ color: CGColor?) -> String {
        guard let color else { return "3380F5" }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(cgColor: color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return "3380F5"
        }
        return String(format: "%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }
}

@MainActor
@Observable
final class DeviceCalendarService {
    private let store: any DeviceCalendarStore
    private let defaults: UserDefaults
    private var day: Date = .now
    private(set) var isEnabled: Bool
    private(set) var selectedCalendarIDs: Set<String>
    private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    private(set) var calendars: [DeviceCalendarOption] = []
    private(set) var events: [DeviceCalendarEvent] = []
    private(set) var isRequestingAccess = false
    private(set) var lastError: String?

    var hasFullAccess: Bool { authorizationStatus == .fullAccess }
    var isConnected: Bool { isEnabled && hasFullAccess }
    var allDayEvents: [DeviceCalendarEvent] { events.filter(\.isAllDay) }
    var timedEvents: [DeviceCalendarEvent] { events.filter { !$0.isAllDay } }

    init(store: any DeviceCalendarStore, defaults: UserDefaults) {
        self.store = store
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: "deviceCalendars.enabled")
        selectedCalendarIDs = Set(defaults.stringArray(forKey: "deviceCalendars.selectedIDs") ?? [])
        refresh()
    }

    convenience init() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["TWODO_SMOKE_CAL"] == "1" {
            let defaults = UserDefaults(suiteName: "DeviceCalendarSmoke.\(UUID().uuidString)")!
            defaults.set(true, forKey: "deviceCalendars.enabled")
            defaults.set(["smoke"], forKey: "deviceCalendars.selectedIDs")
            self.init(store: SmokeCalendarStore(), defaults: defaults)
            return
        }
        #endif
        self.init(store: EventKitCalendarStore(), defaults: .standard)
    }

    func connect() async {
        guard !isRequestingAccess else { return }
        isRequestingAccess = true
        lastError = nil
        defer { isRequestingAccess = false }
        do {
            let granted = store.authorizationStatus == .fullAccess
                ? true : try await store.requestAccess()
            isEnabled = granted
            defaults.set(granted, forKey: "deviceCalendars.enabled")
        } catch {
            isEnabled = false
            defaults.set(false, forKey: "deviceCalendars.enabled")
            lastError = "Calendar access could not be requested. Please try again."
        }
        refresh()
    }

    func disconnect() {
        isEnabled = false
        defaults.set(false, forKey: "deviceCalendars.enabled")
        events = []
        calendars = []
        lastError = nil
    }

    func setSelected(_ selected: Bool, calendarID: String) {
        if selected { selectedCalendarIDs.insert(calendarID) }
        else { selectedCalendarIDs.remove(calendarID) }
        defaults.set(selectedCalendarIDs.sorted(), forKey: "deviceCalendars.selectedIDs")
        refresh()
    }

    func loadEvents(for day: Date) {
        self.day = day
        refresh()
    }

    /// Called on foreground, EventKit changes, and calendar selection changes.
    func refresh() {
        authorizationStatus = store.authorizationStatus
        guard isConnected else {
            calendars = []
            events = []
            return
        }
        calendars = store.calendars()
        let selected = selectedCalendarIDs.intersection(Set(calendars.map(\.id)))
        guard !selected.isEmpty else {
            events = []
            return
        }
        let start = Calendar.current.startOfDay(for: day)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else {
            events = []
            return
        }
        events = store.events(from: start, to: end, calendarIDs: selected)
    }
}

#if DEBUG
@MainActor
private final class SmokeCalendarStore: DeviceCalendarStore {
    var authorizationStatus: EKAuthorizationStatus { .fullAccess }
    func requestAccess() async throws -> Bool { true }
    func calendars() -> [DeviceCalendarOption] {
        [DeviceCalendarOption(id: "smoke", title: "Demo Calendar", source: "On My iPhone", colorHex: "F4511E")]
    }
    func events(from start: Date, to end: Date, calendarIDs: Set<String>) -> [DeviceCalendarEvent] {
        guard calendarIDs.contains("smoke") else { return [] }
        let ten = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: start)!
        return [
            DeviceCalendarEvent(id: "smoke/timed", title: "Design sync (Calendar)", start: ten,
                                end: ten.addingTimeInterval(3600), isAllDay: false,
                                colorHex: "F4511E", calendarName: "Demo Calendar"),
            DeviceCalendarEvent(id: "smoke/allday", title: "Launch day (Calendar)", start: start,
                                end: end, isAllDay: true, colorHex: "F4511E", calendarName: "Demo Calendar")
        ]
    }
}
#endif
