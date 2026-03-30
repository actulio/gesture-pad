import SwiftUI

@main
struct GesturePadApp: App {
    @State private var engine = GestureEngine()
    @State private var accessibilityChecker = AccessibilityChecker()

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
            .task {
                accessibilityChecker.checkAndPrompt()
            }
            .onChange(of: accessibilityChecker.isGranted) { _, granted in
                if granted { engine.start() }
            }
            .onChange(of: engine.configStore.isEnabled) { _, enabled in
                if enabled && accessibilityChecker.isGranted { engine.start() }
                else if !enabled { engine.stop() }
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
}
