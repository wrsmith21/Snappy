import XCTest
@testable import SnappyCore

final class TimecodeTests: XCTestCase {
    func testFormatsMinutesAndHours() {
        XCTAssertEqual(Timecode.string(0), "0:00")
        XCTAssertEqual(Timecode.string(65.9), "1:05")
        XCTAssertEqual(Timecode.string(3723), "1:02:03")
        XCTAssertEqual(Timecode.string(.nan), "0:00")
    }

    func testParsesItunesDurations() {
        XCTAssertEqual(Timecode.parse("3723"), 3723)
        XCTAssertEqual(Timecode.parse("62:03"), 3723)
        XCTAssertEqual(Timecode.parse("1:02:03"), 3723)
        XCTAssertEqual(Timecode.parse(" 90.5 "), 90.5)
    }

    func testRejectsGarbage() {
        XCTAssertNil(Timecode.parse(""))
        XCTAssertNil(Timecode.parse("abc"))
        XCTAssertNil(Timecode.parse("1:2:3:4"))
        XCTAssertNil(Timecode.parse("1::3"))
        XCTAssertNil(Timecode.parse("-5"))
    }
}
