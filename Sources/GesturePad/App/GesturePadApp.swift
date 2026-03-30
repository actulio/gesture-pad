import SwiftUI

@main
struct GesturePadApp: App {
    @State private var engine = GestureEngine()
    @State private var accessibilityChecker = AccessibilityChecker()

    var body: some Scene {
        MenuBarExtra("GesturePad", systemImage: "hand.tap") {
            MenuBarView(configStore: engine.configStore)
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
}
