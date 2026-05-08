import Foundation
import Observation

@Observable
final class AppState {
    static let shared = AppState()

    var noteText: String = ""
    var sendStatus: SendStatus = .idle
    var spaces: [Space] = []
    var face: CardFace = .input

    /// Incremented every time the editor should grab focus. Views observe this
    /// via `.onChange` to drive `@FocusState` regardless of view-tree lifecycle.
    var focusEditorTrigger: Int = 0

    private init() {}
}
