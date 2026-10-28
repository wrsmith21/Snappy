import SwiftUI

struct SettingsView: View {
    @AppStorage(SnapSettings.headphoneSnapKey) private var headphoneSnap = true
    @Environment(PlayerController.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Snap with headphones", isOn: $headphoneSnap)
                } footer: {
                    Text("Your headphones' “next track” gesture, such as double-tapping AirPods, starts a snap. Do it again to stop.")
                }

                Section {
                    Group {
                        Label("**Action Button**: Settings › Action Button › Shortcut › Snappy › Snap.", systemImage: "button.vertical.right.press")
                        Label("**Back Tap**: Settings › Accessibility › Touch › Back Tap, then choose the Snap shortcut.", systemImage: "hand.tap")
                        Label("**Siri**: “Snap that in Snappy.”", systemImage: "mic")
                    }
                    .font(.callout)
                } header: {
                    Text("Snap from anywhere")
                } footer: {
                    Text("Each one starts a snap the first time and saves it the second. Long-press the Stop button to discard a snap.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { dismiss() }
            }
            .onChange(of: headphoneSnap) { _, enabled in
                player.setHeadphoneSnapEnabled(enabled)
            }
        }
    }
}
