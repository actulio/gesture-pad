import Foundation

// C-level types from MultitouchSupport.framework (private)

struct MTVector2 {
    var x: Float
    var y: Float
}

struct MTTouch {
    var frame: Int32
    var timestamp: Double
    var identifier: Int32
    var state: Int32           // 1=notTracking 2=startInRange 3=hoverInRange 4=touching 5=outOfRange
    var fingerID: Int32
    var handID: Int32
    var normalizedVector: MTVector2     // position 0..1
    var zTotal: Float
    var unused3: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var absoluteVector: MTVector2       // absolute position
    var unused4: Int32
    var unused5: Int32
    var zDensity: Float
}

// Use raw pointer types for C convention compatibility
typealias MTContactCallbackRaw = @convention(c) (
    Int32,                              // device (as int, reinterpreted)
    UnsafeRawPointer,                   // touches pointer
    Int32,                              // touch count
    Double,                             // timestamp
    Int32                               // frame
) -> Void

// Dynamically loaded function pointers — use UnsafeMutableRawPointer for device refs
final class MultitouchFunctions: @unchecked Sendable {
    static let shared = MultitouchFunctions()

    private(set) var handle: UnsafeMutableRawPointer?

    private init() {
        handle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW)
    }

    var isAvailable: Bool { handle != nil }

    func deviceCount() -> Int32 {
        guard let handle,
              let sym = dlsym(handle, "MTDeviceCountDevices") else { return 0 }
        let fn = unsafeBitCast(sym, to: (@convention(c) () -> Int32).self)
        return fn()
    }

    func createDeviceList() -> [UnsafeMutableRawPointer] {
        guard let handle else { return [] }
        let count = deviceCount()
        guard count > 0 else { return [] }

        guard let sym = dlsym(handle, "MTDeviceCreateList") else { return [] }
        let fn = unsafeBitCast(sym, to: (@convention(c) (UnsafeMutableRawPointer, Int32) -> Int32).self)

        let buffer = UnsafeMutableBufferPointer<UnsafeMutableRawPointer?>.allocate(capacity: Int(count))
        buffer.initialize(repeating: nil)
        defer { buffer.deallocate() }

        _ = fn(buffer.baseAddress!, count)

        return buffer.compactMap { $0 }
    }

    func registerCallback(device: UnsafeMutableRawPointer, callback: UnsafeMutableRawPointer) {
        guard let handle,
              let sym = dlsym(handle, "MTRegisterContactFrameCallback") else { return }
        let fn = unsafeBitCast(sym, to: (@convention(c) (UnsafeMutableRawPointer, UnsafeMutableRawPointer) -> Void).self)
        fn(device, callback)
    }

    func unregisterCallback(device: UnsafeMutableRawPointer, callback: UnsafeMutableRawPointer) {
        guard let handle,
              let sym = dlsym(handle, "MTUnregisterContactFrameCallback") else { return }
        let fn = unsafeBitCast(sym, to: (@convention(c) (UnsafeMutableRawPointer, UnsafeMutableRawPointer) -> Void).self)
        fn(device, callback)
    }

    func startDevice(_ device: UnsafeMutableRawPointer) -> Int32 {
        guard let handle,
              let sym = dlsym(handle, "MTDeviceStart") else { return -1 }
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
