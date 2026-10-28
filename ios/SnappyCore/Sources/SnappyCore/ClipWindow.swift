import Foundation

/// The stretch of an episode a snap covers.
public struct ClipWindow: Equatable, Sendable {
    public var start: TimeInterval
    public var end: TimeInterval

    public init(start: TimeInterval, end: TimeInterval) {
        self.start = start
        self.end = end
    }

    /// The clip between where the listener started and stopped snapping. The two points can come
    /// in either order (they may have skipped back mid-snap). A clip shorter than `minimumLength`
    /// is stretched forward, and nothing runs past `episodeDuration` when that's known.
    public static func between(
        _ first: TimeInterval,
        _ second: TimeInterval,
        minimumLength: TimeInterval = 1,
        episodeDuration: TimeInterval? = nil
    ) -> ClipWindow {
        let duration = episodeDuration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        func clamp(_ time: TimeInterval) -> TimeInterval {
            let time = time.isFinite ? max(0, time) : 0
            return duration.map { min(time, $0) } ?? time
        }

        let a = clamp(first)
        let b = clamp(second)
        var start = min(a, b)
        var end = max(a, b)

        if end - start < minimumLength {
            end = start + minimumLength
            if let duration, end > duration {
                end = duration
                start = max(0, duration - minimumLength)
            }
        }
        return ClipWindow(start: start, end: end)
    }
}
