import SwiftUI
import os

private let appLogger = Logger(subsystem: "com.gesturepad", category: "App")

final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = GestureEngine()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[GesturePad] applicationDidFinishLaunching")

        // Start the engine immediately — MultitouchSupport does NOT need accessibility.
        // (Accessibility is only needed for posting CGEvents like middle-click.)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            let isAccessible = AXIsProcessTrusted()
            NSLog("[GesturePad] Accessibility trusted: %@", isAccessible ? "YES" : "NO")
            NSLog("[GesturePad] Note: touch detection works WITHOUT accessibility. Accessibility is only needed for action execution (middle-click, keyboard shortcuts).")

            // Always start the engine for touch detection
            engine.start()

            if !isAccessible {
                NSLog("[GesturePad] Prompting for accessibility (needed for actions)")
                let key = "AXTrustedCheckOptionPrompt" as CFString
                let options = [key: kCFBooleanTrue!] as CFDictionary
                AXIsProcessTrustedWithOptions(options)
            }
        }
    }
}

@main
struct GesturePadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("GesturePad", systemImage: "hand.tap") {
            MenuBarView(configStore: appDelegate.engine.configStore)
        }
        .menuBarExtraStyle(.window)

        Window("GesturePad Settings", id: "settings") {
            SettingsView(engine: appDelegate.engine)
        }
        .defaultSize(width: 550, height: 550)
        .windowResizability(.contentSize)
    }
}
