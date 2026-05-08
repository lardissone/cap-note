import Foundation

/// Builds API request payloads from user settings. Pure, deterministic — easy to unit-test.
enum PayloadBuilder {
    static let origin = "commandPalette"

    static func buildDailyNoteRequest(
        text: String,
        spaceId: String,
        useSeparator: Bool,
        separatorString: String,
        includeTimestamp: Bool
    ) -> DailyNoteRequest {
        let mdText = useSeparator ? separatorString + text : text
        return DailyNoteRequest(
            spaceId: spaceId,
            mdText: mdText,
            origin: origin,
            noTimeStamp: !includeTimestamp
        )
    }
}

struct CapacitiesClient {
    let baseURL: URL
    let token: String
    let session: URLSession

    init(
        baseURL: URL = URL(string: "https://api.capacities.io")!,
        token: String,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
    }

    func listSpaces() async throws -> [Space] {
        let request = makeRequest(path: "/spaces", method: "GET", body: nil)
        let data = try await perform(request)
        do {
            return try JSONDecoder().decode(SpacesResponse.self, from: data).spaces
        } catch {
            throw CapacitiesError.decoding
        }
    }

    func saveToDailyNote(_ payload: DailyNoteRequest) async throws {
        let body = try JSONEncoder().encode(payload)
        let request = makeRequest(path: "/save-to-daily-note", method: "POST", body: body)
        _ = try await perform(request)
    }

    private func makeRequest(path: String, method: String, body: Data?) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
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

        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            throw CapacitiesError.unauthorized
        case 429:
            throw CapacitiesError.rateLimited
        default:
            throw CapacitiesError.server(status: http.statusCode)
        }
    }
}
