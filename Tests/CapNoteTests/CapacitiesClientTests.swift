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

    // MARK: - getSpace

    func test_getSpace_returnsTokenSpace() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/space")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Authorization"),
                "Bearer test-token"
            )
            let body = """
            {"id":"a-uuid","title":"Personal","icon":{"type":"iconify","val":"ph-lightbulb"}}
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

        let space = try await client.getSpace()

        XCTAssertEqual(space, Space(id: "a-uuid", title: "Personal"))
    }

    func test_getSpace_unauthorized_throwsCapacitiesError() async {
        MockURLProtocol.requestHandler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!,
                Data()
            )
        }

        do {
            _ = try await client.getSpace()
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
            noTimeStamp: true,
            date: "2026-11-03T00:00:00.000Z"
        )

        MockURLProtocol.requestHandler = { req in
            XCTAssertEqual(req.url?.path, "/blocks/daily-note/append")
            XCTAssertEqual(req.httpMethod, "POST")
            XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")

            // URLProtocol receives the body via httpBodyStream, not httpBody, in tests.
            let body = req.bodyData ?? Data()
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(Set(json.keys), ["markdown", "noTimeStamp", "date"])
            XCTAssertEqual(json["markdown"] as? String, "---\n\nHello")
            XCTAssertEqual(json["noTimeStamp"] as? Bool, true)
            XCTAssertEqual(json["date"] as? String, "2026-11-03T00:00:00.000Z")

            return (
                HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!,
                Data()
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
                markdown: "y", noTimeStamp: true, date: "2026-11-03T00:00:00.000Z"
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
                markdown: "y", noTimeStamp: true, date: "2026-11-03T00:00:00.000Z"
            ))
            XCTFail("Expected rate limited error")
        } catch let error as CapacitiesError {
            XCTAssertEqual(error, .rateLimited)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
