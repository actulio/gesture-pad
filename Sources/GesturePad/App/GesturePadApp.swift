import SwiftUI
import os

private let appLogger = Logger(subsystem: "com.gesturepad", category: "App")

final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = GestureEngine()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[GesturePad] applicationDidFinishLaunching")

        // Delay slightly to let the run loop settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            let isAccessible = AXIsProcessTrusted()
            NSLog("[GesturePad] Accessibility trusted: %@", isAccessible ? "YES" : "NO")

            if isAccessible {
                NSLog("[GesturePad] Starting engine immediately")
                engine.start()
            } else {
                NSLog("[GesturePad] Prompting for accessibility")
                // Prompt for accessibility
                let key = "AXTrustedCheckOptionPrompt" as CFString
                let options = [key: kCFBooleanTrue!] as CFDictionary
                AXIsProcessTrustedWithOptions(options)

                // Poll until granted
                Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                    if AXIsProcessTrusted() {
                        timer.invalidate()
                        NSLog("[GesturePad] Accessibility granted via polling — starting engine")
                        self?.engine.start()
                    }
                }
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
            SettingsView(configStore: appDelegate.engine.configStore)
        }
        .defaultSize(width: 500, height: 350)
        .windowResizability(.contentSize)
    }
}
