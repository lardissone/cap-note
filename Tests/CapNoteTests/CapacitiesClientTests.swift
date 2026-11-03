import XCTest
@testable import CapNote

final class CapacitiesClientTests: XCTestCase {
    private var client: CapacitiesClient!

    override func setUp() {
        super.setUp()
        client = CapacitiesClient(
            baseURL: URL(string: "https://api.example.test")!,
            token: "test-token",
            session: .mock()
        )
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - listSpaces

    func test_listSpaces_returnsOnlyTokenBoundSpace() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/space")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertNil(request.url?.query)
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Capacities-Api-Version"), "1.0.0")
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Authorization"),
                "Bearer test-token"
            )
            let body = """
            {"id":"a-uuid","title":"Personal","icon":{"type":"emoji","val":"📝"}}
            """
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Data(body.utf8)
            )
        }

        let spaces = try await client.listSpaces()

        XCTAssertEqual(spaces.count, 1)
        XCTAssertEqual(spaces[0].id, "a-uuid")
        XCTAssertEqual(spaces[0].title, "Personal")
    }

    func test_listSpaces_unauthorized_throwsCapacitiesError() async {
        MockURLProtocol.requestHandler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!,
                Data()
            )
        }

        do {
            _ = try await client.listSpaces()
            XCTFail("Expected unauthorized error")
        } catch let error as CapacitiesError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - saveToDailyNote

    func test_saveToDailyNote_postsBodyAndAuthHeader() async throws {
        let request = DailyNoteRequest(
            markdown: "---\n\nHello",
            date: "2026-10-12T00:00:00.000Z",
            noTimeStamp: true
        )

        MockURLProtocol.requestHandler = { req in
            XCTAssertEqual(req.url?.path, "/blocks/daily-note/append")
            XCTAssertEqual(req.httpMethod, "POST")
            XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")

            // URLProtocol receives the body via httpBodyStream, not httpBody, in tests.
            let body = req.bodyData ?? Data()
            let decoded = try JSONDecoder().decode(DailyNoteRequest.self, from: body)
            XCTAssertEqual(decoded, request)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(Set(json.keys), Set(["markdown", "date", "noTimeStamp"]))
            XCTAssertEqual(req.value(forHTTPHeaderField: "X-Capacities-Api-Version"), "1.0.0")

            return (
                HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("{}".utf8)
            )
        }

        try await client.saveToDailyNote(request)
    }

    func test_saveToDailyNote_unauthorized_throws() async {
        MockURLProtocol.requestHandler = { req in
            (
                HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!,
                Data()
            )
        }

        do {
            try await client.saveToDailyNote(DailyNoteRequest(
                markdown: "y", date: "2026-10-12T00:00:00.000Z", noTimeStamp: true
            ))
            XCTFail("Expected unauthorized error")
        } catch let error as CapacitiesError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_saveToDailyNote_rateLimited_throws() async {
        MockURLProtocol.requestHandler = { req in
            (
                HTTPURLResponse(url: req.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!,
                Data()
            )
        }

        do {
            try await client.saveToDailyNote(DailyNoteRequest(
                markdown: "y", date: "2026-10-12T00:00:00.000Z", noTimeStamp: true
            ))
            XCTFail("Expected rate limited error")
        } catch let error as CapacitiesError {
            XCTAssertEqual(error, .rateLimited)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_listSpaces_malformedResponse_throwsDecodingError() async {
        MockURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
             Data("{\"spaces\":[]}".utf8))
        }
        do {
            _ = try await client.listSpaces()
            XCTFail("Expected decoding error")
        } catch let error as CapacitiesError {
            XCTAssertEqual(error, .decoding)
        } catch { XCTFail("Unexpected error: \(error)") }
    }

    func test_saveToDailyNote_empty204_succeeds() async throws {
        MockURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, nil)
        }
        try await client.saveToDailyNote(DailyNoteRequest(
            markdown: "Günlük not 📝\nSecond line", date: "2026-10-12T00:00:00.000Z", noTimeStamp: false
        ))
    }

    func test_saveToDailyNote_httpErrors_doNotRetry() async {
        for (status, expected) in [(400, CapacitiesError.server(status: 400)),
                                   (403, .forbidden), (500, .server(status: 500))] {
            var calls = 0
            MockURLProtocol.requestHandler = { req in
                calls += 1
                return (HTTPURLResponse(url: req.url!, statusCode: status, httpVersion: nil, headerFields: nil)!,
                        Data())
            }
            do {
                try await client.saveToDailyNote(DailyNoteRequest(
                    markdown: "note", date: "2026-10-12T00:00:00.000Z", noTimeStamp: true
                ))
                XCTFail("Expected HTTP error")
            } catch let error as CapacitiesError {
                XCTAssertEqual(error, expected)
            } catch { XCTFail("Unexpected error: \(error)") }
            XCTAssertEqual(calls, 1)
        }
    }

    func test_saveToDailyNote_timeout_doesNotRetry() async {
        var calls = 0
        MockURLProtocol.requestHandler = { _ in
            calls += 1
            throw URLError(.timedOut)
        }
        do {
            try await client.saveToDailyNote(DailyNoteRequest(
                markdown: "note", date: "2026-10-12T00:00:00.000Z", noTimeStamp: true
            ))
            XCTFail("Expected timeout")
        } catch let error as CapacitiesError {
            guard case .network = error else { return XCTFail("Expected network error") }
        } catch { XCTFail("Unexpected error: \(error)") }
        XCTAssertEqual(calls, 1)
    }
}

private extension URLRequest {
    /// URLProtocol receives the body as a stream rather than `httpBody`.
    /// Drains it into Data for assertion purposes.
    var bodyData: Data? {
        guard let stream = httpBodyStream else { return httpBody }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
