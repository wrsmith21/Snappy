import Foundation

/// User preferences, shared between `@AppStorage` in views and the player.
enum SnapSettings {
    static let lookbackKey = "snapLookbackSeconds"
    static let headphoneSnapKey = "headphoneSnapEnabled"

    static let defaultLookback: TimeInterval = 30
    static let lookbackChoices: [TimeInterval] = [15, 30, 60]

    /// How far back a snap reaches from the moment it's taken.
    static var lookback: TimeInterval {
        let value = UserDefaults.standard.double(forKey: lookbackKey)
        return value > 0 ? value : defaultLookback
    }

    /// Whether the headphones' "next track" gesture takes a snap.
    static var headphoneSnapEnabled: Bool {
        UserDefaults.standard.object(forKey: headphoneSnapKey) as? Bool ?? true
    }
}
