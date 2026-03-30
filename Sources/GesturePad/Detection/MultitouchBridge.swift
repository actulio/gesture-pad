import Foundation

// C-level types from MultitouchSupport.framework (private)

struct MTPoint {
    var x: Float
    var y: Float
}

// MTVector includes both position AND velocity (critical for correct struct size!)
struct MTVector {
    var position: MTPoint
    var velocity: MTPoint
}

struct MTTouch {
    var frame: Int32
    var timestamp: Double
    var identifier: Int32       // pathIndex / transducerIndex
    var state: Int32            // MTTouchState: 1=notTracking 2=startInRange 3=hoverInRange 4=touching 5=breaking 6=lingering 7=leaving
    var fingerID: Int32
    var handID: Int32
    var normalizedVector: MTVector     // position (0..1) + velocity
    var zTotal: Float                  // pressure/quality 0..1
    var unused3: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var absoluteVector: MTVector       // absolute position (mm) + velocity
    var unused4: Int32
    var unused5: Int32
    var zDensity: Float
}

// Dynamically loaded function pointers — use UnsafeMutableRawPointer for device refs
final class MultitouchFunctions: @unchecked Sendable {
    static let shared = MultitouchFunctions()

    private(set) var handle: UnsafeMutableRawPointer?

    private init() {
        handle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW)
        if handle != nil {
            NSLog("[GesturePad] MultitouchSupport.framework loaded successfully")
        } else {
            NSLog("[GesturePad] FAILED to load MultitouchSupport.framework")
        }
    }

    var isAvailable: Bool { handle != nil }

    func deviceCount() -> Int32 {
        guard let handle else { return 0 }
        // First try the list-based approach (more reliable)
        let devices = createDeviceList()
        return Int32(devices.count)
    }

    /// MTDeviceCreateList() -> CFArrayRef
    /// Takes NO arguments, returns a CFArray of device references
    func createDeviceList() -> [UnsafeMutableRawPointer] {
        guard let handle else {
            NSLog("[GesturePad] createDeviceList: no handle")
            return []
        }

        guard let sym = dlsym(handle, "MTDeviceCreateList") else {
            NSLog("[GesturePad] createDeviceList: symbol not found")
            return []
        }

        // Correct signature: () -> Unmanaged<CFArray>?
        let fn = unsafeBitCast(sym, to: (@convention(c) () -> CFArray?).self)
        
        guard let cfArray = fn() else {
            NSLog("[GesturePad] createDeviceList: MTDeviceCreateList() returned nil")
            return []
        }

        let nsArray = cfArray as NSArray
        NSLog("[GesturePad] createDeviceList: got %d device(s) from CFArray", nsArray.count)

        var devices: [UnsafeMutableRawPointer] = []
        for i in 0..<nsArray.count {
            // Each element is a MTDeviceRef (opaque pointer)
            let obj = nsArray[i]
            let ptr = Unmanaged.passUnretained(obj as AnyObject).toOpaque()
            devices.append(UnsafeMutableRawPointer(mutating: ptr))
        }
        
        return devices
    }

    func registerCallback(device: UnsafeMutableRawPointer, callback: UnsafeMutableRawPointer) {
        guard let handle,
              let sym = dlsym(handle, "MTRegisterContactFrameCallback") else {
            NSLog("[GesturePad] registerCallback: symbol not found")
            return
        }
        let fn = unsafeBitCast(sym, to: (@convention(c) (UnsafeMutableRawPointer, UnsafeMutableRawPointer) -> Void).self)
        fn(device, callback)
        NSLog("[GesturePad] Registered callback for device")
    }

    func unregisterCallback(device: UnsafeMutableRawPointer, callback: UnsafeMutableRawPointer) {
        guard let handle,
              let sym = dlsym(handle, "MTUnregisterContactFrameCallback") else { return }
        let fn = unsafeBitCast(sym, to: (@convention(c) (UnsafeMutableRawPointer, UnsafeMutableRawPointer) -> Void).self)
        fn(device, callback)
    }

    func startDevice(_ device: UnsafeMutableRawPointer) -> Int32 {
        guard let handle,
              let sym = dlsym(handle, "MTDeviceStart") else {
            NSLog("[GesturePad] startDevice: symbol not found")
            return -1
        }
        let fn = unsafeBitCast(sym, to: (@convention(c) (UnsafeMutableRawPointer, Int32) -> Int32).self)
        return fn(device, 0)
    }

    func stopDevice(_ device: UnsafeMutableRawPointer) {
        guard let handle,
              let sym = dlsym(handle, "MTDeviceStop") else { return }
        let fn = unsafeBitCast(sym, to: (@convention(c) (UnsafeMutableRawPointer) -> Void).self)
        fn(device)
    }
}
