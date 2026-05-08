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

    func test_listSpaces_returnsParsedSpaces() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/spaces")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Authorization"),
                "Bearer test-token"
            )
            let body = """
            {"spaces":[
                {"id":"a-uuid","title":"Personal"},
                {"id":"b-uuid","title":"Work"}
            ]}
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

        XCTAssertEqual(spaces.count, 2)
        XCTAssertEqual(spaces[0].id, "a-uuid")
        XCTAssertEqual(spaces[0].title, "Personal")
        XCTAssertEqual(spaces[1].title, "Work")
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
            spaceId: "space-1",
            mdText: "---\n\nHello",
            origin: "commandPalette",
            noTimeStamp: true
        )

        MockURLProtocol.requestHandler = { req in
            XCTAssertEqual(req.url?.path, "/save-to-daily-note")
            XCTAssertEqual(req.httpMethod, "POST")
            XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")

            // URLProtocol receives the body via httpBodyStream, not httpBody, in tests.
            let body = req.bodyData ?? Data()
            let decoded = try JSONDecoder().decode(DailyNoteRequest.self, from: body)
            XCTAssertEqual(decoded, request)

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
                spaceId: "x", mdText: "y", origin: "z", noTimeStamp: true
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
                spaceId: "x", mdText: "y", origin: "z", noTimeStamp: true
            ))
            XCTFail("Expected rate limited error")
        } catch let error as CapacitiesError {
            XCTAssertEqual(error, .rateLimited)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
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
