import SnappyCore
import SwiftUI

struct ContentView: View {
    @Environment(PlayerController.self) private var player

    var body: some View {
        TabView {
            ListenView()
                .tabItem { Label("Listen", systemImage: "headphones") }
            SnapsView()
                .tabItem { Label("Snaps", systemImage: "waveform.badge.plus") }
        }
        .overlay(alignment: .top) {
            if let snap = player.lastSnap {
                SnapToast(snap: snap)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: player.lastSnap?.id)
        .task(id: player.lastSnap?.id) {
            guard player.lastSnap != nil else { return }
            try? await Task.sleep(for: .seconds(2.5))
            if !Task.isCancelled { player.lastSnap = nil }
        }
    }
}

/// Brief confirmation that a snap was saved, like the screenshot thumbnail.
private struct SnapToast: View {
    let snap: Snap

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: snap.artworkURL, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Snapped \(snap.timeRangeText)")
                    .font(.subheadline.weight(.semibold))
                Text(snap.episode.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 8, y: 4)
        .padding(.horizontal)
    }
}

extension View {
    /// Pins the mini player above the tab bar.
    func withPlayerBar() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) { PlayerBar() }
    }
}
