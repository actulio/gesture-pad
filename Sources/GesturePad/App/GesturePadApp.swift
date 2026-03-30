import SwiftUI

@main
struct GesturePadApp: App {
    var body: some Scene {
        MenuBarExtra("GesturePad", systemImage: "hand.tap") {
            Text("GesturePad is running")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
