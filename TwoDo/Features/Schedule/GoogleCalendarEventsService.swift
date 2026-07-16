import Foundation
import Observation

struct GoogleCalendarEvent: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let colorHex: String
    let calendarName: String
}

/// Fetches the connected Google account's events for the schedule.
///
/// Reads the tokens written by `GoogleCalendarAuthService`, refreshing the
/// access token when expired, and pulls events from every calendar the user
/// has visible (falling back to the primary calendar).
@MainActor
@Observable
final class GoogleCalendarEventsService {
    private(set) var events: [GoogleCalendarEvent] = []
    private(set) var isLoading = false
    private(set) var lastError: String?

    var isConnected: Bool {
        KeychainStore.string(forKey: GoogleCalendarKeys.refreshToken) != nil
            || KeychainStore.string(forKey: GoogleCalendarKeys.accessToken) != nil
    }

    var allDayEvents: [GoogleCalendarEvent] { events.filter(\.isAllDay) }
    var timedEvents: [GoogleCalendarEvent] { events.filter { !$0.isAllDay } }

    func loadEvents(for day: Date = .now) async {
        #if DEBUG
        // UI-test hook: fake a connected account so the smoke test can verify
        // Google events render in the schedule without a live OAuth session.
        if ProcessInfo.processInfo.environment["TWODO_SMOKE_CAL"] == "1" {
            let calendar = Calendar.current
            let ten = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day) ?? day
            events = [
                GoogleCalendarEvent(
                    id: "smoke/timed",
                    title: "Design sync (Google)",
                    start: ten,
                    end: ten.addingTimeInterval(3600),
                    isAllDay: false,
                    colorHex: "F4511E",
                    calendarName: "Smoke"
                ),
                GoogleCalendarEvent(
                    id: "smoke/allday",
                    title: "Launch day (Google)",
                    start: calendar.startOfDay(for: day),
                    end: calendar.startOfDay(for: day).addingTimeInterval(86_400),
                    isAllDay: true,
                    colorHex: "F4511E",
                    calendarName: "Smoke"
                )
            ]
            return
        }
        #endif

        guard isConnected else {
            events = []
            return
        }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let token = try await validAccessToken()
            let calendars = try await fetchCalendarList(token: token)
            let day = Calendar.current.startOfDay(for: day)

            let fetched = try await withThrowingTaskGroup(of: [GoogleCalendarEvent].self) { group in
                for calendarInfo in calendars {
                    group.addTask {
                        try await Self.fetchEvents(from: calendarInfo, on: day, token: token)
                    }
                }
                var all: [GoogleCalendarEvent] = []
                for try await chunk in group {
                    all.append(contentsOf: chunk)
                }
                return all
            }

            events = fetched.sorted { $0.start < $1.start }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Token

