import SnappyCore
import SwiftUI

/// Search for a show, then pick an episode to play.
struct ListenView: View {
    @State private var query = ""
    @State private var results: [Podcast] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List(results) { podcast in
                NavigationLink(value: podcast) {
                    PodcastRow(podcast: podcast)
                }
                .accessibilityIdentifier("podcast")
            }
            .overlay {
                if isSearching && results.isEmpty {
                    ProgressView()
                } else if let errorMessage {
                    ContentUnavailableView("Search failed", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                } else if results.isEmpty && query.isEmpty {
                    ContentUnavailableView(
                        "Find a podcast",
                        systemImage: "magnifyingglass",
                        description: Text("Search for a show, start listening, and press Snap when you hear something worth keeping.")
                    )
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationTitle("Listen")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search podcasts")
            .task(id: query) { await search() }
            .navigationDestination(for: Podcast.self) { ShowView(podcast: $0) }
            .withPlayerBar()
        }
    }

    private func search() async {
        let term = query.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else {
            results = []
            errorMessage = nil
            return
        }

        // Wait for typing to pause; a new keystroke cancels this task.
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }

        isSearching = true
        defer { isSearching = false }
        do {
            let found = try await PodcastDirectory.search(term)
            guard !Task.isCancelled else { return }
            results = found
            errorMessage = nil
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
}

private struct PodcastRow: View {
    let podcast: Podcast

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: podcast.artworkURL, size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(podcast.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(podcast.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
