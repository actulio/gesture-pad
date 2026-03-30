import Foundation
import os

final class TouchDetector: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.gesturepad", category: "TouchDetector")
    private var devices: [UnsafeMutableRawPointer] = []
    private var isRunning = false

    var onTouchEvent: (@Sendable (TouchEvent) -> Void)?

    static let shared = TouchDetector()

    private init() {}

    var isAvailable: Bool {
        MultitouchFunctions.shared.isAvailable
    }

    func start() -> Bool {
        guard !isRunning else { return true }
        let mt = MultitouchFunctions.shared
        guard mt.isAvailable else {
            logger.error("MultitouchSupport framework not available")
            return false
        }

        let deviceList = mt.createDeviceList()
        logger.info("Found \(deviceList.count) multitouch device(s)")
        guard !deviceList.isEmpty else {
            logger.warning("No multitouch devices found")
            return false
        }

        let callbackPtr = rawCallbackPointer()

        for device in deviceList {
            mt.registerCallback(device: device, callback: callbackPtr)
            let result = mt.startDevice(device)
            logger.info("Started device: result=\(result)")
            devices.append(device)
        }

        isRunning = true
        logger.info("Started tracking \(self.devices.count) multitouch device(s)")
        return true
    }

    func stop() {
        let mt = MultitouchFunctions.shared
        let callbackPtr = rawCallbackPointer()
        for device in devices {
            mt.unregisterCallback(device: device, callback: callbackPtr)
            mt.stopDevice(device)
        }
        devices.removeAll()
        isRunning = false
        logger.info("Stopped multitouch tracking")
    }

    fileprivate func handleRawTouches(_ touchesPtr: UnsafeRawPointer, count: Int, timestamp: Double) {
        let touches = touchesPtr.assumingMemoryBound(to: MTTouch.self)
        var points: [TouchPoint] = []
        var touchingCount = 0
        var liftingCount = 0

        for i in 0..<count {
            let touch = touches[i]
            // States: 1=notTracking 2=startInRange 3=hoverInRange 4=making/touching
            //         5=breaking (lifting) 6=lingering 7=leaving
            if touch.state >= 4 && touch.state <= 6 {
                // Actively touching
                touchingCount += 1
                points.append(TouchPoint(x: touch.normalizedVector.x * 1000,
                                         y: touch.normalizedVector.y * 1000))
            }
            if touch.state == 5 || touch.state == 7 {
                liftingCount += 1
            }
        }

        // Determine phase based on aggregate state
        let phase: TouchPhase
        if touchingCount == 0 && liftingCount > 0 {
            // All fingers have lifted
            phase = .ended
        } else if liftingCount > 0 {
            // Some fingers lifting while others still down
            phase = .ended
        } else if touchingCount > 0 {
            // Use .began if this is a new touch group, .moved otherwise
            // We'll emit both — the recognizer tracks state transitions itself
            phase = .moved
        } else {
            // No relevant touches
            return
        }

        let fingerCount = max(touchingCount, liftingCount)
        guard fingerCount > 0 else { return }

        let event = TouchEvent(timestamp: timestamp, fingerCount: fingerCount, points: points, phase: phase)
        onTouchEvent?(event)
    }
}

// The C callback uses only C-representable types
private let touchCallbackFunction: @convention(c) (
    UnsafeMutableRawPointer,    // device
    UnsafeRawPointer,           // touches (raw)
    Int32,                      // count
    Double,                     // timestamp
    Int32                       // frame
) -> Void = { _, touchesPtr, touchCount, timestamp, _ in
    guard touchCount > 0 else { return }
    TouchDetector.shared.handleRawTouches(touchesPtr, count: Int(touchCount), timestamp: timestamp)
}

private func rawCallbackPointer() -> UnsafeMutableRawPointer {
    unsafeBitCast(touchCallbackFunction, to: UnsafeMutableRawPointer.self)
}
