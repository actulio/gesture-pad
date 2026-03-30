# GesturePad v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu bar app that detects 3-finger trackpad gestures (tap, swipe left, swipe right) and maps them to system actions (middle click, ⌘+Tab, ⌘+Shift+Tab).

**Architecture:** Hybrid approach — MultitouchSupport.framework (private) for touch detection, CGEvent (public) for action execution. Six components: TouchDetector → GestureRecognizer → ActionMapper → ActionExecutor, backed by ConfigStore, wrapped in a SwiftUI MenuBarExtra app.

**Tech Stack:** Swift 6, SwiftUI, SwiftPM, macOS 15+, MultitouchSupport.framework, CGEvent API

---

## Task 1: Project Scaffold

**Files:**
- Create: `Package.swift`
- Create: `Sources/GesturePad/App/GesturePadApp.swift`

- [ ] **Step 1: Create Package.swift**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GesturePad",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "GesturePad",
            path: "Sources/GesturePad",
            linkerSettings: [
                .unsafeFlags(["-framework", "ApplicationServices"]),
            ]
        ),
        .testTarget(
            name: "GesturePadTests",
            dependencies: ["GesturePad"],
            path: "Tests/GesturePadTests"
        ),
    ]
)
```

- [ ] **Step 2: Create minimal app entry point**

```swift
// Sources/GesturePad/App/GesturePadApp.swift
import SwiftUI

