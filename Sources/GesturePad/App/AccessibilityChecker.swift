import Foundation
import AppKit
import os

@Observable
final class AccessibilityChecker {
    var isGranted: Bool = false
    private var timer: Timer?
    private let logger = Logger(subsystem: "com.gesturepad", category: "Accessibility")

    init() {
        isGranted = AXIsProcessTrusted()
    }

    func checkAndPrompt() {
        isGranted = AXIsProcessTrusted()
        if !isGranted {
            promptForAccess()
            startPolling()
        }
    }

    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let granted = AXIsProcessTrusted()
            if granted != self.isGranted {
                self.isGranted = granted
                if granted {
                    self.timer?.invalidate()
                    self.timer = nil
                    self.logger.info("Accessibility permission granted")
                }
            }
        }
    }

    private func promptForAccess() {
        // Use raw string to avoid Swift 6 concurrency issue with global C variable kAXTrustedCheckOptionPrompt
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let options = [key: kCFBooleanTrue!] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
