import Foundation

/// A podcast show, as found through search or read from its RSS feed.
public struct Podcast: Codable, Hashable, Identifiable, Sendable {
    public var id: URL { feedURL }

    public var title: String
    public var author: String
    public var feedURL: URL
    public var artworkURL: URL?
    /// The show's Apple Podcasts page, when known.
    public var storeURL: URL?

    public init(title: String, author: String, feedURL: URL, artworkURL: URL? = nil, storeURL: URL? = nil) {
        self.title = title
        self.author = author
        self.feedURL = feedURL
        self.artworkURL = artworkURL
        self.storeURL = storeURL
    }
}

/// One episode from a podcast feed.
public struct Episode: Codable, Hashable, Identifiable, Sendable {
    public var id: String { guid }

    public var guid: String
    public var title: String
    public var audioURL: URL
    /// The episode's web page, when the feed provides one.
    public var webURL: URL?
    public var artworkURL: URL?
    public var publishedAt: Date?
    public var duration: TimeInterval?

    public init(
        guid: String,
        title: String,
        audioURL: URL,
        webURL: URL? = nil,
        artworkURL: URL? = nil,
        publishedAt: Date? = nil,
        duration: TimeInterval? = nil
    ) {
        self.guid = guid
        self.title = title
        self.audioURL = audioURL
        self.webURL = webURL
        self.artworkURL = artworkURL
        self.publishedAt = publishedAt
        self.duration = duration
    }
}

/// A saved moment: a short stretch of an episode, with everything needed to credit it and get back to it.
public struct Snap: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var podcast: Podcast
    public var episode: Episode
    /// Clip start, in seconds from the beginning of the episode.
    public var start: TimeInterval
    /// Clip end, in seconds from the beginning of the episode.
    public var end: TimeInterval
    public var note: String?

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        podcast: Podcast,
        episode: Episode,
        start: TimeInterval,
        end: TimeInterval,
        note: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.podcast = podcast
        self.episode = episode
        self.start = start
        self.end = end
        self.note = note
    }

    public var length: TimeInterval { end - start }

    public var artworkURL: URL? { episode.artworkURL ?? podcast.artworkURL }

    /// Where the snap came from: the episode page, else the show's Apple Podcasts page, else its feed.
    public var sourceURL: URL { episode.webURL ?? podcast.storeURL ?? podcast.feedURL }

    /// "Show · Author", or just the show when the author adds nothing.
    public var creditLine: String {
        let author = podcast.author.trimmingCharacters(in: .whitespaces)
        if author.isEmpty || author == podcast.title { return podcast.title }
        return "\(podcast.title) · \(author)"
    }

    /// "12:04–12:34"
    public var timeRangeText: String { "\(Timecode.string(start))–\(Timecode.string(end))" }

    /// Text that goes with the source link when a snap is shared.
    public var shareText: String { "🎧 “\(episode.title)” — \(creditLine) [\(timeRangeText)]" }

    /// Caption for a shared video clip: the credit plus the link, since the video itself can't carry a link.
    public var shareCaption: String { "\(shareText)\nListen to the full episode: \(sourceURL.absoluteString)" }

    /// The part of the snap that goes into a shared video: at most `maxLength` seconds from its start.
    public func sharedRange(maxLength: TimeInterval) -> ClipWindow {
        ClipWindow(start: start, end: min(end, start + maxLength))
    }
}
