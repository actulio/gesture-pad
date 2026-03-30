import Foundation
import os

@Observable
final class GestureEngine: @unchecked Sendable {
    let configStore: ConfigStore
    private let actionMapper: ActionMapper
    private let actionExecutor = ActionExecutor()
    private var gestureRecognizer = GestureRecognizer()
    private let logger = Logger(subsystem: "com.gesturepad", category: "GestureEngine")

    var isDetecting = false
    var trackpadAvailable: Bool { TouchDetector.shared.isAvailable }

    init(configStore: ConfigStore = ConfigStore()) {
        self.configStore = configStore
        self.actionMapper = ActionMapper(configStore: configStore)
    }

    func start() {
        guard configStore.isEnabled else { return }

        TouchDetector.shared.onTouchEvent = { [weak self] event in
            self?.handleTouchEvent(event)
        }

        isDetecting = TouchDetector.shared.start()
        if isDetecting {
            logger.info("Gesture engine started")
        } else {
            logger.error("Failed to start gesture engine")
        }
    }

    func stop() {
        TouchDetector.shared.stop()
        isDetecting = false
        logger.info("Gesture engine stopped")
    }

    private func handleTouchEvent(_ event: TouchEvent) {
        guard configStore.isEnabled else { return }

        if let gesture = gestureRecognizer.process(event),
           let action = actionMapper.action(for: gesture) {
            logger.debug("Recognized \(String(describing: gesture)) → executing \(String(describing: action))")
            actionExecutor.execute(action)
        }
    }
}
