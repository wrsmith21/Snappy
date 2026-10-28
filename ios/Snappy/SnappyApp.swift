import SwiftUI

@main
struct SnappyApp: App {
    @State private var player = PlayerController.shared
    @State private var library = SnapLibrary.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(player)
                .environment(library)
        }
    }
}
