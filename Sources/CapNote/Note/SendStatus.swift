import Foundation

enum SendStatus: Equatable {
    case idle
    case sending
    case sent
    case error(String)
}
