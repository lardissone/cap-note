import Foundation

/// Builds API payloads from user settings, with an injectable clock and time zone for tests.
enum PayloadBuilder {
    static func buildDailyNoteRequest(
        text: String,
        useSeparator: Bool,
        separatorString: String,
        includeTimestamp: Bool,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> DailyNoteRequest {
        // The API expects the chosen calendar day labelled as UTC midnight,
        // not the instant of local midnight converted to UTC.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"

        return DailyNoteRequest(
            markdown: useSeparator ? separatorString + text : text,
            date: formatter.string(from: now) + "T00:00:00.000Z",
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
        // API v1 tokens belong to one space. Keep the existing settings UI's
        // list interface, populated with that single space.
        let request = makeRequest(path: "/space", method: "GET", body: nil)
        let data = try await perform(request)
        do {
            return [try JSONDecoder().decode(Space.self, from: data)]
        } catch {
            throw CapacitiesError.decoding
        }
    }

    func saveToDailyNote(_ payload: DailyNoteRequest) async throws {
        let body = try JSONEncoder().encode(payload)
        let request = makeRequest(path: "/blocks/daily-note/append", method: "POST", body: body)
        _ = try await perform(request)
    }

    private func makeRequest(path: String, method: String, body: Data?) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("1.0.0", forHTTPHeaderField: "X-Capacities-Api-Version")
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
        case 403:
            throw CapacitiesError.forbidden
        case 429:
            throw CapacitiesError.rateLimited
        default:
            throw CapacitiesError.server(status: http.statusCode)
        }
    }
}
