import XCTest
@testable import CapNote

final class PayloadBuilderTests: XCTestCase {
    func test_separatorOn_timestampOff_prependsSeparatorAndDisablesTimestamp() {
        let request = PayloadBuilder.buildDailyNoteRequest(
            text: "Hello world",
            spaceId: "space-uuid",
            useSeparator: true,
            separatorString: "---\n\n",
            includeTimestamp: false
        )

        XCTAssertEqual(request.spaceId, "space-uuid")
        XCTAssertEqual(request.mdText, "---\n\nHello world")
        XCTAssertEqual(request.origin, "commandPalette")
        XCTAssertTrue(request.noTimeStamp)
    }

    func test_separatorOff_timestampOff_sendsTextAsIs() {
        let request = PayloadBuilder.buildDailyNoteRequest(
            text: "Bare note",
            spaceId: "space-uuid",
            useSeparator: false,
            separatorString: "---\n\n",
            includeTimestamp: false
        )

        XCTAssertEqual(request.mdText, "Bare note")
        XCTAssertTrue(request.noTimeStamp)
    }

    func test_separatorOn_timestampOn_enablesTimestamp() {
        let request = PayloadBuilder.buildDailyNoteRequest(
            text: "With time",
            spaceId: "space-uuid",
            useSeparator: true,
            separatorString: "---\n\n",
            includeTimestamp: true
        )

        XCTAssertEqual(request.mdText, "---\n\nWith time")
        XCTAssertFalse(request.noTimeStamp)
    }

    func test_customSeparator_isUsedVerbatim() {
        let request = PayloadBuilder.buildDailyNoteRequest(
            text: "Custom",
            spaceId: "space-uuid",
            useSeparator: true,
            separatorString: "***\n",
            includeTimestamp: false
        )

        XCTAssertEqual(request.mdText, "***\nCustom")
    }
}
