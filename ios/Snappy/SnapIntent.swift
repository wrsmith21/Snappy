import AppIntents
import SnappyCore

/// Starts or stops a snap without opening the app, so it can be bound to the Action Button,
/// Back Tap (via Shortcuts), or triggered by Siri.
struct SnapIntent: AppIntent {
    static let title: LocalizedStringResource = "Start or Stop a Snap"
    static let description: IntentDescription? = IntentDescription("Starts snapping the episode playing in Snappy, or saves the snap if one is already going.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        switch PlayerController.shared.toggleSnap() {
        case .started(let start):
            return .result(dialog: "Snapping from \(Timecode.string(start)). Run it again to stop.")
        case .saved(let snap):
            return .result(dialog: "Snapped \(snap.timeRangeText) of “\(snap.episode.title)”.")
        case nil:
            return .result(dialog: "Nothing is playing in Snappy right now.")
        }
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
