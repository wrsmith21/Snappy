import SnappyCore
import SwiftUI

struct ArtworkView: View {
    let url: URL?
    var size: CGFloat = 56

    var body: some View {
        AsyncImage(url: url?.upgradedToHTTPS) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(.quaternary)
                    Image(systemName: "waveform").foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
    }
}
