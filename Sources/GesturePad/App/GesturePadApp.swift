import SwiftUI

@main
struct GesturePadApp: App {
    @State private var engine = GestureEngine()

    var body: some Scene {
        MenuBarExtra("GesturePad", systemImage: "hand.tap") {
            MenuBarView(configStore: engine.configStore) {
                NSApp.activate()
                if let window = NSApp.windows.first(where: { $0.title == "GesturePad Settings" }) {
                    window.makeKeyAndOrderFront(nil)
                } else {
                    openSettings()
                }
            }
        }
        .menuBarExtraStyle(.window)

        Window("GesturePad Settings", id: "settings") {
            SettingsView(configStore: engine.configStore)
        }
        .defaultSize(width: 500, height: 350)
        .windowResizability(.contentSize)
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func checkAccessibilityAndStart() {
        if AXIsProcessTrusted() {
            engine.start()
        }
    }
}
