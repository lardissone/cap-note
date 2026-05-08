import Foundation
import Observation

@Observable
final class AppState {
    static let shared = AppState()

    var noteText: String = ""
    var sendStatus: SendStatus = .idle
    var spaces: [Space] = []
    var face: CardFace = .input

    private init() {}
}
