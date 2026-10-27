import XCTest
@testable import SnappyCore

final class PodcastDirectoryTests: XCTestCase {
    func testBuildsSearchURL() throws {
        let url = PodcastDirectory.searchURL(for: "c++ & rock", limit: 10)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))

        XCTAssertEqual(components.host, "itunes.apple.com")
        XCTAssertEqual(components.path, "/search")
        XCTAssertEqual(components.queryItems?.first { $0.name == "term" }?.value, "c++ & rock")
        XCTAssertEqual(components.queryItems?.first { $0.name == "media" }?.value, "podcast")
        XCTAssertEqual(components.queryItems?.first { $0.name == "limit" }?.value, "10")
        XCTAssertTrue(url.absoluteString.contains("c%2B%2B"), url.absoluteString)
    }

    func testDecodesResultsAndSkipsOnesWithoutFeeds() throws {
        let json = """
        {
          "resultCount": 2,
          "results": [
            {
              "collectionName": "Hard Fork",
              "artistName": "The New York Times",
              "feedUrl": "https://feeds.simplecast.com/l2i9YnTd",
              "artworkUrl100": "https://is1.mzstatic.com/100.jpg",
              "artworkUrl600": "https://is1.mzstatic.com/600.jpg",
              "collectionViewUrl": "https://podcasts.apple.com/us/podcast/hard-fork/id1528594034"
            },
            { "collectionName": "No Feed Show", "artistName": "Someone" }
          ]
        }
        """

        let podcasts = try PodcastDirectory.decodeSearchResults(Data(json.utf8))

        XCTAssertEqual(podcasts, [
            Podcast(
                title: "Hard Fork",
                author: "The New York Times",
                feedURL: URL(string: "https://feeds.simplecast.com/l2i9YnTd")!,
                artworkURL: URL(string: "https://is1.mzstatic.com/600.jpg"),
                storeURL: URL(string: "https://podcasts.apple.com/us/podcast/hard-fork/id1528594034")
            ),
        ])
    }
}
