import XCTest

/// Walks through the main flow against live podcast data, attaching a screenshot of each screen.
/// Needs network access (iTunes Search API and the show's RSS feed / audio).
final class SnapFlowUITests: XCTestCase {
    @MainActor
    func testSearchListenSnapAndReplay() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        screenshot("01-listen", of: app)

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Radiolab\n")

        let podcast = app.descendants(matching: .any).matching(identifier: "podcast").firstMatch
        XCTAssertTrue(podcast.waitForExistence(timeout: 30), "No search results")
        pause(3)
        screenshot("02-search-results", of: app)
        podcast.tap()

        let episodes = app.buttons.matching(identifier: "episode")
        XCTAssertTrue(episodes.firstMatch.waitForExistence(timeout: 30), "Feed didn't load")
        pause(3)
        screenshot("03-show", of: app)

        // Listen for a bit, then snap.
        episodes.element(boundBy: 0).tap()
        let snapButton = app.buttons["snap"]
        XCTAssertTrue(snapButton.waitForExistence(timeout: 10))
        pause(25)
        screenshot("04-playing", of: app)
        snapButton.tap()
        screenshot("05-snapped", of: app)

        // A second snap from another episode, so the gallery has some variety.
        episodes.element(boundBy: 1).tap()
        pause(15)
        snapButton.tap()
        pause(3)

        app.tabBars.buttons["Snaps"].tap()
        let playSnap = app.buttons.matching(identifier: "playSnap")
        XCTAssertTrue(playSnap.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(playSnap.count, 2)
        pause(3)
        screenshot("06-snaps", of: app)

        playSnap.element(boundBy: 1).tap()
        pause(4)
        screenshot("07-replaying-snap", of: app)

        app.navigationBars.buttons["Settings"].tap()
        pause(2)
        screenshot("08-settings", of: app)
    }

    @MainActor
    private func screenshot(_ name: String, of app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Lets playback run or artwork load before the next step.
    private func pause(_ seconds: TimeInterval) {
        let never = expectation(description: "pause")
        never.isInverted = true
        wait(for: [never], timeout: seconds)
    }
}
