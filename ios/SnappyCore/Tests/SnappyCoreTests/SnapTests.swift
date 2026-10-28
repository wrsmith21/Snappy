import XCTest
@testable import SnappyCore

final class SnapTests: XCTestCase {
    private let feedURL = URL(string: "https://example.com/feed.xml")!

    private func makeSnap(author: String = "Jane Host", webURL: URL? = nil, storeURL: URL? = nil) -> Snap {
        Snap(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            podcast: Podcast(
                title: "The Example Show",
                author: author,
                feedURL: feedURL,
                artworkURL: URL(string: "https://example.com/show.jpg"),
                storeURL: storeURL
            ),
            episode: Episode(
                guid: "ep-1",
                title: "Pilot",
                audioURL: URL(string: "https://cdn.example.com/ep1.mp3")!,
                webURL: webURL
            ),
            start: 724,
            end: 754
        )
    }

    func testShareTextCreditsTheShow() {
        XCTAssertEqual(makeSnap().shareText, "🎧 “Pilot” — The Example Show · Jane Host [12:04–12:34]")
        XCTAssertEqual(makeSnap(author: "").creditLine, "The Example Show")
        XCTAssertEqual(makeSnap(author: "The Example Show").creditLine, "The Example Show")
    }

    func testSourcePrefersEpisodePageThenStoreThenFeed() {
        let episodePage = URL(string: "https://example.com/episodes/1")!
        let store = URL(string: "https://podcasts.apple.com/us/podcast/x/id1")!

        XCTAssertEqual(makeSnap(webURL: episodePage, storeURL: store).sourceURL, episodePage)
        XCTAssertEqual(makeSnap(storeURL: store).sourceURL, store)
        XCTAssertEqual(makeSnap().sourceURL, feedURL)
    }

    func testShareCaptionCarriesTheLink() {
        let snap = makeSnap(webURL: URL(string: "https://example.com/episodes/1"))
        XCTAssertEqual(
            snap.shareCaption,
            "🎧 “Pilot” — The Example Show · Jane Host [12:04–12:34]\nListen to the full episode: https://example.com/episodes/1"
        )
    }

    func testSharedRangeIsCapped() {
        let snap = makeSnap()
        XCTAssertEqual(snap.sharedRange(maxLength: 60), ClipWindow(start: 724, end: 754))
        XCTAssertEqual(snap.sharedRange(maxLength: 10), ClipWindow(start: 724, end: 734))
    }

    func testArtworkFallsBackToShow() {
        XCTAssertEqual(makeSnap().artworkURL, URL(string: "https://example.com/show.jpg"))
        XCTAssertEqual(makeSnap().length, 30)
    }

    func testArchiveRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let archive = SnapArchive(fileURL: directory.appendingPathComponent("nested/snaps.json"))

        XCTAssertEqual(try archive.load(), [])

        let snaps = [makeSnap(webURL: URL(string: "https://example.com/episodes/1"))]
        try archive.save(snaps)
        XCTAssertEqual(try archive.load(), snaps)

        try archive.save([])
        XCTAssertEqual(try archive.load(), [])
    }
}
