import AppIntents
import SnappyCore

/// Takes a snap without opening the app, so it can be bound to the Action Button,
/// Back Tap (via Shortcuts), or triggered by Siri.
struct SnapIntent: AppIntent {
    static let title: LocalizedStringResource = "Snap What's Playing"
    static let description: IntentDescription? = IntentDescription("Saves the last few seconds of the episode playing in Snappy.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snap = PlayerController.shared.snap() else {
            return .result(dialog: "Nothing is playing in Snappy right now.")
        }
        return .result(dialog: "Snapped \(snap.timeRangeText) of “\(snap.episode.title)”.")
    }
}

struct SnappyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SnapIntent(),
            phrases: [
                "Snap that in \(.applicationName)",
                "\(.applicationName) snap",
                "Snap this with \(.applicationName)",
            ],
            shortTitle: "Snap",
            systemImageName: "waveform.badge.plus"
        )
    }
}
