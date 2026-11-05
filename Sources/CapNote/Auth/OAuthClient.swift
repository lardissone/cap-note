import Foundation

struct OAuthConfig: Sendable {
    let clientId: String
    let redirectURI: String
    let callbackScheme: String
    let scopes: [String]
    let baseURL: URL
    let resource: String

    static let capacities = OAuthConfig(
        // Issued by Capacities when the integration is registered.
        clientId: "capacities_api_capnote",
        redirectURI: "capnote://oauth/callback",
        callbackScheme: "capnote",
        scopes: ["api:read", "api:write", "offline_access"],
        baseURL: URL(string: "https://api.capacities.io")!,
        resource: "https://api.capacities.io"
    )
}

/// Token endpoint response. `expiresIn` is in seconds.
struct TokenGrant: Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: TimeInterval
}

enum OAuthError: Error, LocalizedError, Equatable {
    /// The code or refresh token is no longer valid; the user has to authorize again.
    case invalidGrant
    case server(status: Int, code: String?)

    var errorDescription: String? {
        switch self {
        case .invalidGrant:
            return "Capacities rejected the authorization. Connect the space again."
        case .server(let status, let code?):
            return "Capacities sign-in failed: \(code) (status \(status))."
        case .server(let status, nil):
            return "Capacities sign-in failed with status \(status)."
        }
    }
}

/// Authorization code flow with PKCE against Capacities, for a public client (no secret).
struct OAuthClient: Sendable {
    let config: OAuthConfig
    let session: URLSession

    init(config: OAuthConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func authorizeURL(state: String, codeChallenge: String) -> URL {
        var components = URLComponents(
            url: config.baseURL.appendingPathComponent("/oauth/authorize"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "scope", value: config.scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "resource", value: config.resource)
        ]
        return components.url!
    }

    func exchange(code: String, codeVerifier: String) async throws -> TokenGrant {
        try await requestTokens([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": config.redirectURI,
            "client_id": config.clientId,
            "code_verifier": codeVerifier
        ])
    }

    func refresh(_ refreshToken: String) async throws -> TokenGrant {
        try await requestTokens([
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": config.clientId
        ])
    }

    /// Revoking the refresh token removes the whole connection on Capacities' side.
    func revoke(_ refreshToken: String) async throws {
        _ = try await postForm(path: "/oauth/revoke", fields: [
            "token": refreshToken,
            "token_type_hint": "refresh_token",
            "client_id": config.clientId
        ])
    }

    private func requestTokens(_ fields: [String: String]) async throws -> TokenGrant {
        let data = try await postForm(path: "/oauth/token", fields: fields)
        let response: TokenResponse
        do {
            response = try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw CapacitiesError.decoding
        }
        return TokenGrant(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresIn: response.expiresIn
        )
    }

    private func postForm(path: String, fields: [String: String]) async throws -> Data {
        var request = URLRequest(url: config.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(Self.formEncode(fields).utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw CapacitiesError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw CapacitiesError.network("Invalid response")
        }
        guard (200...299).contains(http.statusCode) else {
            let code = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error
            if code == "invalid_grant" {
                throw OAuthError.invalidGrant
            }
            throw OAuthError.server(status: http.statusCode, code: code)
        }
        return data
    }

    static func formEncode(_ fields: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return fields
            .sorted { $0.key < $1.key }
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")
    }

    private struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: TimeInterval

        private enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
        }
    }

    private struct ErrorResponse: Decodable {
        let error: String
    }
}