@main
struct GesturePadApp: App {
    var body: some Scene {
        MenuBarExtra("GesturePad", systemImage: "hand.tap") {
            Text("GesturePad is running")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
```

- [ ] **Step 3: Verify it builds**

Run: `swift build 2>&1`
Expected: Build succeeds with no errors

- [ ] **Step 4: Commit**

```bash
git add Package.swift Sources/
git commit -m "feat: scaffold SwiftPM project with minimal menu bar app"
```

---

## Task 2: Data Model — GestureType and ActionType

**Files:**
- Create: `Sources/GesturePad/Config/GestureType.swift`
- Create: `Sources/GesturePad/Config/ActionType.swift`
- Test: `Tests/GesturePadTests/ConfigModelTests.swift`

- [ ] **Step 1: Write the failing test for GestureType Codable round-trip**

```swift
// Tests/GesturePadTests/ConfigModelTests.swift
import Testing
@testable import GesturePad

@Test func gestureTypeRoundTrip() throws {
    let gestures: [GestureType] = [.threeFingerTap, .threeFingerSwipeLeft, .threeFingerSwipeRight]
    let data = try JSONEncoder().encode(gestures)
    let decoded = try JSONDecoder().decode([GestureType].self, from: data)
    #expect(decoded == gestures)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ConfigModelTests 2>&1`
Expected: FAIL — `GestureType` not defined

- [ ] **Step 3: Implement GestureType**

```swift
// Sources/GesturePad/Config/GestureType.swift
import Foundation

enum GestureType: String, Codable, CaseIterable, Hashable, Sendable {
    case threeFingerTap
    case threeFingerSwipeLeft
    case threeFingerSwipeRight

    var displayName: String {
        switch self {
        case .threeFingerTap: "3-Finger Tap"
        case .threeFingerSwipeLeft: "3-Finger Swipe ←"
        case .threeFingerSwipeRight: "3-Finger Swipe →"
        }
    }

    var subtitle: String {
        switch self {
        case .threeFingerTap: "Tap with three fingers"
        case .threeFingerSwipeLeft: "Swipe left with three fingers"
        case .threeFingerSwipeRight: "Swipe right with three fingers"
        }
    }
}
```

- [ ] **Step 4: Write the failing test for ActionType Codable round-trip**

Add to `ConfigModelTests.swift`:

```swift
@Test func actionTypeRoundTrip() throws {
    let actions: [ActionType] = [
        .middleClick,
        .keyboardShortcut(modifiers: 256, keyCode: 48), // ⌘+Tab
        .disabled,
    ]
    let data = try JSONEncoder().encode(actions)
    let decoded = try JSONDecoder().decode([ActionType].self, from: data)
    #expect(decoded == actions)
}
```

- [ ] **Step 5: Implement ActionType**

```swift
// Sources/GesturePad/Config/ActionType.swift
import Foundation
import CoreGraphics

enum ActionType: Codable, Hashable, Sendable {
    case middleClick
    case keyboardShortcut(modifiers: UInt64, keyCode: UInt16)
    case disabled

    var displayName: String {
        switch self {
        case .middleClick:
            "🖱️ Middle Click"
        case .keyboardShortcut(let modifiers, let keyCode):
            "⌨️ \(Self.formatShortcut(modifiers: modifiers, keyCode: keyCode))"
        case .disabled:
            "Disabled"
        }
    }

    static func formatShortcut(modifiers: UInt64, keyCode: UInt16) -> String {
        var parts: [String] = []
        let flags = CGEventFlags(rawValue: modifiers)
        if flags.contains(.maskControl) { parts.append("⌃") }
        if flags.contains(.maskAlternate) { parts.append("⌥") }
        if flags.contains(.maskShift) { parts.append("⇧") }
        if flags.contains(.maskCommand) { parts.append("⌘") }
        parts.append(KeyCodeNames.name(for: keyCode))
        return parts.joined()
    }
}
```

- [ ] **Step 6: Create KeyCodeNames helper**

```swift
// Sources/GesturePad/Config/KeyCodeNames.swift
import Foundation

enum KeyCodeNames {
    private static let names: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P",
        37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
        48: "Tab", 49: "Space", 51: "Delete", 53: "Esc",
        36: "Return", 76: "Enter",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5",
        97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
        103: "F11", 111: "F12",
    ]

    static func name(for keyCode: UInt16) -> String {
        names[keyCode] ?? "Key\(keyCode)"
    }
}
```

- [ ] **Step 7: Run all tests to verify they pass**

Run: `swift test --filter ConfigModelTests 2>&1`
Expected: All tests PASS

- [ ] **Step 8: Commit**

```bash
git add Sources/GesturePad/Config/ Tests/GesturePadTests/ConfigModelTests.swift
git commit -m "feat: add GestureType and ActionType data models with Codable support"
```

---

## Task 3: ConfigStore — Persistence

**Files:**
- Create: `Sources/GesturePad/Config/ConfigStore.swift`
- Test: `Tests/GesturePadTests/ConfigStoreTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/GesturePadTests/ConfigStoreTests.swift
import Testing
@testable import GesturePad

@Test func defaultMappingsAreSet() {
    let store = ConfigStore(defaults: .init(suiteName: "test-defaults-\(UUID().uuidString)")!)
    let mapping = store.action(for: .threeFingerTap)
    #expect(mapping == .middleClick)
}

@Test func saveAndLoadCustomMapping() {
    let defaults = UserDefaults(suiteName: "test-save-\(UUID().uuidString)")!
    let store = ConfigStore(defaults: defaults)
    store.setAction(.keyboardShortcut(modifiers: 256, keyCode: 48), for: .threeFingerTap)

    let store2 = ConfigStore(defaults: defaults)
    #expect(store2.action(for: .threeFingerTap) == .keyboardShortcut(modifiers: 256, keyCode: 48))
}

@Test func isEnabledDefaultsToTrue() {
    let store = ConfigStore(defaults: .init(suiteName: "test-enabled-\(UUID().uuidString)")!)
    #expect(store.isEnabled == true)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ConfigStoreTests 2>&1`
Expected: FAIL — `ConfigStore` not defined

- [ ] **Step 3: Implement ConfigStore**

```swift
// Sources/GesturePad/Config/ConfigStore.swift
import Foundation
import Observation

@Observable
final class ConfigStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private static let mappingsKey = "gestureMappings"
    private static let enabledKey = "gesturesEnabled"

    private(set) var mappings: [GestureType: ActionType]
    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.enabledKey) }
    }

    static let defaultMappings: [GestureType: ActionType] = [
        .threeFingerTap: .middleClick,
        .threeFingerSwipeRight: .keyboardShortcut(
            modifiers: CGEventFlags.maskCommand.rawValue,
            keyCode: 48
        ),
        .threeFingerSwipeLeft: .keyboardShortcut(
            modifiers: CGEventFlags([.maskCommand, .maskShift]).rawValue,
            keyCode: 48
        ),
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: Self.mappingsKey),
           let decoded = try? JSONDecoder().decode([GestureType: ActionType].self, from: data) {
            self.mappings = decoded
        } else {
            self.mappings = Self.defaultMappings
        }

        if defaults.object(forKey: Self.enabledKey) != nil {
            self.isEnabled = defaults.bool(forKey: Self.enabledKey)
        } else {
            self.isEnabled = true
        }
    }

    func action(for gesture: GestureType) -> ActionType {
        mappings[gesture] ?? .disabled
    }

    func setAction(_ action: ActionType, for gesture: GestureType) {
        mappings[gesture] = action
        if let data = try? JSONEncoder().encode(mappings) {
            defaults.set(data, forKey: Self.mappingsKey)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ConfigStoreTests 2>&1`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/GesturePad/Config/ConfigStore.swift Tests/GesturePadTests/ConfigStoreTests.swift
git commit -m "feat: add ConfigStore with UserDefaults persistence"
```

---

## Task 4: Gesture Recognition — TapRecognizer

**Files:**
- Create: `Sources/GesturePad/Recognition/TouchEvent.swift`
- Create: `Sources/GesturePad/Recognition/RecognizedGesture.swift`
- Create: `Sources/GesturePad/Recognition/TapRecognizer.swift`
- Test: `Tests/GesturePadTests/TapRecognizerTests.swift`

- [ ] **Step 1: Create TouchEvent and RecognizedGesture types**

```swift
// Sources/GesturePad/Recognition/TouchEvent.swift
import Foundation

struct TouchPoint: Sendable {
    let x: Float
    let y: Float
}

struct TouchEvent: Sendable {
    let timestamp: TimeInterval
    let fingerCount: Int
    let points: [TouchPoint]
    let phase: TouchPhase
}

enum TouchPhase: Sendable {
    case began
    case moved
    case ended
    case cancelled
}
```

```swift
// Sources/GesturePad/Recognition/RecognizedGesture.swift
import Foundation

enum RecognizedGesture: Equatable, Sendable {
    case threeFingerTap
    case threeFingerSwipe(SwipeDirection)
}

enum SwipeDirection: Equatable, Sendable {
    case left
    case right
}
```

- [ ] **Step 2: Write failing tests for TapRecognizer**

```swift
// Tests/GesturePadTests/TapRecognizerTests.swift
import Testing
@testable import GesturePad

@Test func validThreeFingerTap() {
    var recognizer = TapRecognizer()
    let now = Date.timeIntervalSinceReferenceDate
    let points = [TouchPoint(x: 100, y: 100), TouchPoint(x: 120, y: 100), TouchPoint(x: 140, y: 100)]

    let r1 = recognizer.process(TouchEvent(timestamp: now, fingerCount: 3, points: points, phase: .began))
    #expect(r1 == nil)

    let r2 = recognizer.process(TouchEvent(timestamp: now + 0.1, fingerCount: 3, points: points, phase: .ended))
    #expect(r2 == .threeFingerTap)
}

@Test func tooSlowRejectsAsTap() {
    var recognizer = TapRecognizer()
    let now = Date.timeIntervalSinceReferenceDate
    let points = [TouchPoint(x: 100, y: 100), TouchPoint(x: 120, y: 100), TouchPoint(x: 140, y: 100)]

    _ = recognizer.process(TouchEvent(timestamp: now, fingerCount: 3, points: points, phase: .began))
    let result = recognizer.process(TouchEvent(timestamp: now + 0.5, fingerCount: 3, points: points, phase: .ended))
    #expect(result == nil)
}

@Test func tooMuchMovementRejectsAsTap() {
    var recognizer = TapRecognizer()
    let now = Date.timeIntervalSinceReferenceDate
    let startPoints = [TouchPoint(x: 100, y: 100), TouchPoint(x: 120, y: 100), TouchPoint(x: 140, y: 100)]
    let movedPoints = [TouchPoint(x: 200, y: 200), TouchPoint(x: 220, y: 200), TouchPoint(x: 240, y: 200)]

    _ = recognizer.process(TouchEvent(timestamp: now, fingerCount: 3, points: startPoints, phase: .began))
    _ = recognizer.process(TouchEvent(timestamp: now + 0.05, fingerCount: 3, points: movedPoints, phase: .moved))
    let result = recognizer.process(TouchEvent(timestamp: now + 0.1, fingerCount: 3, points: movedPoints, phase: .ended))
    #expect(result == nil)
}

@Test func wrongFingerCountIgnored() {
    var recognizer = TapRecognizer()
    let now = Date.timeIntervalSinceReferenceDate
    let points = [TouchPoint(x: 100, y: 100), TouchPoint(x: 120, y: 100)]

    let r1 = recognizer.process(TouchEvent(timestamp: now, fingerCount: 2, points: points, phase: .began))
    #expect(r1 == nil)
    let r2 = recognizer.process(TouchEvent(timestamp: now + 0.1, fingerCount: 2, points: points, phase: .ended))
    #expect(r2 == nil)
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `swift test --filter TapRecognizerTests 2>&1`
Expected: FAIL — `TapRecognizer` not defined

- [ ] **Step 4: Implement TapRecognizer**

```swift
// Sources/GesturePad/Recognition/TapRecognizer.swift
import Foundation

struct TapRecognizer: Sendable {
    private enum State {
        case idle
        case fingersDown(startTime: TimeInterval, startPoints: [TouchPoint])
        case cancelled
    }

    private var state: State = .idle

    private let maxDuration: TimeInterval = 0.2
    private let maxDisplacement: Float = 5.0
    private let requiredFingers = 3

    mutating func process(_ event: TouchEvent) -> RecognizedGesture? {
        switch state {
        case .idle:
            if event.phase == .began && event.fingerCount == requiredFingers {
                state = .fingersDown(startTime: event.timestamp, startPoints: event.points)
            }
            return nil

        case .fingersDown(let startTime, let startPoints):
            if event.phase == .moved {
                if displacement(from: startPoints, to: event.points) > maxDisplacement {
                    state = .cancelled
                }
                return nil
            }
            if event.phase == .ended || event.phase == .cancelled {
                let duration = event.timestamp - startTime
                let moved = displacement(from: startPoints, to: event.points)
                state = .idle
                if duration <= maxDuration && moved <= maxDisplacement && event.phase == .ended {
                    return .threeFingerTap
                }
                return nil
            }
            if event.fingerCount != requiredFingers {
                state = .cancelled
            }
            return nil

        case .cancelled:
            if event.phase == .ended || event.phase == .cancelled {
                state = .idle
            }
            return nil
        }
    }

    private func displacement(from start: [TouchPoint], to end: [TouchPoint]) -> Float {
        guard !start.isEmpty && !end.isEmpty else { return 0 }
        let count = min(start.count, end.count)
        var maxDist: Float = 0
        for i in 0..<count {
            let dx = end[i].x - start[i].x
            let dy = end[i].y - start[i].y
            let dist = sqrt(dx * dx + dy * dy)
            maxDist = max(maxDist, dist)
        }
        return maxDist
    }

    mutating func reset() {
        state = .idle
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter TapRecognizerTests 2>&1`
Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add Sources/GesturePad/Recognition/ Tests/GesturePadTests/TapRecognizerTests.swift
git commit -m "feat: add TapRecognizer with state machine for 3-finger tap detection"
```

---

## Task 5: Gesture Recognition — SwipeRecognizer

**Files:**
- Create: `Sources/GesturePad/Recognition/SwipeRecognizer.swift`
- Test: `Tests/GesturePadTests/SwipeRecognizerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/GesturePadTests/SwipeRecognizerTests.swift
import Testing
@testable import GesturePad

@Test func validSwipeRight() {
    var recognizer = SwipeRecognizer()
    let now = Date.timeIntervalSinceReferenceDate
    let start = [TouchPoint(x: 100, y: 100), TouchPoint(x: 120, y: 100), TouchPoint(x: 140, y: 100)]
    let end = [TouchPoint(x: 200, y: 102), TouchPoint(x: 220, y: 102), TouchPoint(x: 240, y: 102)]

    _ = recognizer.process(TouchEvent(timestamp: now, fingerCount: 3, points: start, phase: .began))
    let result = recognizer.process(TouchEvent(timestamp: now + 0.15, fingerCount: 3, points: end, phase: .moved))
    #expect(result == .threeFingerSwipe(.right))
}

@Test func validSwipeLeft() {
    var recognizer = SwipeRecognizer()
    let now = Date.timeIntervalSinceReferenceDate
    let start = [TouchPoint(x: 200, y: 100), TouchPoint(x: 220, y: 100), TouchPoint(x: 240, y: 100)]
    let end = [TouchPoint(x: 100, y: 102), TouchPoint(x: 120, y: 102), TouchPoint(x: 140, y: 102)]

    _ = recognizer.process(TouchEvent(timestamp: now, fingerCount: 3, points: start, phase: .began))
    let result = recognizer.process(TouchEvent(timestamp: now + 0.15, fingerCount: 3, points: end, phase: .moved))
    #expect(result == .threeFingerSwipe(.left))
}

@Test func tooMuchVerticalMovementCancels() {
    var recognizer = SwipeRecognizer()
    let now = Date.timeIntervalSinceReferenceDate
    let start = [TouchPoint(x: 100, y: 100), TouchPoint(x: 120, y: 100), TouchPoint(x: 140, y: 100)]
    let end = [TouchPoint(x: 160, y: 200), TouchPoint(x: 180, y: 200), TouchPoint(x: 200, y: 200)]

    _ = recognizer.process(TouchEvent(timestamp: now, fingerCount: 3, points: start, phase: .began))
    let result = recognizer.process(TouchEvent(timestamp: now + 0.15, fingerCount: 3, points: end, phase: .moved))
    #expect(result == nil)
}

@Test func insufficientHorizontalMovement() {
    var recognizer = SwipeRecognizer()
    let now = Date.timeIntervalSinceReferenceDate
    let start = [TouchPoint(x: 100, y: 100), TouchPoint(x: 120, y: 100), TouchPoint(x: 140, y: 100)]
    let end = [TouchPoint(x: 120, y: 101), TouchPoint(x: 140, y: 101), TouchPoint(x: 160, y: 101)]

    _ = recognizer.process(TouchEvent(timestamp: now, fingerCount: 3, points: start, phase: .began))
    let result = recognizer.process(TouchEvent(timestamp: now + 0.15, fingerCount: 3, points: end, phase: .moved))
    #expect(result == nil)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter SwipeRecognizerTests 2>&1`
Expected: FAIL — `SwipeRecognizer` not defined

- [ ] **Step 3: Implement SwipeRecognizer**

```swift
// Sources/GesturePad/Recognition/SwipeRecognizer.swift
import Foundation

struct SwipeRecognizer: Sendable {
    private enum State {
        case idle
        case tracking(startPoints: [TouchPoint])
        case fired
    }

    private var state: State = .idle

    private let horizontalThreshold: Float = 50.0
    private let maxVerticalRatio: Float = 0.5
    private let requiredFingers = 3

    mutating func process(_ event: TouchEvent) -> RecognizedGesture? {
        switch state {
        case .idle:
            if event.phase == .began && event.fingerCount == requiredFingers {
                state = .tracking(startPoints: event.points)
            }
            return nil

        case .tracking(let startPoints):
            if event.fingerCount != requiredFingers {
                state = .idle
                return nil
            }
            if event.phase == .moved {
                let (dx, dy) = averageDisplacement(from: startPoints, to: event.points)
                let absDx = abs(dx)
                let absDy = abs(dy)

                if absDy > absDx * maxVerticalRatio && absDy > 20 {
                    state = .idle
                    return nil
                }

                if absDx >= horizontalThreshold {
                    state = .fired
                    let direction: SwipeDirection = dx > 0 ? .right : .left
                    return .threeFingerSwipe(direction)
                }
                return nil
            }
            if event.phase == .ended || event.phase == .cancelled {
                state = .idle
            }
            return nil

        case .fired:
            if event.phase == .ended || event.phase == .cancelled {
                state = .idle
            }
            return nil
        }
    }

    private func averageDisplacement(from start: [TouchPoint], to end: [TouchPoint]) -> (dx: Float, dy: Float) {
        let count = min(start.count, end.count)
        guard count > 0 else { return (0, 0) }
        var totalDx: Float = 0
        var totalDy: Float = 0
        for i in 0..<count {
            totalDx += end[i].x - start[i].x
            totalDy += end[i].y - start[i].y
        }
        return (totalDx / Float(count), totalDy / Float(count))
    }

    mutating func reset() {
        state = .idle
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter SwipeRecognizerTests 2>&1`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/GesturePad/Recognition/SwipeRecognizer.swift Tests/GesturePadTests/SwipeRecognizerTests.swift
git commit -m "feat: add SwipeRecognizer with horizontal threshold detection"
```

---

## Task 6: GestureRecognizer Coordinator + Debouncing

**Files:**
- Create: `Sources/GesturePad/Recognition/GestureRecognizer.swift`
- Test: `Tests/GesturePadTests/GestureRecognizerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/GesturePadTests/GestureRecognizerTests.swift
import Testing
@testable import GesturePad

@Test func coordinatorRoutesTapCorrectly() {
    var recognizer = GestureRecognizer()
    let now = Date.timeIntervalSinceReferenceDate
    let points = [TouchPoint(x: 100, y: 100), TouchPoint(x: 120, y: 100), TouchPoint(x: 140, y: 100)]

    _ = recognizer.process(TouchEvent(timestamp: now, fingerCount: 3, points: points, phase: .began))
    let result = recognizer.process(TouchEvent(timestamp: now + 0.1, fingerCount: 3, points: points, phase: .ended))
    #expect(result == .threeFingerTap)
}

@Test func debouncePreventsDoubleTrigger() {
    var recognizer = GestureRecognizer()
    let now = Date.timeIntervalSinceReferenceDate
    let points = [TouchPoint(x: 100, y: 100), TouchPoint(x: 120, y: 100), TouchPoint(x: 140, y: 100)]

    _ = recognizer.process(TouchEvent(timestamp: now, fingerCount: 3, points: points, phase: .began))
    let r1 = recognizer.process(TouchEvent(timestamp: now + 0.1, fingerCount: 3, points: points, phase: .ended))
    #expect(r1 == .threeFingerTap)

    _ = recognizer.process(TouchEvent(timestamp: now + 0.15, fingerCount: 3, points: points, phase: .began))
    let r2 = recognizer.process(TouchEvent(timestamp: now + 0.25, fingerCount: 3, points: points, phase: .ended))
    #expect(r2 == nil) // within 300ms cooldown
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter GestureRecognizerTests 2>&1`
Expected: FAIL

- [ ] **Step 3: Implement GestureRecognizer**

```swift
// Sources/GesturePad/Recognition/GestureRecognizer.swift
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter GestureRecognizerTests 2>&1`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/GesturePad/Recognition/GestureRecognizer.swift Tests/GesturePadTests/GestureRecognizerTests.swift
git commit -m "feat: add GestureRecognizer coordinator with debouncing"
```

---

## Task 7: ActionMapper

**Files:**
- Create: `Sources/GesturePad/Actions/ActionMapper.swift`
- Test: `Tests/GesturePadTests/ActionMapperTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/GesturePadTests/ActionMapperTests.swift
import Testing
@testable import GesturePad

@Test func mapsGestureToConfiguredAction() {
    let store = ConfigStore(defaults: .init(suiteName: "test-mapper-\(UUID().uuidString)")!)
    let mapper = ActionMapper(configStore: store)
    let action = mapper.action(for: .threeFingerTap)
    #expect(action == .middleClick)
}

@Test func disabledGestureReturnsNil() {
    let store = ConfigStore(defaults: .init(suiteName: "test-mapper-disabled-\(UUID().uuidString)")!)
    store.setAction(.disabled, for: .threeFingerTap)
    let mapper = ActionMapper(configStore: store)
    let action = mapper.action(for: .threeFingerTap)
    #expect(action == nil)
}

@Test func mapsRecognizedGestureToGestureType() {
    let result = ActionMapper.gestureType(from: .threeFingerTap)
    #expect(result == .threeFingerTap)

    let swipeResult = ActionMapper.gestureType(from: .threeFingerSwipe(.left))
    #expect(swipeResult == .threeFingerSwipeLeft)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ActionMapperTests 2>&1`
Expected: FAIL

- [ ] **Step 3: Implement ActionMapper**

```swift
// Sources/GesturePad/Actions/ActionMapper.swift
import Foundation

final class ActionMapper: Sendable {
    private let configStore: ConfigStore

    init(configStore: ConfigStore) {
        self.configStore = configStore
    }

    func action(for gestureType: GestureType) -> ActionType? {
        let action = configStore.action(for: gestureType)
        if action == .disabled { return nil }
        return action
    }

    func action(for gesture: RecognizedGesture) -> ActionType? {
        action(for: Self.gestureType(from: gesture))
    }

    static func gestureType(from gesture: RecognizedGesture) -> GestureType {
        switch gesture {
        case .threeFingerTap: .threeFingerTap
        case .threeFingerSwipe(.left): .threeFingerSwipeLeft
        case .threeFingerSwipe(.right): .threeFingerSwipeRight
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ActionMapperTests 2>&1`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/GesturePad/Actions/ActionMapper.swift Tests/GesturePadTests/ActionMapperTests.swift
git commit -m "feat: add ActionMapper for gesture-to-action lookup"
```

---

## Task 8: ActionExecutor — CGEvent Posting

**Files:**
- Create: `Sources/GesturePad/Actions/ActionExecutor.swift`

No unit tests — requires Accessibility permissions. Manual testing only.

- [ ] **Step 1: Implement ActionExecutor**

```swift
// Sources/GesturePad/Actions/ActionExecutor.swift
import CoreGraphics
import Foundation
import os

final class ActionExecutor: Sendable {
    private let logger = Logger(subsystem: "com.gesturepad", category: "ActionExecutor")

    func execute(_ action: ActionType) {
        switch action {
        case .middleClick:
            postMiddleClick()
        case .keyboardShortcut(let modifiers, let keyCode):
            postKeyboardShortcut(modifiers: modifiers, keyCode: keyCode)
        case .disabled:
            break
        }
    }

    private func postMiddleClick() {
        let position = CGEvent(source: nil)?.location ?? .zero

        guard let downEvent = CGEvent(mouseEventSource: nil, mouseType: .otherMouseDown,
                                       mouseCursorPosition: position, mouseButton: .center),
              let upEvent = CGEvent(mouseEventSource: nil, mouseType: .otherMouseUp,
                                     mouseCursorPosition: position, mouseButton: .center) else {
            logger.error("Failed to create middle click events")
            return
        }

        downEvent.post(tap: .cghidEventTap)
        upEvent.post(tap: .cghidEventTap)
        logger.debug("Posted middle click at \(position.x), \(position.y)")
    }

    private func postKeyboardShortcut(modifiers: UInt64, keyCode: UInt16) {
        guard let downEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let upEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            logger.error("Failed to create keyboard events")
            return
        }

        let flags = CGEventFlags(rawValue: modifiers)
        downEvent.flags = flags
        upEvent.flags = flags

        downEvent.post(tap: .cghidEventTap)
        upEvent.post(tap: .cghidEventTap)
        logger.debug("Posted key \(keyCode) with modifiers \(modifiers)")
    }
}
```

- [ ] **Step 2: Verify build succeeds**

Run: `swift build 2>&1`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/GesturePad/Actions/ActionExecutor.swift
git commit -m "feat: add ActionExecutor for CGEvent posting (middle click + keyboard shortcuts)"
```

---

## Task 9: TouchDetector — MultitouchSupport Bridge

**Files:**
- Create: `Sources/GesturePad/Detection/MultitouchBridge.swift`
- Create: `Sources/GesturePad/Detection/TouchDetector.swift`

No unit tests — requires physical trackpad. Manual testing only.

- [ ] **Step 1: Implement MultitouchBridge**

```swift
// Sources/GesturePad/Detection/MultitouchBridge.swift
import Foundation

// C-level types from MultitouchSupport.framework (private)
typealias MTDeviceRef = UnsafeMutableRawPointer

struct MTTouch {
    var frame: Int32
    var timestamp: Double
    var identifier: Int32
    var state: Int32           // 1=notTracking 2=startInRange 3=hoverInRange 4=touching 5=outOfRange
    var fingerID: Int32
    var handID: Int32
    var normalizedVector: SIMD2<Float>   // position 0..1
    var zTotal: Float
    var unused3: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var absoluteVector: SIMD2<Float>     // absolute position
    var unused4: Int32
    var unused5: Int32
    var zDensity: Float
}

typealias MTContactCallback = @convention(c) (
    MTDeviceRef,                        // device
    UnsafeMutablePointer<MTTouch>?,     // touches
    Int32,                              // touch count
    Double,                             // timestamp
    Int32                               // frame
) -> Int32

// Dynamically loaded function pointers
final class MultitouchFunctions: @unchecked Sendable {
    static let shared = MultitouchFunctions()

    let createDevice: (@convention(c) (Int32) -> MTDeviceRef?)?
    let getDeviceList: (@convention(c) (UnsafeMutablePointer<MTDeviceRef?>, Int32) -> Int32)?
    let deviceCount: (@convention(c) () -> Int32)?
    let registerContactCallback: (@convention(c) (MTDeviceRef, MTContactCallback) -> Void)?
    let unregisterContactCallback: (@convention(c) (MTDeviceRef, MTContactCallback) -> Void)?
    let start: (@convention(c) (MTDeviceRef, Int32) -> Int32)?
    let stop: (@convention(c) (MTDeviceRef) -> Void)?
    let isRunning: (@convention(c) (MTDeviceRef) -> Bool)?

    let handle: UnsafeMutableRawPointer?

    private init() {
        handle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW)

        guard let handle else {
            createDevice = nil; getDeviceList = nil; deviceCount = nil
            registerContactCallback = nil; unregisterContactCallback = nil
            start = nil; stop = nil; isRunning = nil
            return
        }

        createDevice = unsafeBitCast(dlsym(handle, "MTDeviceCreateFromDeviceID"), to: Optional.self)
        getDeviceList = unsafeBitCast(dlsym(handle, "MTDeviceCreateList"), to: Optional.self)
        deviceCount = unsafeBitCast(dlsym(handle, "MTDeviceCountDevices"), to: Optional.self)
        registerContactCallback = unsafeBitCast(dlsym(handle, "MTRegisterContactFrameCallback"), to: Optional.self)
        unregisterContactCallback = unsafeBitCast(dlsym(handle, "MTUnregisterContactFrameCallback"), to: Optional.self)
        start = unsafeBitCast(dlsym(handle, "MTDeviceStart"), to: Optional.self)
        stop = unsafeBitCast(dlsym(handle, "MTDeviceStop"), to: Optional.self)
        isRunning = unsafeBitCast(dlsym(handle, "MTDeviceIsRunning"), to: Optional.self)
    }

    var isAvailable: Bool { handle != nil }
}
```

- [ ] **Step 2: Implement TouchDetector**

```swift
// Sources/GesturePad/Detection/TouchDetector.swift
import Foundation
import os

final class TouchDetector: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.gesturepad", category: "TouchDetector")
    private var devices: [MTDeviceRef] = []
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
        guard mt.isAvailable, let getList = mt.getDeviceList,
              let register = mt.registerContactCallback,
              let startDevice = mt.start else {
            logger.error("MultitouchSupport framework not available")
            return false
        }

        let count = mt.deviceCount?() ?? 0
        guard count > 0 else {
            logger.warning("No multitouch devices found")
            return false
        }

        var deviceList = [MTDeviceRef?](repeating: nil, count: Int(count))
        _ = getList(&deviceList, count)

        for device in deviceList {
            guard let device else { continue }
            register(device, touchCallback)
            _ = startDevice(device, 0)
            devices.append(device)
        }

        isRunning = true
        logger.info("Started tracking \(self.devices.count) multitouch device(s)")
        return true
    }

    func stop() {
        let mt = MultitouchFunctions.shared
        for device in devices {
            mt.unregisterContactCallback?(device, touchCallback)
            mt.stop?(device)
        }
        devices.removeAll()
        isRunning = false
        logger.info("Stopped multitouch tracking")
    }
}

private let touchCallback: MTContactCallback = { _, touches, touchCount, timestamp, _ in
    guard let touches, touchCount > 0 else { return 0 }

    let count = Int(touchCount)
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

    guard touchingCount > 0 else { return 0 }

    // Determine phase from touch states
    let allTouching = (0..<count).allSatisfy { touches[$0].state >= 4 }
    let anyEnding = (0..<count).contains { touches[$0].state >= 5 }

    let phase: TouchPhase
    if anyEnding {
        phase = .ended
    } else if allTouching {
        // We track frame-to-frame, so if we're getting callbacks, it's either began or moved
        phase = .moved
    } else {
        phase = .began
    }

    let event = TouchEvent(timestamp: timestamp, fingerCount: touchingCount, points: points, phase: phase)
    TouchDetector.shared.onTouchEvent?(event)

    return 0
}
```

- [ ] **Step 3: Verify build succeeds**

Run: `swift build 2>&1`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add Sources/GesturePad/Detection/
git commit -m "feat: add TouchDetector with MultitouchSupport.framework bridge"
```

---

## Task 10: Settings UI — SwiftUI Views

**Files:**
- Create: `Sources/GesturePad/UI/SettingsView.swift`
- Create: `Sources/GesturePad/UI/GestureRowView.swift`
- Create: `Sources/GesturePad/UI/KeyRecorderView.swift`
- Create: `Sources/GesturePad/UI/MenuBarView.swift`

- [ ] **Step 1: Create GestureRowView**

```swift
// Sources/GesturePad/UI/GestureRowView.swift
import SwiftUI

struct GestureRowView: View {
    let gestureType: GestureType
    @Binding var action: ActionType
    @State private var isRecordingShortcut = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(gestureType.displayName)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(gestureType.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isRecordingShortcut {
                KeyRecorderView { modifiers, keyCode in
                    action = .keyboardShortcut(modifiers: modifiers, keyCode: keyCode)
                    isRecordingShortcut = false
                } onCancel: {
                    isRecordingShortcut = false
                }
                .frame(width: 160)
            } else {
                actionPicker
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var actionPicker: some View {
        Menu {
            Button("🖱️ Middle Click") { action = .middleClick }
            Button("⌨️ Record Shortcut…") { isRecordingShortcut = true }
            Divider()
            Button("Disabled") { action = .disabled }
        } label: {
            Text(action.displayName)
                .font(.caption)
                .frame(minWidth: 120, alignment: .leading)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 160)
    }
}
```

- [ ] **Step 2: Create KeyRecorderView**

```swift
// Sources/GesturePad/UI/KeyRecorderView.swift
import SwiftUI
import Carbon.HIToolbox

struct KeyRecorderView: View {
    let onRecord: (UInt64, UInt16) -> Void
    let onCancel: () -> Void

    @State private var displayText = "Press shortcut…"
    @State private var monitor: Any?

    var body: some View {
        Text(displayText)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor, lineWidth: 1)
            )
            .onAppear { startListening() }
            .onDisappear { stopListening() }
            .onKeyPress(.escape) {
                onCancel()
                return .handled
            }
    }

    private func startListening() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let cgFlags = CGEventFlags(rawValue: UInt64(modifiers.rawValue))
            let keyCode = UInt16(event.keyCode)

            if keyCode == UInt16(kVK_Escape) {
                onCancel()
            } else {
                onRecord(cgFlags.rawValue, keyCode)
            }
            return nil
        }
    }

    private func stopListening() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}
```

- [ ] **Step 3: Create SettingsView**

```swift
// Sources/GesturePad/UI/SettingsView.swift
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State var configStore: ConfigStore

    var body: some View {
        Form {
            Section("Gesture Mappings") {
                ForEach(GestureType.allCases, id: \.self) { gestureType in
                    GestureRowView(
                        gestureType: gestureType,
                        action: Binding(
                            get: { configStore.action(for: gestureType) },
                            set: { configStore.setAction($0, for: gestureType) }
                        )
                    )
                }
            }

            Section("General") {
                Toggle("Enable Gestures", isOn: $configStore.isEnabled)
                LaunchAtLoginToggle()
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 450, minHeight: 300)
    }
}

struct LaunchAtLoginToggle: View {
    @State private var isEnabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Toggle("Launch at Login", isOn: $isEnabled)
            .onChange(of: isEnabled) { _, newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    isEnabled = !newValue
                }
            }
    }
}
```

- [ ] **Step 4: Create MenuBarView**

```swift
// Sources/GesturePad/UI/MenuBarView.swift
import SwiftUI

struct MenuBarView: View {
    @State var configStore: ConfigStore
    let onOpenSettings: () -> Void

    private var activeCount: Int {
        GestureType.allCases.filter { configStore.action(for: $0) != .disabled }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("GesturePad")
                        .font(.headline)
                    Text("\(activeCount) gestures active")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $configStore.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            Button(action: onOpenSettings) {
                Label("Settings…", systemImage: "gear")
            }
            .keyboardShortcut(",", modifiers: .command)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)

            Divider()

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Label("Quit", systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: .command)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
        }
        .frame(width: 240)
    }
}
```

- [ ] **Step 5: Verify build succeeds**

Run: `swift build 2>&1`
Expected: Build succeeds

- [ ] **Step 6: Commit**

```bash
git add Sources/GesturePad/UI/
git commit -m "feat: add Settings, MenuBar, GestureRow, and KeyRecorder SwiftUI views"
```

---

## Task 11: Wire Everything Together — App Entry Point

**Files:**
- Modify: `Sources/GesturePad/App/GesturePadApp.swift`
- Create: `Sources/GesturePad/App/GestureEngine.swift`

- [ ] **Step 1: Create GestureEngine to coordinate detection → recognition → action**

```swift
// Sources/GesturePad/App/GestureEngine.swift
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
```

- [ ] **Step 2: Update GesturePadApp with full wiring**

```swift
// Sources/GesturePad/App/GesturePadApp.swift
import SwiftUI

