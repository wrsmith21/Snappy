import AVFoundation
import CoreGraphics
import SnappyCore
import UIKit

/// Turns a snap into a square MP4: the clip's audio over a card with cover art, credits and a
/// progress bar. Social apps like LinkedIn take video but not bare audio files.
enum ClipVideoMaker {
    /// Shared clips stay short, like other podcast apps' clip sharing.
    static let maxLength: TimeInterval = 60

    /// Where the progress bar sits on the 1080×1080 card, in top-left coordinates.
    static let progressBar = CGRect(x: 120, y: 916, width: 840, height: 16)

    private static let framesPerSecond: Int32 = 10
    private static let size = Int(ClipCardView.size)

    enum Failure: LocalizedError {
        case audio(String)
        case video(String)

        var errorDescription: String? {
            switch self {
            case .audio(let reason): "Couldn't get the clip's audio. \(reason)"
            case .video(let reason): "Couldn't make the video. \(reason)"
            }
        }
    }

    /// Builds the video for `range` of `snap` over `card`, reporting progress from 0 to 1.
    static func makeVideo(
        for snap: Snap,
        range: ClipWindow,
        card: CGImage,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        let audioURL = try await clipAudio(for: snap.episode, range: range)
        defer { try? FileManager.default.removeItem(at: audioURL) }
        progress(0.3)

        let videoURL = FileManager.default.temporaryDirectory.appending(path: fileName(for: snap))
        try? FileManager.default.removeItem(at: videoURL)
        try await writeVideo(to: videoURL, card: card, audioURL: audioURL, length: range.end - range.start) { fraction in
            progress(0.3 + 0.7 * fraction)
        }
        return videoURL
    }

    /// Downloads the episode from the publisher up to just past the clip (the exporter can't cut
    /// from a remote file) and cuts the clip out of it. Falls back to the whole file when the
    /// partial one can't be read, e.g. an M4A whose index sits at the end.
    private static func clipAudio(for episode: Episode, range: ClipWindow) async throws -> URL {
        let partial = try await download(episode, through: range.end)
        defer { try? FileManager.default.removeItem(at: partial.file) }
        do {
            return try await exportAudio(from: partial.file, range: range)
        } catch where partial.isPartial {
            let whole = try await download(episode, through: nil)
            defer { try? FileManager.default.removeItem(at: whole.file) }
            return try await exportAudio(from: whole.file, range: range)
        }
    }

    /// Downloads the episode's audio, or only its first part when `end` is given and the size and
    /// duration are known: enough bytes to reach `end` plus a margin, assuming a steady bitrate.
    private static func download(_ episode: Episode, through end: TimeInterval?) async throws -> (file: URL, isPartial: Bool) {
        let url = episode.audioURL.upgradedToHTTPS
        var request = URLRequest(url: url)
        var isPartial = false

        if let end, let duration = episode.duration, duration > 0, end < duration - 30,
           let total = await contentLength(of: url) {
            let fraction = min(1, (end + 20) / duration)
            let lastByte = min(total - 1, Int64(Double(total) * fraction * 1.05) + 512 * 1024)
            if lastByte < total - 1 {
                request.setValue("bytes=0-\(lastByte)", forHTTPHeaderField: "Range")
                isPartial = true
            }
        }

        let (downloaded, response) = try await URLSession.shared.download(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            try? FileManager.default.removeItem(at: downloaded)
            throw Failure.audio("The podcast's server didn't send the audio.")
        }
        // A server that ignores Range sends the whole file.
        if http.statusCode == 200 { isPartial = false }

        let file = FileManager.default.temporaryDirectory
            .appending(path: "snappy-\(UUID().uuidString).\(audioExtension(for: url, mimeType: response.mimeType))")
        try FileManager.default.moveItem(at: downloaded, to: file)
        return (file, isPartial)
    }

    private static func contentLength(of url: URL) async -> Int64? {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        let result = try? await URLSession.shared.data(for: request)
        guard let length = result?.1.expectedContentLength, length > 0 else { return nil }
        return length
    }

    /// AVFoundation picks the parser from the file extension.
    private static func audioExtension(for url: URL, mimeType: String?) -> String {
        let known = ["mp3", "m4a", "mp4", "aac", "wav"]
        if known.contains(url.pathExtension.lowercased()) { return url.pathExtension.lowercased() }
        switch mimeType?.lowercased() {
        case "audio/mp4", "audio/x-m4a", "audio/m4a": return "m4a"
        case "audio/aac", "audio/aacp": return "aac"
        case "audio/wav", "audio/x-wav": return "wav"
        default: return "mp3"
        }
    }

