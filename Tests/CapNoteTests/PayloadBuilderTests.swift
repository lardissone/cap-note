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

    func test_localDay_usesCalendarDateLabelAcrossTimeZones() {
        let cases = [
            ("2026-10-11T21:30:00Z", "Europe/Istanbul", "2026-10-12T00:00:00.000Z"),
            ("2026-10-12T02:00:00Z", "America/Los_Angeles", "2026-10-11T00:00:00.000Z"),
            ("2026-03-08T09:30:00Z", "America/Los_Angeles", "2026-03-08T00:00:00.000Z"),
            ("2026-03-08T10:30:00Z", "America/Los_Angeles", "2026-03-08T00:00:00.000Z"),
            ("2026-12-31T21:30:00Z", "Europe/Istanbul", "2027-01-01T00:00:00.000Z"),
            ("2026-10-12T00:00:00Z", "UTC", "2026-10-12T00:00:00.000Z")
        ]
        for (instant, zone, expected) in cases {
            let request = PayloadBuilder.buildDailyNoteRequest(
                text: "Günlük not 📝\nİkinci satır", useSeparator: false,
                separatorString: "", includeTimestamp: false,
                now: ISO8601DateFormatter().date(from: instant)!,
                timeZone: TimeZone(identifier: zone)!
            )
            XCTAssertEqual(request.date, expected, "Day for \(instant) in \(zone)")
            XCTAssertEqual(request.markdown, "Günlük not 📝\nİkinci satır")
        }
    }
}
