import Foundation
import AuthenticationServices
import CryptoKit
import SwiftUI

@MainActor
@Observable
final class GoogleCalendarAuthService: NSObject {
    private typealias Keys = GoogleCalendarKeys

    var isSignedIn = false
    var email: String?
    var displayName: String?
    var isBusy = false
    var lastError: String?

    private var presentationContextProvider: AuthPresentationContextProvider?
    private var authSession: ASWebAuthenticationSession?

    override init() {
        super.init()
        reloadFromKeychain()
    }

    func reloadFromKeychain() {
        email = KeychainStore.string(forKey: Keys.email)
        displayName = KeychainStore.string(forKey: Keys.displayName)
        isSignedIn = KeychainStore.string(forKey: Keys.refreshToken) != nil
            || KeychainStore.string(forKey: Keys.accessToken) != nil
    }

    func signIn() async {
        lastError = nil
        guard GoogleCalendarConfig.isConfigured else {
            lastError = "Add your Google OAuth Client ID in GoogleCalendarConfig.swift"
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            let pkce = try PKCE.generate()
            let authURL = try buildAuthorizationURL(codeChallenge: pkce.challenge)
            let callbackURL = try await startAuthSession(url: authURL)
            let code = try authorizationCode(from: callbackURL)
            let tokens = try await exchangeCode(code, verifier: pkce.verifier)
            try await persist(tokens: tokens)
            reloadFromKeychain()
        } catch AuthError.cancelled {
            // User dismissed the sheet — not an error surface.
        } catch {
            lastError = error.localizedDescription
        }
    }

    func signOut() {
        KeychainStore.remove(Keys.accessToken)
        KeychainStore.remove(Keys.refreshToken)
        KeychainStore.remove(Keys.expiry)
        KeychainStore.remove(Keys.email)
        KeychainStore.remove(Keys.displayName)
        isSignedIn = false
        email = nil
        displayName = nil
        lastError = nil
    }

    // MARK: - OAuth

    private func buildAuthorizationURL(codeChallenge: String) throws -> URL {
        var components = URLComponents(url: GoogleCalendarConfig.authorizationEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: GoogleCalendarConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: GoogleCalendarConfig.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: GoogleCalendarConfig.scopes),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        guard let url = components.url else { throw AuthError.invalidURL }
        return url
    }

    private func startAuthSession(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let provider = AuthPresentationContextProvider()
            self.presentationContextProvider = provider

            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: GoogleCalendarConfig.callbackURLScheme
            ) { callbackURL, error in
                self.authSession = nil
                self.presentationContextProvider = nil
                if let error {
                    let ns = error as NSError
                    if ns.domain == ASWebAuthenticationSessionErrorDomain,
                       ns.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: AuthError.cancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: AuthError.missingCallback)
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = provider
            session.prefersEphemeralWebBrowserSession = false
            self.authSession = session
            if !session.start() {
                continuation.resume(throwing: AuthError.failedToStart)
            }
        }
    }

    private func authorizationCode(from url: URL) throws -> String {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
            throw AuthError.missingCode
        }
        if let error = items.first(where: { $0.name == "error" })?.value {
            throw AuthError.server(error)
        }
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            throw AuthError.missingCode
        }
        return code
    }

    private func exchangeCode(_ code: String, verifier: String) async throws -> TokenResponse {
        var request = URLRequest(url: GoogleCalendarConfig.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "client_id": GoogleCalendarConfig.clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": GoogleCalendarConfig.redirectURI
        ]
        request.httpBody = body
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Token exchange failed"
            throw AuthError.server(message)
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func persist(tokens: TokenResponse) async throws {
        KeychainStore.set(tokens.access_token, forKey: Keys.accessToken)
        if let refresh = tokens.refresh_token {
            KeychainStore.set(refresh, forKey: Keys.refreshToken)
        }
        if let expiresIn = tokens.expires_in {
            let expiry = Date().addingTimeInterval(TimeInterval(expiresIn)).timeIntervalSince1970
            KeychainStore.set(String(expiry), forKey: Keys.expiry)
        }

        if let profile = try? await fetchUserInfo(accessToken: tokens.access_token) {
            if let email = profile.email {
                KeychainStore.set(email, forKey: Keys.email)
            }
            if let name = profile.name {
                KeychainStore.set(name, forKey: Keys.displayName)
            }
        }
    }

    private func fetchUserInfo(accessToken: String) async throws -> UserInfo {
        var request = URLRequest(url: GoogleCalendarConfig.userInfoEndpoint)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthError.server("Could not load Google account profile")
        }
        return try JSONDecoder().decode(UserInfo.self, from: data)
    }
}

// MARK: - Models

private struct TokenResponse: Decodable {
    let access_token: String
    let expires_in: Int?
    let refresh_token: String?
    let scope: String?
    let token_type: String?
}

private struct UserInfo: Decodable {
    let email: String?
    let name: String?
}

private enum AuthError: LocalizedError {
    case invalidURL
    case cancelled
    case missingCallback
    case missingCode
    case failedToStart
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Could not build Google sign-in URL"
        case .cancelled: return "Sign-in cancelled"
        case .missingCallback: return "Missing Google callback"
        case .missingCode: return "Google did not return an auth code"
        case .failedToStart: return "Could not start Google sign-in"
        case .server(let message): return message
        }
    }
}

// MARK: - PKCE

private enum PKCE {
    struct Pair {
        let verifier: String
        let challenge: String
    }

    static func generate() throws -> Pair {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { throw AuthError.failedToStart }
        let verifier = Data(bytes).base64URLEncodedString()
        let challengeData = Data(SHA256.hash(data: Data(verifier.utf8)))
        let challenge = challengeData.base64URLEncodedString()
        return Pair(verifier: verifier, challenge: challenge)
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Presentation

private final class AuthPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
