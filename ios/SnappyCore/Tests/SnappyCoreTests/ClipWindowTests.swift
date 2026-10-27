import XCTest
@testable import SnappyCore

final class ClipWindowTests: XCTestCase {
    func testCapturesTheSecondsBeforeThePress() {
        XCTAssertEqual(ClipWindow.ending(at: 100, lookback: 30), ClipWindow(start: 70, end: 100))
    }

    func testStretchesForwardNearTheStart() {
        XCTAssertEqual(ClipWindow.ending(at: 5, lookback: 30), ClipWindow(start: 0, end: 10))
    }

    func testNeverRunsPastTheEnd() {
        XCTAssertEqual(ClipWindow.ending(at: 200, lookback: 30, episodeDuration: 150), ClipWindow(start: 120, end: 150))
    }

    func testVeryShortEpisodeIsCapturedWhole() {
        XCTAssertEqual(ClipWindow.ending(at: 5, lookback: 30, episodeDuration: 8), ClipWindow(start: 0, end: 8))
    }

    func testIgnoresUnknownDuration() {
        XCTAssertEqual(ClipWindow.ending(at: 60, lookback: 15, episodeDuration: .nan), ClipWindow(start: 45, end: 60))
        XCTAssertEqual(ClipWindow.ending(at: 60, lookback: 15, episodeDuration: 0), ClipWindow(start: 45, end: 60))
    }

    func testInvalidPositionStartsAtZero() {
        XCTAssertEqual(ClipWindow.ending(at: .nan, lookback: 30), ClipWindow(start: 0, end: 10))
        XCTAssertEqual(ClipWindow.ending(at: -3, lookback: 30), ClipWindow(start: 0, end: 10))
    }
}
