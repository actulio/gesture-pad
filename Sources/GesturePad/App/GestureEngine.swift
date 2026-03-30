import Foundation
import os

@Observable
final class GestureEngine: @unchecked Sendable {
    let configStore: ConfigStore
    private let actionMapper: ActionMapper
    private let actionExecutor = ActionExecutor()
    private var gestureRecognizer = GestureRecognizer()
    private let logger = Logger(subsystem: "com.gesturepad", category: "GestureEngine")
    private var eventCount = 0

    var isDetecting = false
    var trackpadAvailable: Bool { TouchDetector.shared.isAvailable }

    init(configStore: ConfigStore = ConfigStore()) {
        self.configStore = configStore
        self.actionMapper = ActionMapper(configStore: configStore)
    }

    func start() {
        guard configStore.isEnabled else {
            NSLog("[GesturePad] Engine not starting: isEnabled=false")
            return
        }

        NSLog("[GesturePad] Starting gesture engine...")

        TouchDetector.shared.onTouchEvent = { [weak self] event in
            self?.handleTouchEvent(event)
        }

        isDetecting = TouchDetector.shared.start()
        if isDetecting {
            NSLog("[GesturePad] ✅ Gesture engine started successfully")
        } else {
            NSLog("[GesturePad] ❌ Failed to start gesture engine")
        }
    }

    func stop() {
        TouchDetector.shared.stop()
        isDetecting = false
        logger.info("Gesture engine stopped")
    }

    private func handleTouchEvent(_ event: TouchEvent) {
        guard configStore.isEnabled else { return }

        eventCount += 1
        if eventCount <= 10 || eventCount % 50 == 0 {
            NSLog("[GesturePad] Touch #%d: fingers=%d phase=%@ points=%d", eventCount, event.fingerCount, String(describing: event.phase), event.points.count)
        }

        if let gesture = gestureRecognizer.process(event),
           let action = actionMapper.action(for: gesture) {
            NSLog("[GesturePad] 🎯 Gesture → Action: %@ → %@", String(describing: gesture), String(describing: action))
            actionExecutor.execute(action)
        }
    }
}
