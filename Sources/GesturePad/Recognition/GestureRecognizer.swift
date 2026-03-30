import Foundation
import os

struct GestureRecognizer: Sendable {
    private var tapRecognizer = TapRecognizer()
    private var swipeRecognizer = SwipeRecognizer()
    private var lastGestureTime: TimeInterval = 0
    private let cooldown: TimeInterval = 0.3
    private let logger = Logger(subsystem: "com.gesturepad", category: "GestureRecognizer")

    mutating func process(_ event: TouchEvent) -> RecognizedGesture? {
        let timeSinceLastGesture = event.timestamp - lastGestureTime
        if timeSinceLastGesture < cooldown {
            // During cooldown, just reset state on end events
            if event.phase == .ended || event.phase == .cancelled {
                tapRecognizer.reset()
                swipeRecognizer.reset()
            }
            return nil
        }

        // Try swipe first (higher priority for multi-finger horizontal movement)
        if let swipe = swipeRecognizer.process(event) {
            tapRecognizer.reset()
            lastGestureTime = event.timestamp
            logger.info("Recognized gesture: swipe → \(String(describing: swipe))")
            return swipe
        }

        if let tap = tapRecognizer.process(event) {
            swipeRecognizer.reset()
            lastGestureTime = event.timestamp
            logger.info("Recognized gesture: tap → \(String(describing: tap))")
            return tap
        }

        return nil
    }
}
