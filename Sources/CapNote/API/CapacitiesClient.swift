import Foundation

/// Builds API request payloads from user settings. Pure, deterministic — easy to unit-test.
enum PayloadBuilder {
    static func buildDailyNoteRequest(
        text: String,
        useSeparator: Bool,
        separatorString: String,
        includeTimestamp: Bool,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> DailyNoteRequest {
        let markdown = useSeparator ? separatorString + text : text
        return DailyNoteRequest(
            markdown: markdown,
            noTimeStamp: !includeTimestamp,
            date: dailyNoteDate(for: now, in: timeZone)
        )
    }

    /// The API identifies a daily note by its day at UTC midnight and defaults to the
    /// server's today, so a note written late in the evening west of UTC would land on
    /// tomorrow's page. Sending the user's local calendar day keeps it on the right one.
    static func dailyNoteDate(for now: Date, in timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let day = calendar.dateComponents([.year, .month, .day], from: now)
        return String(format: "%04d-%02d-%02dT00:00:00.000Z", day.year!, day.month!, day.day!)
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

    /// Returns the space the token is scoped to. Every token grants access to exactly one space.
    func getSpace() async throws -> Space {
        let request = makeRequest(path: "/space", method: "GET", body: nil)
        let data = try await perform(request)
        do {
            return try JSONDecoder().decode(Space.self, from: data)
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
