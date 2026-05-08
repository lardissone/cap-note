import Foundation

struct Space: Codable, Identifiable, Hashable {
    let id: String
    let title: String

    private enum CodingKeys: String, CodingKey {
        case id
        case title
    }
}

struct SpacesResponse: Codable {
    let spaces: [Space]
}

struct DailyNoteRequest: Codable, Equatable {
    let spaceId: String
    let mdText: String
    let origin: String
    let noTimeStamp: Bool
}

enum CapacitiesError: Error, LocalizedError, Equatable {
    case missingToken
    case missingSpace
    case unauthorized
    case rateLimited
    case server(status: Int)
    case decoding
    case network(String)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "API token is not configured."
        case .missingSpace:
            return "No space selected."
        case .unauthorized:
            return "Invalid API token."
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
