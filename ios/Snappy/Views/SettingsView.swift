import SwiftUI

struct SettingsView: View {
    @AppStorage(SnapSettings.lookbackKey) private var lookback = SnapSettings.defaultLookback
    @AppStorage(SnapSettings.headphoneSnapKey) private var headphoneSnap = true
    @Environment(PlayerController.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Snap length", selection: $lookback) {
                        ForEach(SnapSettings.lookbackChoices, id: \.self) { seconds in
                            Text("\(Int(seconds)) seconds").tag(seconds)
                        }
                    }
                } footer: {
                    Text("How far back a snap reaches from the moment you press it.")
                }

                Section {
                    Toggle("Snap with headphones", isOn: $headphoneSnap)
                } footer: {
                    Text("Your headphones' “next track” gesture, such as double-tapping AirPods, takes a snap.")
                }

                Section("Snap from anywhere") {
                    Label("**Action Button**: Settings › Action Button › Shortcut › Snappy › Snap.", systemImage: "button.vertical.right.press")
                    Label("**Back Tap**: Settings › Accessibility › Touch › Back Tap, then choose the Snap shortcut.", systemImage: "hand.tap")
                    Label("**Siri**: “Snap that in Snappy.”", systemImage: "mic")
                }
                .font(.callout)
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
