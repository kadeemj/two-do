import Foundation

/// Keychain keys shared by the auth service (writes) and events service (reads).
enum GoogleCalendarKeys {
    static let accessToken = "google.calendar.accessToken"
    static let refreshToken = "google.calendar.refreshToken"
    static let expiry = "google.calendar.expiry"
    static let email = "google.calendar.email"
    static let displayName = "google.calendar.displayName"
}

enum GoogleCalendarConfig {
    /// Create an OAuth client of type **iOS** in Google Cloud Console
    /// (bundle ID: `com.kadeem.twodo`), then paste the Client ID here.
    /// Do not use Web application — Google rejects custom schemes like twodo://
    static let clientID = "13891422235-fvtacidps3cpo4n15b8hkldsq7jbbaev.apps.googleusercontent.com"

    /// Reversed client ID used as the iOS URL scheme / redirect (Google’s format).
    static var reversedClientID: String {
        let suffix = ".apps.googleusercontent.com"
        let prefix = clientID.hasSuffix(suffix)
            ? String(clientID.dropLast(suffix.count))
            : clientID
        return "com.googleusercontent.apps.\(prefix)"
    }

    /// Google iOS redirect URI — no Console field to fill; it’s implied by the iOS client.
    static var redirectURI: String {
        "\(reversedClientID):/oauth2redirect"
    }

    static var callbackURLScheme: String {
        reversedClientID
    }

    static let authorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    static let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
    static let userInfoEndpoint = URL(string: "https://www.googleapis.com/oauth2/v3/userinfo")!

    static let scopes = [
        "https://www.googleapis.com/auth/calendar",
        "https://www.googleapis.com/auth/userinfo.email",
        "openid",
        "profile"
    ].joined(separator: " ")

    static var isConfigured: Bool {
        !clientID.isEmpty
            && !clientID.contains("YOUR_")
            && clientID.hasSuffix(".apps.googleusercontent.com")
    }
}
