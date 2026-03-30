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
        guard !deviceList.isEmpty else {
            logger.warning("No multitouch devices found")
            return false
        }

        let callbackPtr = rawCallbackPointer()

        for device in deviceList {
            mt.registerCallback(device: device, callback: callbackPtr)
            _ = mt.startDevice(device)
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

        for i in 0..<count {
            let touch = touches[i]
            if touch.state >= 4 { // touching
                touchingCount += 1
                points.append(TouchPoint(x: touch.normalizedVector.x * 1000,
                                         y: touch.normalizedVector.y * 1000))
            }
        }

        guard touchingCount > 0 else { return }

        let allTouching = (0..<count).allSatisfy { touches[$0].state >= 4 }
        let anyEnding = (0..<count).contains { touches[$0].state >= 5 }

        let phase: TouchPhase
        if anyEnding {
            phase = .ended
        } else if allTouching {
            phase = .moved
        } else {
            phase = .began
        }

        let event = TouchEvent(timestamp: timestamp, fingerCount: touchingCount, points: points, phase: phase)
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