    /// Cuts the clip's stretch out of a local audio file into an M4A.
    private static func exportAudio(from audioFile: URL, range: ClipWindow) async throws -> URL {
        let asset = AVURLAsset(url: audioFile)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw Failure.audio("This episode's audio format isn't supported.")
        }
        let outputURL = FileManager.default.temporaryDirectory.appending(path: "snappy-\(UUID().uuidString).m4a")
        session.outputURL = outputURL
        session.outputFileType = .m4a
        session.timeRange = CMTimeRange(
            start: CMTime(seconds: range.start, preferredTimescale: 600),
            end: CMTime(seconds: range.end, preferredTimescale: 600)
        )
        await session.export()
        guard session.status == .completed else {
            throw Failure.audio(session.error?.localizedDescription ?? "The download didn't finish.")
        }
        return outputURL
    }

    private static func writeVideo(
        to outputURL: URL,
        card: CGImage,
        audioURL: URL,
        length: TimeInterval,
        progress: (Double) -> Void
    ) async throws {
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size,
            AVVideoHeightKey: size,
        ])
        videoInput.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: size,
            kCVPixelBufferHeightKey as String: size,
        ])
        writer.add(videoInput)

        // The exported M4A is already AAC, so its samples pass straight through.
        let audioAsset = AVURLAsset(url: audioURL)
        guard let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first else {
            throw Failure.audio("The clip has no sound.")
        }
        let reader = try AVAssetReader(asset: audioAsset)
        let audioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
        reader.add(audioOutput)
        let formatHint = try await audioTrack.load(.formatDescriptions).first
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil, sourceFormatHint: formatHint)
        audioInput.expectsMediaDataInRealTime = false
        writer.add(audioInput)

        guard writer.startWriting(), reader.startReading() else {
            throw Failure.video(writer.error?.localizedDescription ?? reader.error?.localizedDescription ?? "")
        }
        writer.startSession(atSourceTime: .zero)

        let frameCount = max(1, Int((length * Double(framesPerSecond)).rounded(.up)))
        var frame = 0
        var videoDone = false
        var audioDone = false

        // Feed both tracks in turn: the writer interleaves them and stalls one that runs ahead.
        while !(videoDone && audioDone) {
            var fedSomething = false

            if !videoDone, videoInput.isReadyForMoreMediaData {
                if frame < frameCount {
                    let fraction = frameCount > 1 ? Double(frame) / Double(frameCount - 1) : 1
                    guard let pool = adaptor.pixelBufferPool, let buffer = makeFrame(card: card, progress: fraction, pool: pool) else {
                        throw Failure.video("Couldn't draw a frame.")
                    }
                    adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: framesPerSecond))
                    frame += 1
                    progress(Double(frame) / Double(frameCount))
                } else {
                    videoInput.markAsFinished()
                    videoDone = true
                }
                fedSomething = true
            }

            if !audioDone, audioInput.isReadyForMoreMediaData {
                if let sample = audioOutput.copyNextSampleBuffer() {
                    audioInput.append(sample)
                } else {
                    if reader.status == .failed {
                        throw Failure.audio(reader.error?.localizedDescription ?? "")
                    }
                    audioInput.markAsFinished()
                    audioDone = true
                }
                fedSomething = true
            }

            if writer.status == .failed {
                throw Failure.video(writer.error?.localizedDescription ?? "")
            }
            if !fedSomething {
                try await Task.sleep(for: .milliseconds(5))
            }
        }

        await writer.finishWriting()
        guard writer.status == .completed else {
            throw Failure.video(writer.error?.localizedDescription ?? "")
        }
    }

    /// One video frame: the card with the progress bar filled to `progress`.
    private static func makeFrame(card: CGImage, progress: Double, pool: CVPixelBufferPool) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        guard let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        let canvas = CGRect(x: 0, y: 0, width: size, height: size)
        context.draw(card, in: canvas)

        // Core Graphics counts y from the bottom.
        var track = progressBar
        track.origin.y = CGFloat(size) - progressBar.maxY
        let radius = track.height / 2
        context.addPath(CGPath(roundedRect: track, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.setFillColor(UIColor.white.withAlphaComponent(0.25).cgColor)
        context.fillPath()

        var filled = track
        filled.size.width = max(track.height, track.width * min(max(progress, 0), 1))
        context.addPath(CGPath(roundedRect: filled, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.setFillColor(UIColor(red: 0xC9 / 255, green: 0xF2 / 255, blue: 0x6B / 255, alpha: 1).cgColor)
        context.fillPath()

        return buffer
    }

    private static func fileName(for snap: Snap) -> String {
        let unsafe = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let title = snap.episode.title.components(separatedBy: unsafe).joined(separator: " ")
        return "\(String(title.prefix(60))) – Snappy.mp4"
    }
}
