import Foundation

/// User preferences, shared between `@AppStorage` in views and the player.
enum SnapSettings {
    static let headphoneSnapKey = "headphoneSnapEnabled"

    /// Whether the headphones' "next track" gesture starts and stops snaps.
    static var headphoneSnapEnabled: Bool {
        UserDefaults.standard.object(forKey: headphoneSnapKey) as? Bool ?? true
    }
}
