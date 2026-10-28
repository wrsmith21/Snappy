import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Finds shows through the public iTunes Search API and loads their feeds.
public enum PodcastDirectory {
    public static func searchURL(for term: String, limit: Int = 25) -> URL {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "media", value: "podcast"),
            URLQueryItem(name: "entity", value: "podcast"),
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        // URLComponents leaves "+" alone, which the server would read as a space.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return components.url!
    }

    /// Decodes an iTunes Search API response, skipping results that have no feed.
    public static func decodeSearchResults(_ data: Data) throws -> [Podcast] {
        try JSONDecoder().decode(SearchResponse.self, from: data).results.compactMap(\.podcast)
    }

    public static func search(_ term: String, session: URLSession = .shared) async throws -> [Podcast] {
        let data = try await fetch(searchURL(for: term), session: session)
        return try decodeSearchResults(data)
    }

    public static func loadFeed(for podcast: Podcast, session: URLSession = .shared) async throws -> Feed {
        let data = try await fetch(podcast.feedURL.upgradedToHTTPS, session: session)
        return try RSSParser.parse(data, feedURL: podcast.feedURL, fallback: podcast)
    }

    private static func fetch(_ url: URL, session: URLSession) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private struct SearchResponse: Decodable {
        var results: [SearchResult]
    }

    private struct SearchResult: Decodable {
        var collectionName: String?
        var artistName: String?
        var feedUrl: String?
        var artworkUrl600: String?
        var artworkUrl100: String?
        var collectionViewUrl: String?

        var podcast: Podcast? {
            guard let name = collectionName, let feedURL = URL.lenient(feedUrl) else { return nil }
            return Podcast(
                title: name,
                author: artistName ?? "",
                feedURL: feedURL,
                artworkURL: URL.lenient(artworkUrl600 ?? artworkUrl100),
                storeURL: URL.lenient(collectionViewUrl)
            )
        }
    }
}
