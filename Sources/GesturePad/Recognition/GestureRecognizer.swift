import Foundation

struct GestureRecognizer: Sendable {
    private var tapRecognizer = TapRecognizer()
    private var swipeRecognizer = SwipeRecognizer()
    private var lastGestureTime: TimeInterval = 0
    private let cooldown: TimeInterval = 0.3

    mutating func process(_ event: TouchEvent) -> RecognizedGesture? {
        if event.timestamp - lastGestureTime < cooldown {
            if event.phase == .began {
                tapRecognizer.reset()
                swipeRecognizer.reset()
            }
            if event.phase == .ended || event.phase == .cancelled {
                tapRecognizer.reset()
                swipeRecognizer.reset()
            }
            return nil
        }

        if let swipe = swipeRecognizer.process(event) {
            tapRecognizer.reset()
            lastGestureTime = event.timestamp
            return swipe
        }

        if let tap = tapRecognizer.process(event) {
            swipeRecognizer.reset()
            lastGestureTime = event.timestamp
            return tap
        }

        return nil
    }
}
