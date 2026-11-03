import Foundation

struct Space: Codable, Identifiable, Hashable {
    let id: String
    let title: String

    private enum CodingKeys: String, CodingKey {
        case id
        case title
    }
}

struct DailyNoteRequest: Codable, Equatable {
    let markdown: String
    let noTimeStamp: Bool
    let date: String
}

enum CapacitiesError: Error, LocalizedError, Equatable {
    case unauthorized
    case rateLimited
    case server(status: Int)
    case decoding
    case network(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Capacities rejected the connection. Connect the space again in settings."
        case .rateLimited:
            return "Rate limit exceeded — try again in a moment."
        case .server(let status):
            return "Server returned status \(status)."
        case .decoding:
            return "Could not decode server response."
        case .network(let message):
            return "Network error: \(message)"
        }
    }
}
