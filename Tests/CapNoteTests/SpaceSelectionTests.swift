import XCTest
@testable import CapNote

final class SpaceSelectionTests: XCTestCase {
    private let alpha = Space(id: "a", title: "Alpha")
    private let beta = Space(id: "b", title: "Beta")

    func test_keepsCurrentSelection_whenStillPresent() {
        let resolved = SpaceSelection.resolve(spaces: [alpha, beta], current: "b")
        XCTAssertEqual(resolved, "b")
    }

    func test_fallsBackToFirstSpace_whenCurrentIsMissing() {
        let resolved = SpaceSelection.resolve(spaces: [alpha, beta], current: "ghost")
        XCTAssertEqual(resolved, "a")
    }

    func test_fallsBackToFirstSpace_whenCurrentIsNil() {
        let resolved = SpaceSelection.resolve(spaces: [alpha, beta], current: nil)
        XCTAssertEqual(resolved, "a")
    }

    func test_returnsNil_whenSpacesAreEmpty() {
        let resolved = SpaceSelection.resolve(spaces: [], current: "b")
        XCTAssertNil(resolved)
    }
}