    private func validAccessToken() async throws -> String {
        if let access = KeychainStore.string(forKey: GoogleCalendarKeys.accessToken),
           let expiryString = KeychainStore.string(forKey: GoogleCalendarKeys.expiry),
           let expiry = Double(expiryString),
           Date(timeIntervalSince1970: expiry) > Date.now.addingTimeInterval(120) {
            return access
        }

        guard let refresh = KeychainStore.string(forKey: GoogleCalendarKeys.refreshToken) else {
            // No refresh token — use the access token we have and let the
            // API surface an auth error if it has expired.
            if let access = KeychainStore.string(forKey: GoogleCalendarKeys.accessToken) {
                return access
            }
            throw EventsError.notConnected
        }

        var request = URLRequest(url: GoogleCalendarConfig.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "client_id": GoogleCalendarConfig.clientID,
            "grant_type": "refresh_token",
            "refresh_token": refresh
        ]
        request.httpBody = body
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw EventsError.server("Could not refresh Google Calendar access")
        }
        let refreshed = try JSONDecoder().decode(RefreshResponse.self, from: data)
        KeychainStore.set(refreshed.access_token, forKey: GoogleCalendarKeys.accessToken)
        if let expiresIn = refreshed.expires_in {
            let expiry = Date().addingTimeInterval(TimeInterval(expiresIn)).timeIntervalSince1970
            KeychainStore.set(String(expiry), forKey: GoogleCalendarKeys.expiry)
        }
        return refreshed.access_token
    }

    // MARK: - Calendar API

    private struct CalendarInfo: Decodable {
        let id: String
        let summary: String?
        let backgroundColor: String?
        let selected: Bool?
        let primary: Bool?
    }

    private func fetchCalendarList(token: String) async throws -> [CalendarInfo] {
        let url = URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList?maxResults=100")!
        let data = try await Self.get(url, token: token)

        struct CalendarListResponse: Decodable {
            let items: [CalendarInfo]?
        }
        let list = try JSONDecoder().decode(CalendarListResponse.self, from: data)
        let visible = (list.items ?? []).filter { ($0.selected ?? false) || ($0.primary ?? false) }
        if visible.isEmpty {
            return [CalendarInfo(id: "primary", summary: nil, backgroundColor: nil, selected: true, primary: true)]
        }
        return visible
    }

    private static func fetchEvents(from calendarInfo: CalendarInfo, on day: Date, token: String) async throws -> [GoogleCalendarEvent] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }

        let iso = ISO8601DateFormatter()
        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/\(calendarInfo.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarInfo.id)/events")!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: iso.string(from: dayStart)),
            URLQueryItem(name: "timeMax", value: iso.string(from: dayEnd)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: "100")
        ]
        guard let url = components.url else { return [] }
        let data = try await get(url, token: token)

        struct EventsResponse: Decodable {
            let items: [EventItem]?
        }
        struct EventItem: Decodable {
            struct EventTime: Decodable {
                let dateTime: String?
                let date: String?
            }
            let id: String
            let summary: String?
            let status: String?
            let start: EventTime?
            let end: EventTime?
        }

        let response = try JSONDecoder().decode(EventsResponse.self, from: data)
        let colorHex = (calendarInfo.backgroundColor ?? "#3380F5").replacingOccurrences(of: "#", with: "")
        let calendarName = calendarInfo.summary ?? "Google Calendar"

        return (response.items ?? []).compactMap { item in
            guard item.status != "cancelled" else { return nil }
            guard let startTime = item.start, let endTime = item.end else { return nil }

            if let startString = startTime.dateTime, let endString = endTime.dateTime,
               let start = parseRFC3339(startString), let end = parseRFC3339(endString) {
                return GoogleCalendarEvent(
                    id: "\(calendarInfo.id)/\(item.id)",
                    title: item.summary ?? "(No title)",
                    start: start,
                    end: end,
                    isAllDay: false,
                    colorHex: colorHex,
                    calendarName: calendarName
                )
            }

            if let startDay = startTime.date, let start = parseDateOnly(startDay) {
                let end = endTime.date.flatMap(parseDateOnly) ?? start.addingTimeInterval(86_400)
                return GoogleCalendarEvent(
                    id: "\(calendarInfo.id)/\(item.id)",
                    title: item.summary ?? "(No title)",
                    start: start,
                    end: end,
                    isAllDay: true,
                    colorHex: colorHex,
                    calendarName: calendarName
                )
            }
            return nil
        }
    }

    private static func get(_ url: URL, token: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw EventsError.server("Invalid response") }
        guard http.statusCode != 401 else { throw EventsError.server("Google Calendar session expired — sign in again in Settings") }
        guard (200..<300).contains(http.statusCode) else {
            throw EventsError.server("Google Calendar request failed (\(http.statusCode))")
        }
        return data
    }

    // MARK: - Parsing

    private static let rfc3339WithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let rfc3339: ISO8601DateFormatter = ISO8601DateFormatter()

    private static func parseRFC3339(_ string: String) -> Date? {
        rfc3339.date(from: string) ?? rfc3339WithFraction.date(from: string)
    }

    private static func parseDateOnly(_ string: String) -> Date? {
        let components = string.split(separator: "-").compactMap { Int($0) }
        guard components.count == 3 else { return nil }
        var dateComponents = DateComponents()
        dateComponents.year = components[0]
        dateComponents.month = components[1]
        dateComponents.day = components[2]
        return Calendar.current.date(from: dateComponents)
    }

    private struct RefreshResponse: Decodable {
        let access_token: String
        let expires_in: Int?
    }

    private enum EventsError: LocalizedError {
        case notConnected
        case server(String)

        var errorDescription: String? {
            switch self {
            case .notConnected: return "Google Calendar is not connected"
            case .server(let message): return message
            }
        }
    }
}
