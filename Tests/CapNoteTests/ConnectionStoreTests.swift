import XCTest
@testable import CapNote

final class ConnectionStoreTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let work = Space(id: "space-work", title: "Work")
    private var secrets: InMemorySecretStore!

    override func setUp() {
        super.setUp()
        secrets = InMemorySecretStore()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - connect

    func test_connect_exchangesCodeAndStoresTheGrantedSpace() async throws {
        let space = work
        let sentVerifier = Recorder()
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/oauth/token")
            XCTAssertEqual(request.formFields["code"], "code-1")
            sentVerifier.record(request.formFields["code_verifier"] ?? "")
            return (.ok(request), Self.tokenBody(access: "at-1", refresh: "rt-1"))
        }
        let store = makeStore(fetchSpace: { token in
            XCTAssertEqual(token, "at-1")
            return space
        })
        let sentChallenge = Recorder()

        let connected = try await store.connect { url in
            let query = Self.query(url)
            sentChallenge.record(query["code_challenge"] ?? "")
            let state = try XCTUnwrap(query["state"])
            return URL(string: "capnote://oauth/callback?code=code-1&state=\(state)")!
        }

        XCTAssertEqual(PKCE.challenge(for: sentVerifier.values[0]), sentChallenge.values[0])

        XCTAssertEqual(connected, work)
        let spaces = try await store.spaces()
        XCTAssertEqual(spaces, [work])
        let token = try await store.accessToken(for: work.id)
        XCTAssertEqual(token, "at-1")
    }

    func test_connect_rejectsCallbackForAnotherRequest() async {
        MockURLProtocol.requestHandler = { _ in
            XCTFail("No token request expected")
            throw URLError(.badURL)
        }
        let store = makeStore()

        do {
            _ = try await store.connect { _ in
                URL(string: "capnote://oauth/callback?code=code-1&state=forged")!
            }
            XCTFail("Expected state mismatch")
        } catch {
            XCTAssertEqual(error as? ConnectionError, .stateMismatch)
        }
        let spaces = try? await store.spaces()
        XCTAssertEqual(spaces, [])
    }

    func test_connect_reportsDeniedConsent() async {
        let store = makeStore()

        do {
            _ = try await store.connect { url in
                let state = Self.query(url)["state"] ?? ""
                return URL(string: "capnote://oauth/callback?error=access_denied&state=\(state)")!
            }
            XCTFail("Expected access denied")
        } catch {
            XCTAssertEqual(error as? ConnectionError, .denied("access_denied"))
        }
    }

    func test_connect_failureAfterExchange_revokesTheUnusedGrant() async {
        let revoked = Recorder()
        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/oauth/revoke" {
                revoked.record(request.formFields["token"] ?? "")
                return (.ok(request), Data())
            }
            return (.ok(request), Self.tokenBody(access: "at-1", refresh: "rt-1"))
        }
        let store = makeStore(fetchSpace: { _ in throw CapacitiesError.server(status: 500) })

        do {
            _ = try await store.connect { url in
                URL(string: "capnote://oauth/callback?code=c&state=\(Self.query(url)["state"] ?? "")")!
            }
            XCTFail("Expected the space lookup error")
        } catch {
            XCTAssertEqual(error as? CapacitiesError, .server(status: 500))
        }
        XCTAssertEqual(revoked.values, ["rt-1"])
        let spaces = try? await store.spaces()
        XCTAssertEqual(spaces, [])
    }

    // MARK: - accessToken

    func test_accessToken_unknownSpace_throwsNotConnected() async {
        let store = makeStore()

        do {
            _ = try await store.accessToken(for: "nope")
            XCTFail("Expected notConnected")
        } catch {
            XCTAssertEqual(error as? ConnectionError, .notConnected)
        }
    }

    func test_accessToken_validToken_isReturnedWithoutNetwork() async throws {
        try saveConnection(expiresAt: now.addingTimeInterval(3600))
        MockURLProtocol.requestHandler = { _ in
            XCTFail("No request expected")
            throw URLError(.badURL)
        }

        let token = try await makeStore().accessToken(for: work.id)

        XCTAssertEqual(token, "at-old")
    }

    func test_accessToken_nearExpiry_refreshesAndStoresRotatedToken() async throws {
        try saveConnection(expiresAt: now.addingTimeInterval(30))
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.formFields["refresh_token"], "rt-old")
            return (.ok(request), Self.tokenBody(access: "at-new", refresh: "rt-new"))
        }
        let store = makeStore()

        let token = try await store.accessToken(for: work.id)

        XCTAssertEqual(token, "at-new")
        let stored = try storedConnection()
        XCTAssertEqual(stored.refreshToken, "rt-new")
        XCTAssertEqual(stored.expiresAt, now.addingTimeInterval(3600))
    }

    func test_accessToken_concurrentCallers_shareOneRefresh() async throws {
        try saveConnection(expiresAt: now.addingTimeInterval(-1))
        let requests = Counter()
        MockURLProtocol.requestHandler = { request in
            requests.increment()
            Thread.sleep(forTimeInterval: 0.05)
            return (.ok(request), Self.tokenBody(access: "at-new", refresh: "rt-new"))
        }
        let store = makeStore()
        let spaceId = work.id

        async let first = store.accessToken(for: spaceId)
        async let second = store.accessToken(for: spaceId)
        let tokens = try await [first, second]

        XCTAssertEqual(tokens, ["at-new", "at-new"])
        XCTAssertEqual(requests.value, 1)
    }

    func test_accessToken_revokedRefreshToken_dropsConnection() async throws {
        try saveConnection(expiresAt: now.addingTimeInterval(-1))
        MockURLProtocol.requestHandler = { request in
            (.status(400, request), Data(#"{"error":"invalid_grant"}"#.utf8))
        }
        let store = makeStore()

        do {
            _ = try await store.accessToken(for: work.id)
            XCTFail("Expected reconnectRequired")
        } catch {
            XCTAssertEqual(error as? ConnectionError, .reconnectRequired(space: "Work"))
        }
        let spaces = try await store.spaces()
        XCTAssertEqual(spaces, [])
    }

    func test_accessToken_transientRefreshFailure_keepsConnectionAndRetries() async throws {
        try saveConnection(expiresAt: now.addingTimeInterval(-1))
        let requests = Counter()
        MockURLProtocol.requestHandler = { request in
            requests.increment()
            if requests.value == 1 {
                return (.status(503, request), Data())
            }
            return (.ok(request), Self.tokenBody(access: "at-new", refresh: "rt-new"))
        }
        let store = makeStore()

        do {
            _ = try await store.accessToken(for: work.id)
            XCTFail("Expected the server error")
        } catch {
            XCTAssertEqual(error as? OAuthError, .server(status: 503, code: nil))
        }
        let token = try await store.accessToken(for: work.id)

        XCTAssertEqual(token, "at-new")
        XCTAssertEqual(requests.value, 2)
    }

    func test_accessToken_keychainWriteFails_keepsRotatedTokenForThisRun() async throws {
        try saveConnection(expiresAt: now.addingTimeInterval(-1))
        secrets.failSaves()
        let requests = Counter()
        MockURLProtocol.requestHandler = { request in
            requests.increment()
            return (.ok(request), Self.tokenBody(access: "at-new", refresh: "rt-new"))
        }
        let store = makeStore()

        let first = try await store.accessToken(for: work.id)
        let second = try await store.accessToken(for: work.id)

        XCTAssertEqual(first, "at-new")
        XCTAssertEqual(second, "at-new")
        XCTAssertEqual(requests.value, 1)
    }

    // MARK: - disconnect

    func test_disconnect_removesConnectionAndRevokesIt() async throws {
        try saveConnection(expiresAt: now.addingTimeInterval(3600))
        let revoked = Counter()
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/oauth/revoke")
            XCTAssertEqual(request.formFields["token"], "rt-old")
            revoked.increment()
            return (.ok(request), Data())
        }
        let store = makeStore()

        try await store.disconnect(spaceId: work.id)

        XCTAssertEqual(revoked.value, 1)
        let spaces = try await store.spaces()
        XCTAssertEqual(spaces, [])
    }

    func test_disconnect_duringRefresh_revokesRotatedTokenAndStaysGone() async throws {
        try saveConnection(expiresAt: now.addingTimeInterval(-1))
        let revoked = Recorder()
        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/oauth/revoke" {
                revoked.record(request.formFields["token"] ?? "")
                return (.ok(request), Data())
            }
            Thread.sleep(forTimeInterval: 0.05)
            return (.ok(request), Self.tokenBody(access: "at-new", refresh: "rt-new"))
        }
        let store = makeStore()
        let spaceId = work.id

        let send = Task { try await store.accessToken(for: spaceId) }
        try await Task.sleep(nanoseconds: 10_000_000)
        try await store.disconnect(spaceId: spaceId)
        _ = try await send.value

        XCTAssertEqual(revoked.values, ["rt-new"])
        let spaces = try await store.spaces()
        XCTAssertEqual(spaces, [])
    }

    func test_disconnect_revokeFails_stillRemovesWithoutError() async throws {
        try saveConnection(expiresAt: now.addingTimeInterval(3600))
        let revoked = Recorder()
        MockURLProtocol.requestHandler = { request in
            revoked.record(request.formFields["token"] ?? "")
            throw URLError(.notConnectedToInternet)
        }
        let store = makeStore()

        try await store.disconnect(spaceId: work.id)

        XCTAssertEqual(revoked.values, ["rt-old"])
        let spaces = try await store.spaces()
        XCTAssertEqual(spaces, [])
    }

    // MARK: - Helpers

    private func makeStore(
        fetchSpace: @escaping @Sendable (String) async throws -> Space = { _ in
            XCTFail("No space lookup expected")
            throw URLError(.badURL)
        }
    ) -> ConnectionStore {
        let config = OAuthConfig(
            clientId: "client-123",
            redirectURI: "capnote://oauth/callback",
            callbackScheme: "capnote",
            scopes: ["api:read"],
            baseURL: URL(string: "https://api.example.test")!,
            resource: "https://api.capacities.io"
        )
        let now = self.now
        return ConnectionStore(
            secrets: secrets,
            oauth: OAuthClient(config: config, session: .mock()),
            fetchSpace: fetchSpace,
            now: { now }
        )
    }

    private func saveConnection(expiresAt: Date) throws {
        let connection = Connection(space: work, accessToken: "at-old", refreshToken: "rt-old", expiresAt: expiresAt)
        try secrets.save(JSONEncoder().encode(connection), account: work.id)
    }

    private func storedConnection() throws -> Connection {
        let data = try XCTUnwrap(secrets.read(account: work.id))
        return try JSONDecoder().decode(Connection.self, from: data)
    }

    private static func tokenBody(access: String, refresh: String) -> Data {
        Data(#"{"access_token":"\#(access)","refresh_token":"\#(refresh)","expires_in":3600}"#.utf8)
    }

    private static func query(_ url: URL) -> [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int { lock.withLock { count } }

    func increment() {
        lock.withLock { count += 1 }
    }
}

private final class Recorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []

    var values: [String] { lock.withLock { recorded } }

    func record(_ value: String) {
        lock.withLock { recorded.append(value) }
    }
}