@main
struct GesturePadApp: App {
    @State private var engine = GestureEngine()

    var body: some Scene {
        MenuBarExtra("GesturePad", systemImage: "hand.tap") {
            MenuBarView(configStore: engine.configStore) {
                NSApp.activate()
                if let window = NSApp.windows.first(where: { $0.title == "GesturePad Settings" }) {
                    window.makeKeyAndOrderFront(nil)
                } else {
                    openSettings()
                }
            }
        }
        .menuBarExtraStyle(.window)

        Window("GesturePad Settings", id: "settings") {
            SettingsView(configStore: engine.configStore)
        }
        .defaultSize(width: 500, height: 350)
        .windowResizability(.contentSize)
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func checkAccessibilityAndStart() {
        if AXIsProcessTrusted() {
            engine.start()
        }
    }
}
```

- [ ] **Step 3: Verify build succeeds**

Run: `swift build 2>&1`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add Sources/GesturePad/App/
git commit -m "feat: wire GestureEngine and full app entry point with MenuBarExtra"
```

---

## Task 12: Accessibility Permission Onboarding

**Files:**
- Create: `Sources/GesturePad/App/AccessibilityChecker.swift`
- Modify: `Sources/GesturePad/App/GesturePadApp.swift`

- [ ] **Step 1: Implement AccessibilityChecker**

```swift
// Sources/GesturePad/App/AccessibilityChecker.swift
import Foundation
import AppKit
import os

@Observable
final class AccessibilityChecker {
    var isGranted: Bool = false
    private var timer: Timer?
    private let logger = Logger(subsystem: "com.gesturepad", category: "Accessibility")

    init() {
        isGranted = AXIsProcessTrusted()
    }

    func checkAndPrompt() {
        isGranted = AXIsProcessTrusted()
        if !isGranted {
            promptForAccess()
            startPolling()
        }
    }

    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let granted = AXIsProcessTrusted()
            if granted != self.isGranted {
                self.isGranted = granted
                if granted {
                    self.timer?.invalidate()
                    self.timer = nil
                    self.logger.info("Accessibility permission granted")
                }
            }
        }
    }

    private func promptForAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
```

- [ ] **Step 2: Integrate into GesturePadApp — add `.onAppear` to check permissions and start engine when granted**

Update `GesturePadApp.swift` to add:

```swift
@State private var accessibilityChecker = AccessibilityChecker()
```

And in the `MenuBarExtra` content, add at the top:

```swift
.task {
    accessibilityChecker.checkAndPrompt()
}
.onChange(of: accessibilityChecker.isGranted) { _, granted in
    if granted { engine.start() }
}
.onChange(of: engine.configStore.isEnabled) { _, enabled in
    if enabled && accessibilityChecker.isGranted { engine.start() }
    else if !enabled { engine.stop() }
}
```

- [ ] **Step 3: Verify build succeeds**

Run: `swift build 2>&1`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add Sources/GesturePad/App/
git commit -m "feat: add accessibility permission checker with polling and onboarding prompt"
```

---

## Task 13: Manual End-to-End Testing

- [ ] **Step 1: Build and run the app**

Run: `swift build && .build/debug/GesturePad &`
Expected: Menu bar icon appears

- [ ] **Step 2: Grant Accessibility permission when prompted**

System Settings > Privacy & Security > Accessibility > enable GesturePad

- [ ] **Step 3: Test 3-finger tap → middle click**

Open a browser with multiple tabs. 3-finger tap on a tab → it should close.

- [ ] **Step 4: Test 3-finger swipe right → ⌘+Tab**

Have multiple apps open. 3-finger swipe right → app switcher should appear.

- [ ] **Step 5: Test 3-finger swipe left → ⌘+Shift+Tab**

3-finger swipe left → app switcher should go in reverse direction.

- [ ] **Step 6: Test settings window**

Click menu bar icon → Settings… → remap a gesture → verify new mapping works.

- [ ] **Step 7: Test enable/disable toggle**

Toggle off → gestures should stop working. Toggle on → gestures resume.

- [ ] **Step 8: Commit any fixes from manual testing**

```bash
git add -A
git commit -m "fix: adjustments from manual end-to-end testing"
```
