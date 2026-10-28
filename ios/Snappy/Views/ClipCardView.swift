import SnappyCore
import SwiftUI

/// The still image behind a shared video clip: cover art, credits and a link back.
/// Rendered at 1080×1080; the progress bar is drawn on top of it frame by frame
/// (see `ClipVideoMaker.progressBar`), so its slot here is left empty.
struct ClipCardView: View {
    let snap: Snap
    let range: ClipWindow
    let cover: UIImage?

    static let size: CGFloat = 1080

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 90)

            coverArt
                .frame(width: 540, height: 540)
                .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))

            Color.clear.frame(height: 40)

            Text(snap.episode.title)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(width: 900, height: 140)

            Text(snap.creditLine)
                .font(.system(size: 36, weight: .medium, design: .rounded))
                .foregroundStyle(Color.cardMint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 900, height: 50)

            // Progress bar slot: y 916–932 (see ClipVideoMaker.progressBar).
            Color.clear.frame(height: 56)
            Color.clear.frame(height: 16)
            Color.clear.frame(height: 12)

            HStack {
                Text(Timecode.string(range.start))
                Spacer()
                Text(Timecode.string(range.end))
            }
            .font(.system(size: 28, weight: .medium, design: .rounded).monospacedDigit())
            .foregroundStyle(.white.opacity(0.75))
            .frame(width: ClipVideoMaker.progressBar.width, height: 36)

            Spacer(minLength: 0)

            HStack(spacing: 14) {
                Image("SnappyMark")
                    .resizable()
                    .frame(width: 44, height: 44)
                Text("Full episode: \(snap.sourceURL.host() ?? snap.podcast.title)  ·  Snapped with Snappy")
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .font(.system(size: 26, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.cardLime)
            .frame(width: 960, height: 50)

            Color.clear.frame(height: 30)
        }
        .frame(width: Self.size, height: Self.size)
        .background(Color.cardInk)
    }

    @ViewBuilder
    private var coverArt: some View {
        if let cover {
            Image(uiImage: cover).resizable().scaledToFill()
        } else {
            ZStack {
                Color.cardMint.opacity(0.25)
                Image(systemName: "waveform")
                    .font(.system(size: 160))
                    .foregroundStyle(Color.cardMint)
            }
        }
    }
}

extension Color {
    static let cardInk = Color(red: 0x13 / 255, green: 0x32 / 255, blue: 0x2A / 255)
    static let cardMint = Color(red: 0x9B / 255, green: 0xE3 / 255, blue: 0xB5 / 255)
    static let cardLime = Color(red: 0xC9 / 255, green: 0xF2 / 255, blue: 0x6B / 255)
}
