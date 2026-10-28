import SnappyCore
import SwiftUI

/// The gallery of saved snaps.
struct SnapsView: View {
    @Environment(SnapLibrary.self) private var library
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(library.snaps) { snap in
                    SnapRow(snap: snap)
                }
                .onDelete { library.delete(at: $0) }
            }
            .overlay {
                if library.snaps.isEmpty {
                    ContentUnavailableView(
                        "No snaps yet",
                        systemImage: "waveform.badge.plus",
                        description: Text("While an episode plays, press Snap where you want the clip to start and Stop where it ends. Double-tapping your AirPods or the Action Button work too.")
                    )
                }
            }
            .navigationTitle("Snaps")
            .toolbar {
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
        }
        .withPlayerBar()
    }
}

private struct SnapRow: View {
    let snap: Snap

    @Environment(PlayerController.self) private var player

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ArtworkView(url: snap.artworkURL, size: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(snap.episode.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(snap.creditLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\(snap.timeRangeText) · \(snap.createdAt.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 28) {
                    Button { player.playClip(snap) } label: {
                        Label("Play", systemImage: "play.circle.fill")
                    }
                    .accessibilityIdentifier("playSnap")
                    ShareLink(item: snap.sourceURL, message: Text(snap.shareText)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Link(destination: snap.sourceURL) {
                        Label("Source", systemImage: "arrow.up.right.square")
                    }
                }
                .labelStyle(.iconOnly)
                .font(.title3)
                // Separate tap targets inside a List row.
                .buttonStyle(.borderless)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}
