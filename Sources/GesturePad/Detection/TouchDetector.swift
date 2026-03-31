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
            NSLog("[GesturePad] MultitouchSupport framework NOT available")
            return false
        }
        NSLog("[GesturePad] MultitouchSupport framework loaded OK")

        let count = mt.deviceCount()
        NSLog("[GesturePad] MTDeviceCountDevices = %d", count)

        let deviceList = mt.createDeviceList()
        NSLog("[GesturePad] createDeviceList returned %d device(s)", deviceList.count)
        guard !deviceList.isEmpty else {
            NSLog("[GesturePad] ❌ No multitouch devices found")
            return false
        }

        let callbackPtr = rawCallbackPointer()
        NSLog("[GesturePad] Callback pointer: %@", String(describing: callbackPtr))

        for (i, device) in deviceList.enumerated() {
            mt.registerCallback(device: device, callback: callbackPtr)
            let result = mt.startDevice(device)
            NSLog("[GesturePad] Device %d: started with result=%d", i, result)
            devices.append(device)
        }

        isRunning = true
        NSLog("[GesturePad] ✅ Tracking %d multitouch device(s)", devices.count)
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

    nonisolated(unsafe) static var rawCallbackCount = 0
    nonisolated(unsafe) static var loggedStructSize = false

    fileprivate func handleRawTouches(_ touchesPtr: UnsafeRawPointer, count: Int, timestamp: Double) {
        Self.rawCallbackCount += 1

        // Log struct size once
        if !Self.loggedStructSize {
            Self.loggedStructSize = true
            NSLog("[GesturePad] MTTouch size=%d stride=%d alignment=%d",
                  MemoryLayout<MTTouch>.size, MemoryLayout<MTTouch>.stride, MemoryLayout<MTTouch>.alignment)
        }

        let touches = touchesPtr.assumingMemoryBound(to: MTTouch.self)
        var points: [TouchPoint] = []
        var touchingCount = 0
        var liftingCount = 0

        // Log ALL multi-finger callbacks (count >= 2) and first 5 single-finger ones
        if count >= 2 || Self.rawCallbackCount <= 5 {
            var stateStr = ""
            for i in 0..<count {
                let t = touches[i]
                stateStr += "[i\(i):s\(t.state) id\(t.identifier) pos(\(String(format:"%.2f",t.normalizedVector.position.x)),\(String(format:"%.2f",t.normalizedVector.position.y)))] "
            }
            NSLog("[GesturePad] RAW #%d: count=%d — %@", Self.rawCallbackCount, count, stateStr)
        }

        for i in 0..<count {
            let touch = touches[i]
            // States: 1=notTracking 2=startInRange 3=hoverInRange 4=making/touching
            //         5=breaking (lifting) 6=lingering 7=leaving
            if touch.state >= 4 && touch.state <= 6 {
                touchingCount += 1
                points.append(TouchPoint(x: touch.normalizedVector.position.x * 1000,
                                         y: touch.normalizedVector.position.y * 1000))
            }
            if touch.state == 5 || touch.state == 7 {
                liftingCount += 1
            }
        }

        // Determine phase
        let phase: TouchPhase
        if touchingCount == 0 && liftingCount > 0 {
            phase = .ended
        } else if liftingCount > 0 {
            phase = .ended
        } else if touchingCount > 0 {
            phase = .moved
        } else {
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
