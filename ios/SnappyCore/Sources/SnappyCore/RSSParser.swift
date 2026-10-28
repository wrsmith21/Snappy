import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

public struct Feed: Hashable, Sendable {
    public var podcast: Podcast
    public var episodes: [Episode]

    public init(podcast: Podcast, episodes: [Episode]) {
        self.podcast = podcast
        self.episodes = episodes
    }
}

public enum RSSParserError: Error, Equatable {
    case notAPodcastFeed
}

public enum RSSParser {
    /// Parses a podcast RSS feed. Details the feed leaves out (artwork, Apple Podcasts link)
    /// are filled in from `fallback`, typically the search result that led to the feed.
    public static func parse(_ data: Data, feedURL: URL, fallback: Podcast? = nil) throws -> Feed {
        let delegate = FeedParserDelegate()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.delegate = delegate

        guard parser.parse() else { throw parser.parserError ?? RSSParserError.notAPodcastFeed }
        guard delegate.sawChannel else { throw RSSParserError.notAPodcastFeed }

        let channel = delegate.channel
        let podcast = Podcast(
            title: channel.title ?? fallback?.title ?? feedURL.host() ?? "Podcast",
            author: channel.author ?? fallback?.author ?? "",
            feedURL: feedURL,
            artworkURL: channel.itunesImage ?? channel.rssImage ?? fallback?.artworkURL,
            storeURL: fallback?.storeURL
        )
        return Feed(podcast: podcast, episodes: delegate.items.compactMap(\.episode))
    }
}

private enum Namespace {
    static let none = ""
    static let itunes = "http://www.itunes.com/dtds/podcast-1.0.dtd"
}

private final class FeedParserDelegate: NSObject, XMLParserDelegate {
    struct Element: Equatable {
        var name: String
        var namespace: String

        static let channel = Element(name: "channel", namespace: Namespace.none)
        static let item = Element(name: "item", namespace: Namespace.none)
        static let image = Element(name: "image", namespace: Namespace.none)
    }

    struct Channel {
        var title: String?
        var author: String?
        var itunesImage: URL?
        var rssImage: URL?
    }

    struct Item {
        var title: String?
        var guid: String?
        var link: String?
        var pubDate: String?
        var duration: String?
        var enclosure: URL?
        var itunesImage: URL?

        var episode: Episode? {
            guard let enclosure else { return nil }
            return Episode(
                guid: guid ?? enclosure.absoluteString,
                title: title ?? "Untitled episode",
                audioURL: enclosure,
                webURL: URL.lenient(link),
                artworkURL: itunesImage,
                publishedAt: pubDate.flatMap(RFC822.date),
                duration: duration.flatMap(Timecode.parse)
            )
        }
    }

    private(set) var sawChannel = false
    private(set) var channel = Channel()
    private(set) var items: [Item] = []

    private var currentItem: Item?
    private var stack: [Element] = []
    private var text = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes: [String: String] = [:]
    ) {
        let element = Element(name: elementName, namespace: namespaceURI ?? Namespace.none)
        let parent = stack.last
        stack.append(element)
        text = ""

        switch (element.namespace, element.name) {
        case (Namespace.none, "channel"):
            sawChannel = true
        case (Namespace.none, "item"):
            currentItem = Item()
        case (Namespace.none, "enclosure") where parent == .item:
            currentItem?.enclosure = URL.lenient(attributes["url"])
        case (Namespace.itunes, "image"):
            let url = URL.lenient(attributes["href"])
            if parent == .item {
                currentItem?.itunesImage = url
            } else if parent == .channel {
                channel.itunesImage = url
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(decoding: CDATABlock, as: UTF8.self)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard let element = stack.popLast() else { return }
        let parent = stack.last
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let nonEmpty = value.isEmpty ? nil : value
        text = ""

        let inItem = parent == .item
        let inChannel = parent == .channel

        switch (element.namespace, element.name) {
        case (Namespace.none, "item"):
            if let currentItem { items.append(currentItem) }
            currentItem = nil
        case (Namespace.none, "title") where inItem:
            currentItem?.title = nonEmpty
        case (Namespace.none, "title") where inChannel:
            channel.title = nonEmpty
        case (Namespace.none, "guid") where inItem:
            currentItem?.guid = nonEmpty
        case (Namespace.none, "link") where inItem:
            currentItem?.link = nonEmpty
        case (Namespace.none, "pubDate") where inItem:
            currentItem?.pubDate = nonEmpty
        case (Namespace.itunes, "duration") where inItem:
            currentItem?.duration = nonEmpty
        case (Namespace.itunes, "author") where inChannel:
            channel.author = nonEmpty
        case (Namespace.none, "url") where parent == .image && stack.dropLast().last == .channel:
            channel.rssImage = URL.lenient(nonEmpty)
        default:
            break
        }
    }
}

enum RFC822 {
    private static let formatters: [DateFormatter] = [
        "EEE, d MMM yyyy HH:mm:ss Z",
        "EEE, d MMM yyyy HH:mm:ss zzz",
        "EEE, d MMM yyyy HH:mm Z",
        "d MMM yyyy HH:mm:ss Z",
        "yyyy-MM-dd'T'HH:mm:ssZ",
    ].map { format in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        return formatter
    }

    static func date(_ string: String) -> Date? {
        for formatter in formatters {
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
}

extension URL {
    /// Builds an http(s) URL from feed text, tolerating stray whitespace and unescaped characters.
    static func lenient(_ string: String?) -> URL? {
        guard let trimmed = string?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        let url = URL(string: trimmed)
            ?? trimmed.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed).flatMap(URL.init(string:))
        guard let url, let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        return url
    }

    /// The same URL over https; feeds and artwork are usually served both ways, and iOS blocks plain http.
    public var upgradedToHTTPS: URL {
        guard scheme?.lowercased() == "http", var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }
        components.scheme = "https"
        return components.url ?? self
    }
}
