import SnappyCore
import SwiftUI

/// Mini player with the Snap button, shown whenever an episode is loaded.
struct PlayerBar: View {
    @Environment(PlayerController.self) private var player

    var body: some View {
        if let episode = player.episode, let podcast = player.podcast {
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .tint(player.clipEnd == nil ? Color.accentColor : Color.orange)

                HStack(spacing: 12) {
                    ArtworkView(url: episode.artworkURL ?? podcast.artworkURL, size: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(episode.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        if player.clipEnd != nil {
                            Button("Keep listening ›") { player.keepListening() }
                                .font(.caption)
                                .lineLimit(1)
                                .buttonStyle(.borderless)
                        } else {
                            Text("\(Timecode.string(player.currentTime)) · \(podcast.title)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    Button { player.skip(by: -15) } label: {
                        Image(systemName: "gobackward.15")
                    }
                    .accessibilityLabel("Back 15 seconds")

                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .frame(width: 24)
                    }
                    .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

                    SnapButton()
                }
                .font(.title3)
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    private var progress: Double {
        guard let duration = player.duration, duration > 0 else { return 0 }
        return min(1, player.currentTime / duration)
    }
}

/// The app's "shutter": saves the last few seconds of what's playing.
struct SnapButton: View {
    @Environment(PlayerController.self) private var player

    var body: some View {
        Button { _ = player.snap() } label: {
            Label("Snap", systemImage: "waveform.badge.plus")
                .font(.subheadline.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.accentColor, in: Capsule())
                // White on the dark green accent in light mode, black on the brighter one in dark mode.
                .foregroundStyle(Color(uiColor: .systemBackground))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("snap")
        .accessibilityHint("Saves the last few seconds of this episode")
    }
}
