import XCTest
@testable import SnappyCore

final class RSSParserTests: XCTestCase {
    private let feedURL = URL(string: "https://example.com/feed.xml")!

    private let sampleFeed = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
      <channel>
        <title>The Example Show</title>
        <link>https://example.com</link>
        <itunes:author>Jane Host</itunes:author>
        <itunes:image href="https://example.com/show.jpg"/>
        <image>
          <title>Not the show title</title>
          <url>https://example.com/rss-image.jpg</url>
        </image>
        <item>
          <title><![CDATA[Episode 2: Tom & Jerry]]></title>
          <guid isPermaLink="false">ep-2</guid>
          <link>https://example.com/episodes/2</link>
          <pubDate>Tue, 20 Oct 2026 08:00:00 +0000</pubDate>
          <itunes:duration>1:02:03</itunes:duration>
          <itunes:image href="https://example.com/ep2.jpg"/>
          <enclosure url="https://cdn.example.com/ep2.mp3" length="123" type="audio/mpeg"/>
        </item>
        <item>
          <title>Episode 1</title>
          <itunes:duration>1800</itunes:duration>
          <enclosure url="https://cdn.example.com/ep1.mp3" type="audio/mpeg"/>
        </item>
        <item>
          <title>Trailer with no audio</title>
          <guid>no-audio</guid>
        </item>
      </channel>
    </rss>
    """

    func testParsesShowDetails() throws {
        let feed = try RSSParser.parse(Data(sampleFeed.utf8), feedURL: feedURL)

        XCTAssertEqual(feed.podcast.title, "The Example Show")
        XCTAssertEqual(feed.podcast.author, "Jane Host")
        XCTAssertEqual(feed.podcast.feedURL, feedURL)
        XCTAssertEqual(feed.podcast.artworkURL, URL(string: "https://example.com/show.jpg"))
    }

    func testParsesEpisodesAndSkipsOnesWithoutAudio() throws {
        let feed = try RSSParser.parse(Data(sampleFeed.utf8), feedURL: feedURL)
        XCTAssertEqual(feed.episodes.count, 2)

        let latest = feed.episodes[0]
        XCTAssertEqual(latest.guid, "ep-2")
        XCTAssertEqual(latest.title, "Episode 2: Tom & Jerry")
        XCTAssertEqual(latest.audioURL, URL(string: "https://cdn.example.com/ep2.mp3"))
        XCTAssertEqual(latest.webURL, URL(string: "https://example.com/episodes/2"))
        XCTAssertEqual(latest.artworkURL, URL(string: "https://example.com/ep2.jpg"))
        XCTAssertEqual(latest.duration, 3723)
        XCTAssertEqual(latest.publishedAt, Date(timeIntervalSince1970: 1_792_483_200))
    }

    func testFallsBackToEnclosureForMissingGuid() throws {
        let feed = try RSSParser.parse(Data(sampleFeed.utf8), feedURL: feedURL)
        let first = feed.episodes[1]

        XCTAssertEqual(first.guid, "https://cdn.example.com/ep1.mp3")
        XCTAssertEqual(first.duration, 1800)
        XCTAssertNil(first.webURL)
        XCTAssertNil(first.artworkURL)
    }

    func testFillsGapsFromSearchResult() throws {
        let minimal = """
        <rss version="2.0"><channel><title>Bare</title>
        <item><title>One</title><enclosure url="https://cdn.example.com/1.mp3"/></item>
        </channel></rss>
        """
        let fromSearch = Podcast(
            title: "Bare (search)",
            author: "Searched Author",
            feedURL: feedURL,
            artworkURL: URL(string: "https://example.com/search-art.jpg"),
            storeURL: URL(string: "https://podcasts.apple.com/us/podcast/bare/id1")
        )

        let feed = try RSSParser.parse(Data(minimal.utf8), feedURL: feedURL, fallback: fromSearch)

        XCTAssertEqual(feed.podcast.title, "Bare")
        XCTAssertEqual(feed.podcast.author, "Searched Author")
        XCTAssertEqual(feed.podcast.artworkURL, fromSearch.artworkURL)
        XCTAssertEqual(feed.podcast.storeURL, fromSearch.storeURL)
    }

    func testUsesRSSImageWhenThereIsNoItunesImage() throws {
        let feedXML = """
        <rss version="2.0"><channel><title>Show</title>
        <image><url>https://example.com/rss.jpg</url><title>Ignored</title></image>
        </channel></rss>
        """
        let feed = try RSSParser.parse(Data(feedXML.utf8), feedURL: feedURL)

        XCTAssertEqual(feed.podcast.title, "Show")
        XCTAssertEqual(feed.podcast.artworkURL, URL(string: "https://example.com/rss.jpg"))
    }

    func testRejectsNonFeeds() {
        XCTAssertThrowsError(try RSSParser.parse(Data("<html><body>hi</body></html>".utf8), feedURL: feedURL)) { error in
            XCTAssertEqual(error as? RSSParserError, .notAPodcastFeed)
        }
        XCTAssertThrowsError(try RSSParser.parse(Data("not xml".utf8), feedURL: feedURL))
    }

    func testUpgradesHTTPToHTTPS() {
        XCTAssertEqual(URL(string: "http://example.com/a?b=1")!.upgradedToHTTPS, URL(string: "https://example.com/a?b=1"))
        XCTAssertEqual(URL(string: "https://example.com/a")!.upgradedToHTTPS, URL(string: "https://example.com/a"))
    }
}
