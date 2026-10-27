import SnappyCore
import SwiftUI

/// A show's episodes, loaded from its RSS feed.
struct ShowView: View {
    let podcast: Podcast

    @Environment(PlayerController.self) private var player
    @State private var feed: Feed?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    ArtworkView(url: feed?.podcast.artworkURL ?? podcast.artworkURL, size: 96)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(feed?.podcast.title ?? podcast.title)
                            .font(.title3.weight(.semibold))
                        Text(feed?.podcast.author ?? podcast.author)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color.clear)
            }

            if let feed {
                Section("Episodes") {
                    ForEach(feed.episodes) { episode in
                        Button {
                            player.play(episode, of: feed.podcast)
                        } label: {
                            EpisodeRow(episode: episode, isCurrent: player.episode?.guid == episode.guid)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .overlay {
            if let errorMessage {
                ContentUnavailableView("Couldn't load episodes", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if feed == nil {
                ProgressView()
            }
        }
        .navigationTitle(podcast.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            feed = try await PodcastDirectory.loadFeed(for: podcast)
            errorMessage = nil
        } catch {
            if feed == nil { errorMessage = error.localizedDescription }
        }
    }
}

private struct EpisodeRow: View {
    let episode: Episode
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.body.weight(isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                    .lineLimit(2)
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: isCurrent ? "speaker.wave.2.fill" : "play.circle")
                .foregroundStyle(Color.accentColor)
        }
        .contentShape(Rectangle())
    }

    private var details: String {
        [
            episode.publishedAt?.formatted(date: .abbreviated, time: .omitted),
            episode.duration.map(Timecode.string),
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}
