import XCTest
@testable import CapNote

final class PayloadBuilderTests: XCTestCase {
    func test_separatorOn_timestampOff_prependsSeparatorAndDisablesTimestamp() {
        let request = PayloadBuilder.buildDailyNoteRequest(
            text: "Hello world",
            useSeparator: true,
            separatorString: "---\n\n",
            includeTimestamp: false
        )

        XCTAssertEqual(request.markdown, "---\n\nHello world")
        XCTAssertTrue(request.noTimeStamp)
    }

    func test_separatorOff_timestampOff_sendsTextAsIs() {
        let request = PayloadBuilder.buildDailyNoteRequest(
            text: "Bare note",
            useSeparator: false,
            separatorString: "---\n\n",
            includeTimestamp: false
        )

        XCTAssertEqual(request.markdown, "Bare note")
        XCTAssertTrue(request.noTimeStamp)
    }

    func test_separatorOn_timestampOn_enablesTimestamp() {
        let request = PayloadBuilder.buildDailyNoteRequest(
            text: "With time",
            useSeparator: true,
            separatorString: "---\n\n",
            includeTimestamp: true
        )

        XCTAssertEqual(request.markdown, "---\n\nWith time")
        XCTAssertFalse(request.noTimeStamp)
    }

    func test_customSeparator_isUsedVerbatim() {
        let request = PayloadBuilder.buildDailyNoteRequest(
            text: "Custom",
            useSeparator: true,
            separatorString: "***\n",
            includeTimestamp: false
        )

        XCTAssertEqual(request.markdown, "***\nCustom")
    }

    func test_lateEveningWestOfUTC_usesLocalDay() {
        // 2026-11-03 23:30 at UTC-3 is already 2026-11-04 in UTC.
        let now = ISO8601DateFormatter().date(from: "2026-11-04T02:30:00Z")!
        let request = PayloadBuilder.buildDailyNoteRequest(
            text: "Late",
            useSeparator: false,
            separatorString: "",
            includeTimestamp: false,
            now: now,
            timeZone: TimeZone(secondsFromGMT: -3 * 3600)!
        )

        XCTAssertEqual(request.date, "2026-11-03T00:00:00.000Z")
    }

    func test_earlyMorningEastOfUTC_usesLocalDay() {
        // 2026-11-04 01:00 at UTC+9 is still 2026-11-03 in UTC.
        let now = ISO8601DateFormatter().date(from: "2026-11-03T16:00:00Z")!
        let date = PayloadBuilder.dailyNoteDate(for: now, in: TimeZone(secondsFromGMT: 9 * 3600)!)

        XCTAssertEqual(date, "2026-11-04T00:00:00.000Z")
    }
}
