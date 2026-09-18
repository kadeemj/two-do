import Foundation
import Security

enum KeychainStore {
    /// Migration from direct Google OAuth to device calendars. This only removes
    /// this app's local credentials; it does not revoke authorization at Google.
    static func removeLegacyGoogleCredentials() {
        for key in ["accessToken", "refreshToken", "expiry", "email", "displayName"] {
            remove("google.calendar.\(key)")
        }
    }
    private static func remove(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.kadeem.twodo"
        ]
        SecItemDelete(query as CFDictionary)
    }
}
