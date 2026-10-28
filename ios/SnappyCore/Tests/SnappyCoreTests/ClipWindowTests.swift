import XCTest
@testable import SnappyCore

final class ClipWindowTests: XCTestCase {
    func testCoversExactlyFromStartToStop() {
        XCTAssertEqual(ClipWindow.between(724, 761.5), ClipWindow(start: 724, end: 761.5))
    }

    func testAcceptsPointsInEitherOrder() {
        XCTAssertEqual(ClipWindow.between(90, 60), ClipWindow(start: 60, end: 90))
    }

    func testStretchesVeryShortClips() {
        XCTAssertEqual(ClipWindow.between(10, 10.3), ClipWindow(start: 10, end: 11))
        XCTAssertEqual(ClipWindow.between(10, 10), ClipWindow(start: 10, end: 11))
    }

    func testNeverRunsPastTheEnd() {
        XCTAssertEqual(ClipWindow.between(140, 200, episodeDuration: 150), ClipWindow(start: 140, end: 150))
        XCTAssertEqual(ClipWindow.between(149.8, 150, episodeDuration: 150), ClipWindow(start: 149, end: 150))
    }

    func testIgnoresUnknownDuration() {
        XCTAssertEqual(ClipWindow.between(45, 60, episodeDuration: .nan), ClipWindow(start: 45, end: 60))
        XCTAssertEqual(ClipWindow.between(45, 60, episodeDuration: 0), ClipWindow(start: 45, end: 60))
    }

    func testInvalidPositionsStartAtZero() {
        XCTAssertEqual(ClipWindow.between(.nan, -3), ClipWindow(start: 0, end: 1))
    }
}
