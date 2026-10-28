import SnappyCore
import SwiftUI

/// Makes a video of a snap and hands it to the share sheet, with the caption (credit and
/// link) copied so it can be pasted into apps that ignore shared text, like LinkedIn.
struct ClipShareSheet: View {
    let snap: Snap

    @Environment(\.dismiss) private var dismiss
    @State private var phase = Phase.working(0)
    @State private var attempt = 0

    private enum Phase {
        case working(Double)
        case ready(video: URL, preview: UIImage)
        case failed(String)
    }

    private var range: ClipWindow { snap.sharedRange(maxLength: ClipVideoMaker.maxLength) }
    private var isTrimmed: Bool { range.end < snap.end }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    switch phase {
                    case .working(let fraction):
                        ProgressView(value: fraction) {
                            Text("Making your clip…")
                        } currentValueLabel: {
                            Text("Getting the audio from \(snap.podcast.title) and adding the cover and credits.")
                        }
                        .padding(.top, 40)

                    case .ready(let video, let preview):
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .accessibilityLabel("Clip preview")

                        ShareLink(item: video, message: Text(snap.shareCaption)) {
                            Label("Share Video", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Label("Caption with the link copied. Paste it into your post.", systemImage: "doc.on.clipboard")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if isTrimmed {
                            Text("Shared videos use the first \(Int(ClipVideoMaker.maxLength)) seconds of the snap.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                    case .failed(let message):
                        ContentUnavailableView {
                            Label("Couldn't make the clip", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text(message)
                        } actions: {
                            Button("Try Again") { attempt += 1 }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Share Clip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
        .task(id: attempt) { await makeClip() }
    }

    @MainActor
    private func makeClip() async {
        phase = .working(0)
        let cover = await loadCover()

        let renderer = ImageRenderer(content: ClipCardView(snap: snap, range: range, cover: cover))
        renderer.scale = 1
        guard let card = renderer.uiImage, let cgCard = card.cgImage else {
            phase = .failed("Couldn't draw the cover card.")
            return
        }

        do {
            let video = try await ClipVideoMaker.makeVideo(for: snap, range: range, card: cgCard) { fraction in
                Task { @MainActor in
                    if case .working = phase { phase = .working(fraction) }
                }
            }
            UIPasteboard.general.string = snap.shareCaption
            phase = .ready(video: video, preview: card)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func loadCover() async -> UIImage? {
        guard let url = snap.artworkURL?.upgradedToHTTPS else { return nil }
        let response = try? await URLSession.shared.data(from: url)
        return response.flatMap { UIImage(data: $0.0) }
    }
}
