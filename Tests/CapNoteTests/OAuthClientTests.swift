import XCTest
@testable import CapNote

final class OAuthClientTests: XCTestCase {
    private let config = OAuthConfig(
        clientId: "client-123",
        redirectURI: "capnote://oauth/callback",
        callbackScheme: "capnote",
        scopes: ["api:read", "api:write", "offline_access"],
        baseURL: URL(string: "https://api.example.test")!,
        resource: "https://api.capacities.io"
    )
    private var client: OAuthClient!

    override func setUp() {
        super.setUp()
        client = OAuthClient(config: config, session: .mock())
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func test_authorizeURL_carriesEveryRequiredParameter() throws {
        let url = client.authorizeURL(state: "state-1", codeChallenge: "challenge-1")
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })

        XCTAssertEqual(components.host, "api.example.test")
        XCTAssertEqual(components.path, "/oauth/authorize")
        XCTAssertEqual(query, [
            "response_type": "code",
            "client_id": "client-123",
            "redirect_uri": "capnote://oauth/callback",
            "scope": "api:read api:write offline_access",
            "code_challenge": "challenge-1",
            "code_challenge_method": "S256",
            "state": "state-1",
            "resource": "https://api.capacities.io"
        ])
    }

    func test_exchange_postsFormWithoutAuthorizationHeader() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/oauth/token")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            XCTAssertEqual(request.formFields, [
                "grant_type": "authorization_code",
                "code": "code-1",
                "redirect_uri": "capnote://oauth/callback",
                "client_id": "client-123",
                "code_verifier": "verifier-1"
            ])
            return (.ok(request), Data(#"{"access_token":"at","refresh_token":"rt","expires_in":3600,"token_type":"Bearer"}"#.utf8))
        }

        let grant = try await client.exchange(code: "code-1", codeVerifier: "verifier-1")

        XCTAssertEqual(grant, TokenGrant(accessToken: "at", refreshToken: "rt", expiresIn: 3600))
    }

    func test_refresh_sendsRefreshToken() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.formFields, [
                "grant_type": "refresh_token",
                "refresh_token": "rt-old",
                "client_id": "client-123"
            ])
            return (.ok(request), Data(#"{"access_token":"at2","refresh_token":"rt-new","expires_in":3600}"#.utf8))
        }

        let grant = try await client.refresh("rt-old")

        XCTAssertEqual(grant.refreshToken, "rt-new")
    }

    func test_invalidGrant_isReportedAsSuch() async {
        MockURLProtocol.requestHandler = { request in
            (.status(400, request), Data(#"{"error":"invalid_grant"}"#.utf8))
        }

        do {
            _ = try await client.refresh("rt-revoked")
            XCTFail("Expected invalid_grant")
        } catch {
            XCTAssertEqual(error as? OAuthError, .invalidGrant)
        }
    }

    func test_otherTokenErrors_keepStatusAndCode() async {
        MockURLProtocol.requestHandler = { request in
            (.status(401, request), Data(#"{"error":"unauthorized_client"}"#.utf8))
        }

        do {
            _ = try await client.exchange(code: "c", codeVerifier: "v")
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? OAuthError, .server(status: 401, code: "unauthorized_client"))
        }
    }

    func test_revoke_postsRefreshToken() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/oauth/revoke")
            XCTAssertEqual(request.formFields, [
                "token": "rt",
                "token_type_hint": "refresh_token",
                "client_id": "client-123"
            ])
            return (.ok(request), Data())
        }

        try await client.revoke("rt")
    }

    func test_formEncode_escapesReservedCharacters() {
        XCTAssertEqual(
            OAuthClient.formEncode(["redirect_uri": "capnote://oauth/callback", "a": "x y+z"]),
            "a=x%20y%2Bz&redirect_uri=capnote%3A%2F%2Foauth%2Fcallback"
        )
    }
}
