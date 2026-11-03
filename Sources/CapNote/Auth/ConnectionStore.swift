import Foundation

/// An authorized Capacities space. Each OAuth connection grants access to exactly one space.
struct Connection: Codable, Equatable, Sendable {
    let space: Space
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

enum ConnectionError: Error, LocalizedError, Equatable {
    case notConnected
    case reconnectRequired(space: String)
    case revokeFailed(space: String, reason: String)
    case denied(String)
    case stateMismatch
    case invalidCallback
    case cancelled
    case couldNotStart

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Connect a Capacities space first."
        case .reconnectRequired(let space):
            return "Capacities no longer accepts the connection to \(space). Connect it again in settings."
        case .revokeFailed(let space, let reason):
            return "Disconnected \(space), but Capacities couldn't be notified (\(reason)). You can remove it in Capacities → Settings → Capacities API → Connections."
        case .denied(let reason):
            return "Capacities didn't grant access: \(reason)"
        case .stateMismatch:
            return "The authorization response didn't match this request. Try again."
        case .invalidCallback:
            return "Capacities returned an unexpected authorization response."
        case .cancelled:
            return "Connection cancelled."
        case .couldNotStart:
            return "Could not open the Capacities sign-in page."
        }
    }
}

enum OAuthCallback {
    /// Extracts the authorization code from the redirect, rejecting responses to other requests.
    static func code(from url: URL, expectedState: String) throws -> String {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value
        }

        guard value("state") == expectedState else {
            throw ConnectionError.stateMismatch
        }
        if let error = value("error") {
            throw ConnectionError.denied(value("error_description") ?? error)
        }
        guard let code = value("code"), !code.isEmpty else {
            throw ConnectionError.invalidCallback
        }
        return code
    }
}

/// Owns the connected spaces and hands out access tokens, refreshing them when they expire.
actor ConnectionStore {
    static let shared = ConnectionStore(
        secrets: Keychain.connections,
        oauth: OAuthClient(config: .capacities)
    )

    /// Refresh this long before expiry so a token doesn't lapse mid-request.
    static let refreshMargin: TimeInterval = 60

    private let secrets: SecretStore
    private let oauth: OAuthClient
    private let fetchSpace: @Sendable (String) async throws -> Space
    private let now: @Sendable () -> Date

    /// Refresh tokens rotate on every use, so concurrent refreshes of one connection
    /// must share a single request: a second one would present an already-revoked token.
    private var refreshes: [String: Task<String, Error>] = [:]

    /// The latest known state of each connection. A rotated refresh token is the only valid
    /// one, so it is kept here even when writing it to the Keychain fails.
    private var cache: [String: Connection] = [:]

    init(
        secrets: SecretStore,
        oauth: OAuthClient,
        fetchSpace: @escaping @Sendable (String) async throws -> Space = { token in
            try await CapacitiesClient(token: token).getSpace()
        },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.secrets = secrets
        self.oauth = oauth
        self.fetchSpace = fetchSpace
        self.now = now
    }

    func spaces() throws -> [Space] {
        try secrets.accounts()
            .compactMap { spaceId -> Space? in
                do {
                    return try connection(for: spaceId)?.space
                } catch {
                    NSLog("CapNote: skipping unreadable connection \(spaceId): \(error)")
                    return nil
                }
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// Runs the authorization flow. `authorize` presents the URL to the user and returns
    /// the redirect it lands on. Authorizing a space that is already connected replaces it.
    func connect(authorize: @Sendable (URL) async throws -> URL) async throws -> Space {
        let verifier = PKCE.makeVerifier()
        let state = PKCE.makeState()
        let url = oauth.authorizeURL(state: state, codeChallenge: PKCE.challenge(for: verifier))

        let callback = try await authorize(url)
        let code = try OAuthCallback.code(from: callback, expectedState: state)
        let grant = try await oauth.exchange(code: code, codeVerifier: verifier)

        do {
            let space = try await fetchSpace(grant.accessToken)
            await settleRefresh(for: space.id)
            let connection = Connection(
                space: space,
                accessToken: grant.accessToken,
                refreshToken: grant.refreshToken,
                expiresAt: now().addingTimeInterval(grant.expiresIn)
            )
            try secrets.save(JSONEncoder().encode(connection), account: space.id)
            cache[space.id] = connection
            return space
        } catch {
            // The grant can't be used, so don't leave it behind as a connection on Capacities.
            do {
                try await oauth.revoke(grant.refreshToken)
            } catch let revokeError {
                NSLog("CapNote: could not revoke unused grant: \(revokeError)")
            }
            throw error
        }
    }

    /// Forgets the connection locally, then revokes it on Capacities' side.
    func disconnect(spaceId: String) async throws {
        await settleRefresh(for: spaceId)
        guard let connection = try connection(for: spaceId) else { return }
        try remove(spaceId)
        do {
            try await oauth.revoke(connection.refreshToken)
        } catch {
            throw ConnectionError.revokeFailed(space: connection.space.title, reason: error.localizedDescription)
        }
    }

    func accessToken(for spaceId: String) async throws -> String {
        if let inFlight = refreshes[spaceId] {
            return try await inFlight.value
        }
        guard let connection = try connection(for: spaceId) else {
            throw ConnectionError.notConnected
        }
        if connection.expiresAt > now().addingTimeInterval(Self.refreshMargin) {
            return connection.accessToken
        }

        let refresh = Task { try await self.refresh(connection) }
        refreshes[spaceId] = refresh
        defer { refreshes[spaceId] = nil }
        return try await refresh.value
    }

    private func refresh(_ connection: Connection) async throws -> String {
        let spaceId = connection.space.id
        let grant: TokenGrant
        do {
            grant = try await oauth.refresh(connection.refreshToken)
        } catch OAuthError.invalidGrant {
            do {
                try remove(spaceId)
            } catch {
                NSLog("CapNote: could not remove rejected connection \(spaceId): \(error)")
            }
            throw ConnectionError.reconnectRequired(space: connection.space.title)
        }

        let refreshed = Connection(
            space: connection.space,
            accessToken: grant.accessToken,
            refreshToken: grant.refreshToken,
            expiresAt: now().addingTimeInterval(grant.expiresIn)
        )
        cache[spaceId] = refreshed
        do {
            try secrets.save(JSONEncoder().encode(refreshed), account: spaceId)
        } catch {
            // The cache keeps the rotated token for this run; the next refresh retries the write.
            NSLog("CapNote: could not persist refreshed connection \(spaceId): \(error)")
        }
        return grant.accessToken
    }

    /// Waits for an in-flight refresh so its rotated token is the one acted on. Its outcome
    /// is reported to the caller that started it, not here.
    private func settleRefresh(for spaceId: String) async {
        guard let inFlight = refreshes[spaceId] else { return }
        _ = try? await inFlight.value
    }

    private func connection(for spaceId: String) throws -> Connection? {
        if let cached = cache[spaceId] {
            return cached
        }
        guard let data = try secrets.read(account: spaceId) else { return nil }
        let connection = try JSONDecoder().decode(Connection.self, from: data)
        cache[spaceId] = connection
        return connection
    }

    private func remove(_ spaceId: String) throws {
        cache[spaceId] = nil
        try secrets.delete(account: spaceId)
    }
}
