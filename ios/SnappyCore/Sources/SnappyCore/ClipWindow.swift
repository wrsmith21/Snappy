import Foundation

/// The stretch of an episode a snap covers.
public struct ClipWindow: Equatable, Sendable {
    public var start: TimeInterval
    public var end: TimeInterval

    public init(start: TimeInterval, end: TimeInterval) {
        self.start = start
        self.end = end
    }

    /// Like a screenshot, a snap captures what just happened: the `lookback` seconds before `position`.
    /// Near the start of an episode the window is stretched forward so it's at least `minimumLength` long,
    /// and it never runs past `episodeDuration` when that's known.
    public static func ending(
        at position: TimeInterval,
        lookback: TimeInterval = 30,
        minimumLength: TimeInterval = 10,
        episodeDuration: TimeInterval? = nil
    ) -> ClipWindow {
        let duration = episodeDuration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        var end = max(0, position.isFinite ? position : 0)
        if let duration { end = min(end, duration) }
        var start = max(0, end - lookback)

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
