import SnappyCore
import SwiftUI

/// Mini player with the Snap button, shown whenever an episode is loaded.
struct PlayerBar: View {
    @Environment(PlayerController.self) private var player

    var body: some View {
        if let episode = player.episode, let podcast = player.podcast {
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .tint(progressTint)

                HStack(spacing: 12) {
                    ArtworkView(url: episode.artworkURL ?? podcast.artworkURL, size: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(episode.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        if let start = player.snapStart {
                            Label("Snapping from \(Timecode.string(start))", systemImage: "record.circle")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.snapRecording)
                                .lineLimit(1)
                        } else if player.clipEnd != nil {
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

    private var progressTint: Color {
        if player.isSnapping { return .snapRecording }
        return player.clipEnd == nil ? .accentColor : .orange
    }
}

/// The app's "shutter": press to start a snap, press again to stop and save it.
struct SnapButton: View {
    @Environment(PlayerController.self) private var player

    var body: some View {
        Button { _ = player.toggleSnap() } label: {
            label
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(player.isSnapping ? Color.snapRecording : Color.accentColor, in: Capsule())
                // On the green accent: white in light mode, black on the brighter dark-mode green.
                .foregroundStyle(player.isSnapping ? Color.white : Color(uiColor: .systemBackground))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if player.isSnapping {
                Button("Discard Snap", systemImage: "trash", role: .destructive) { player.cancelSnap() }
            }
        }
        .accessibilityIdentifier("snap")
        .accessibilityHint(player.isSnapping ? "Saves the snap" : "Starts a snap from this moment")
    }

    @ViewBuilder
    private var label: some View {
        if let start = player.snapStart {
            Label("Stop \(Timecode.string(max(0, player.currentTime - start)))", systemImage: "stop.fill")
        } else {
            Label("Snap", systemImage: "waveform.badge.plus")
        }
    }
}

extension Color {
    /// Deep red for a snap in progress; white text on it passes contrast in light and dark mode.
    static let snapRecording = Color(red: 0.70, green: 0.15, blue: 0.12)
}
