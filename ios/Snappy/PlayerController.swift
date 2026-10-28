import AVFoundation
import MediaPlayer
import Observation
import SnappyCore
import UIKit

/// Plays podcast episodes and takes snaps of whatever is playing.
@MainActor
@Observable
final class PlayerController {
    static let shared = PlayerController()

    private(set) var podcast: Podcast?
    private(set) var episode: Episode?
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval?
    /// Set while replaying a snap: playback pauses here unless the listener chooses to keep going.
    private(set) var clipEnd: TimeInterval?
    /// Where the snap in progress began; nil when not snapping.
    private(set) var snapStart: TimeInterval?
    /// The most recent snap, shown briefly as a confirmation.
    var lastSnap: Snap?

    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var clipEndObserver: Any?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private var artwork: MPMediaItemArtwork?
    @ObservationIgnored private var artworkTask: Task<Void, Never>?

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, policy: .longFormAudio)
        configureRemoteCommands()
        observePlayer()
    }

    // MARK: - Snapping

    enum SnapAction {
        case started(at: TimeInterval)
        case saved(Snap)
    }

    var isSnapping: Bool { snapStart != nil }

    /// Snapping works like a stopwatch: the first press marks the start, the second saves
    /// everything in between. Returns nil when nothing is loaded.
    @discardableResult
    func toggleSnap() -> SnapAction? {
        if isSnapping {
            return finishSnap().map(SnapAction.saved)
        }
        guard player.currentItem != nil else { return nil }
        let start = currentPosition
        snapStart = start
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        return .started(at: start)
    }

    /// Discards the snap in progress without saving it.
    func cancelSnap() {
        snapStart = nil
    }

    private func finishSnap() -> Snap? {
        guard let start = snapStart, let episode, let podcast else { return nil }
        snapStart = nil

        let window = ClipWindow.between(start, currentPosition, episodeDuration: duration)
        let snap = Snap(podcast: podcast, episode: episode, start: window.start, end: window.end)
        SnapLibrary.shared.add(snap)
        lastSnap = snap
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        return snap
    }

    func setHeadphoneSnapEnabled(_ enabled: Bool) {
        MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = enabled
    }

    // MARK: - Playback

    func play(_ episode: Episode, of podcast: Podcast) {
        clearClipEnd()
        load(episode, of: podcast)
        resume()
    }

    /// Replays a snap, pausing at its end.
    func playClip(_ snap: Snap) {
        cancelSnap()
        load(snap.episode, of: snap.podcast)
        seek(to: snap.start)
        setClipEnd(snap.end)
        resume()
    }

    /// Stops treating playback as a snap replay and carries on with the episode.
    func keepListening() {
        clearClipEnd()
        resume()
    }

    func resume() {
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
        updateNowPlaying()
    }

    func pause() {
        player.pause()
        updateNowPlaying()
    }

    func togglePlayPause() {
        player.timeControlStatus == .paused ? resume() : pause()
    }

    func skip(by seconds: TimeInterval) {
        seek(to: currentPosition + seconds)
    }

    func seek(to time: TimeInterval) {
        var target = max(0, time)
        if let duration { target = min(target, duration) }
        currentTime = target
        let tolerance = CMTime(seconds: 0.5, preferredTimescale: 600)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: tolerance, toleranceAfter: tolerance)
        updateNowPlaying()
    }

    private var currentPosition: TimeInterval {
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? seconds : currentTime
    }

    private func load(_ episode: Episode, of podcast: Podcast) {
        guard episode.guid != self.episode?.guid || player.currentItem == nil else { return }

        // A snap can't span two episodes.
        cancelSnap()
        player.replaceCurrentItem(with: AVPlayerItem(url: episode.audioURL))
        self.episode = episode
        self.podcast = podcast
        duration = episode.duration
        currentTime = 0
        loadArtwork(from: episode.artworkURL ?? podcast.artworkURL)
    }

    private func setClipEnd(_ end: TimeInterval) {
        clearClipEnd()
        clipEnd = end
        let boundary = NSValue(time: CMTime(seconds: end, preferredTimescale: 600))
        clipEndObserver = player.addBoundaryTimeObserver(forTimes: [boundary], queue: .main) { [weak self] in
            MainActor.assumeIsolated {
                self?.pause()
                self?.clearClipEnd()
            }
        }
    }

    private func clearClipEnd() {
        if let clipEndObserver { player.removeTimeObserver(clipEndObserver) }
        clipEndObserver = nil
        clipEnd = nil
    }

    // MARK: - Observation

    private func observePlayer() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated { self?.tick(time) }
        }

        statusObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] _, _ in
            guard let self else { return }
            Task { @MainActor in self.syncPlaybackState() }
        }
    }

    private func tick(_ time: CMTime) {
        if time.seconds.isFinite { currentTime = time.seconds }
        if duration == nil, let seconds = player.currentItem?.duration.seconds, seconds.isFinite, seconds > 0 {
            duration = seconds
            updateNowPlaying()
        }
    }

    private func syncPlaybackState() {
        isPlaying = player.timeControlStatus != .paused
        updateNowPlaying()
    }

    // MARK: - Lock screen, Control Center and headphones

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        handle(center.playCommand) { $0.resume() }
        handle(center.pauseCommand) { $0.pause() }
        handle(center.togglePlayPauseCommand) { $0.togglePlayPause() }

        center.skipForwardCommand.preferredIntervals = [30]
        handle(center.skipForwardCommand) { $0.skip(by: 30) }
        center.skipBackwardCommand.preferredIntervals = [15]
        handle(center.skipBackwardCommand) { $0.skip(by: -15) }

        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = event.positionTime
            Task { @MainActor in self.seek(to: position) }
            return .success
        }

        // The headphones' "next track" gesture (e.g. double-tapping AirPods) starts and stops a snap instead.
        handle(center.nextTrackCommand) { _ = $0.toggleSnap() }
        center.nextTrackCommand.isEnabled = SnapSettings.headphoneSnapEnabled
        center.previousTrackCommand.isEnabled = false
    }

    private func handle(_ command: MPRemoteCommand, perform action: @escaping @MainActor (PlayerController) -> Void) {
        command.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in action(self) }
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let episode, let podcast else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: episode.title,
            MPMediaItemPropertyArtist: podcast.title,
            MPMediaItemPropertyAlbumTitle: podcast.title,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: player.timeControlStatus == .paused ? 0.0 : 1.0,
        ]
        if let duration { info[MPMediaItemPropertyPlaybackDuration] = duration }
        if let artwork { info[MPMediaItemPropertyArtwork] = artwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func loadArtwork(from url: URL?) {
        artworkTask?.cancel()
        artwork = nil
        guard let url else { return }

        artworkTask = Task { [weak self] in
            let response = try? await URLSession.shared.data(from: url.upgradedToHTTPS)
            guard let data = response?.0, let image = UIImage(data: data), !Task.isCancelled else { return }
            self?.artwork = PlayerController.makeArtwork(image)
            self?.updateNowPlaying()
        }
    }

    /// Built outside the main actor: the system asks for artwork images on a background queue.
    nonisolated private static func makeArtwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
}
