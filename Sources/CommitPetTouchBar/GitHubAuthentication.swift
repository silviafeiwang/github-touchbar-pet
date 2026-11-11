import Foundation
import Security

struct GitHubDeviceAuthorization: Sendable {
    let deviceCode: String
    let userCode: String
    let verificationURL: URL
    let expiresAt: Date
    let interval: TimeInterval
}

enum GitHubAuthenticationError: LocalizedError {
    case invalidResponse
    case github(String)
    case expired
    case denied
    case cancelled
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "GitHub returned an unexpected response."
        case .github(let message): message
        case .expired: "The GitHub sign-in code expired. Please try again."
        case .denied: "GitHub authorization was cancelled."
        case .cancelled: "Sign-in was cancelled."
        case .keychain(let status): "Could not save the GitHub login in Keychain (\(status))."
        }
    }
}

enum GitHubCredentialStore {
    private static let service = "dev.commitpet.touchbar.github"
    private static let account = "oauth-access-token"

    static func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func saveToken(_ token: String) throws {
        deleteToken()
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(token.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw GitHubAuthenticationError.keychain(status) }
    }

    static func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

actor GitHubOAuthClient {
    private struct DeviceCodeResponse: Decodable {
        let deviceCode: String
        let userCode: String
        let verificationURI: URL
        let expiresIn: TimeInterval
        let interval: TimeInterval

        enum CodingKeys: String, CodingKey {
            case deviceCode = "device_code"
            case userCode = "user_code"
            case verificationURI = "verification_uri"
            case expiresIn = "expires_in"
            case interval
        }
    }

    private struct TokenResponse: Decodable {
        let accessToken: String?
        let error: String?
        let errorDescription: String?
        let interval: TimeInterval?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case error
            case errorDescription = "error_description"
            case interval
        }
    }

    private struct UserResponse: Decodable { let login: String }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func begin(clientID: String) async throws -> GitHubDeviceAuthorization {
        let response: DeviceCodeResponse = try await postForm(
            url: URL(string: "https://github.com/login/device/code")!,
            parameters: [
                "client_id": clientID,
                "scope": "notifications read:user"
            ]
        )
        return GitHubDeviceAuthorization(
            deviceCode: response.deviceCode,
            userCode: response.userCode,
            verificationURL: response.verificationURI,
            expiresAt: Date().addingTimeInterval(response.expiresIn),
            interval: response.interval
        )
    }

    func finish(clientID: String, authorization: GitHubDeviceAuthorization) async throws -> String {
        var interval = authorization.interval
        while Date() < authorization.expiresAt {
            try await Task.sleep(for: .seconds(interval))
            let response: TokenResponse = try await postForm(
                url: URL(string: "https://github.com/login/oauth/access_token")!,
                parameters: [
                    "client_id": clientID,
                    "device_code": authorization.deviceCode,
                    "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
                ]
            )
            if let token = response.accessToken {
                let login = try await validate(token: token)
                try GitHubCredentialStore.saveToken(token)
                UserDefaults.standard.set(login, forKey: "githubAuthenticatedLogin")
                return login
            }
            switch response.error {
            case "authorization_pending":
                continue
            case "slow_down":
                interval = max(interval + 5, response.interval ?? 0)
            case "expired_token":
                throw GitHubAuthenticationError.expired
            case "access_denied":
                throw GitHubAuthenticationError.denied
            case .some:
                throw GitHubAuthenticationError.github(
                    response.errorDescription ?? "GitHub could not complete authorization."
                )
            case .none:
                throw GitHubAuthenticationError.invalidResponse
            }
        }
        throw GitHubAuthenticationError.expired
    }

    func validateStoredToken() async throws -> String? {
        guard let token = GitHubCredentialStore.loadToken() else { return nil }
        return try await validate(token: token)
    }

    private func validate(token: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.github.com/user")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2026-03-10", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("CommitPetTouchBar/0.4", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GitHubAuthenticationError.github("The saved GitHub login is no longer valid.")
        }
        return try JSONDecoder().decode(UserResponse.self, from: data).login
    }

    private func postForm<Response: Decodable>(
        url: URL,
        parameters: [String: String]
    ) async throws -> Response {
        var components = URLComponents()
        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("CommitPetTouchBar/0.4", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GitHubAuthenticationError.invalidResponse
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}

extension Notification.Name {
    static let githubAuthenticationDidChange = Notification.Name("GitHubAuthenticationDidChange")
}
