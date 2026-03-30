import Foundation
import os

@Observable
final class GestureEngine: @unchecked Sendable {
    var configStore: ConfigStore
    private let actionMapper: ActionMapper
    private let actionExecutor = ActionExecutor()
    private var gestureRecognizer = GestureRecognizer()
    private let logger = Logger(subsystem: "com.gesturepad", category: "GestureEngine")
    private var eventCount = 0

    // Debug state — visible to the UI
    var isDetecting = false
    var trackpadAvailable: Bool { TouchDetector.shared.isAvailable }
    var debugStatus: String = "Not started"
    var lastTouchInfo: String = "—"
    var lastGestureInfo: String = "No gesture detected yet"
    var touchEventCount: Int = 0
    var deviceCount: Int = 0

    /// Test mode: when true, recognized gestures update `lastGestureInfo` but do NOT execute actions
    var testMode = false

    init(configStore: ConfigStore = ConfigStore()) {
        self.configStore = configStore
        self.actionMapper = ActionMapper(configStore: configStore)
    }

    func start() {
        guard configStore.isEnabled else {
            NSLog("[GesturePad] Engine not starting: isEnabled=false")
            debugStatus = "Disabled (toggle is off)"
            return
        }

        NSLog("[GesturePad] Starting gesture engine...")
        debugStatus = "Starting..."

        TouchDetector.shared.onTouchEvent = { [weak self] event in
            self?.handleTouchEvent(event)
        }

        let mt = MultitouchFunctions.shared
        NSLog("[GesturePad] MultitouchSupport available: %@", mt.isAvailable ? "YES" : "NO")
        
        if mt.isAvailable {
            let count = mt.deviceCount()
            NSLog("[GesturePad] MT device count: %d", count)
            let devices = mt.createDeviceList()
            NSLog("[GesturePad] MT device list: %d devices", devices.count)
            DispatchQueue.main.async {
                self.deviceCount = devices.count
            }
        }

        isDetecting = TouchDetector.shared.start()
        if isDetecting {
            NSLog("[GesturePad] ✅ Gesture engine started successfully")
            debugStatus = "Running — waiting for touches"
        } else {
            NSLog("[GesturePad] ❌ Failed to start gesture engine")
            debugStatus = "Failed to start (no trackpad?)"
        }
    }

    func stop() {
        TouchDetector.shared.stop()
        isDetecting = false
        debugStatus = "Stopped"
        logger.info("Gesture engine stopped")
    }

    private func handleTouchEvent(_ event: TouchEvent) {
        guard configStore.isEnabled else { return }

        eventCount += 1
        
        let info = "fingers=\(event.fingerCount) phase=\(event.phase) pts=\(event.points.count)"
        
        // Always log multi-finger events; throttle single-finger noise
        if event.fingerCount >= 2 || eventCount <= 20 || eventCount % 200 == 0 {
            NSLog("[GesturePad] Touch #%d: %@", eventCount, info)
        }

        // Update UI on main thread
        DispatchQueue.main.async {
            self.touchEventCount = self.eventCount
            self.lastTouchInfo = info
            self.debugStatus = "Active — receiving touches"
        }

        if let gesture = gestureRecognizer.process(event) {
            NSLog("[GesturePad] 🎯 Recognized: %@", String(describing: gesture))
            
            DispatchQueue.main.async {
                self.lastGestureInfo = "\(gesture) at \(Self.timeString())"
            }
            
            if testMode {
                NSLog("[GesturePad] Test mode — skipping action execution")
            } else if let action = actionMapper.action(for: gesture) {
                NSLog("[GesturePad] Executing: %@", String(describing: action))
                actionExecutor.execute(action)
            }
        }
    }
    
    private static func timeString() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }
}
