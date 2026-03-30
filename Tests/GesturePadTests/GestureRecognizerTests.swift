import Foundation
import Testing
@testable import GesturePad

@Test func coordinatorRoutesTapCorrectly() {
    var recognizer = GestureRecognizer()
    let now = Date.timeIntervalSinceReferenceDate
    let points = [TouchPoint(x: 100, y: 100), TouchPoint(x: 120, y: 100), TouchPoint(x: 140, y: 100)]

    _ = recognizer.process(TouchEvent(timestamp: now, fingerCount: 3, points: points, phase: .moved))
    let result = recognizer.process(TouchEvent(timestamp: now + 0.1, fingerCount: 3, points: points, phase: .ended))
    #expect(result == .threeFingerTap)
}

@Test func debouncePreventsDoubleTrigger() {
    var recognizer = GestureRecognizer()
    let now = Date.timeIntervalSinceReferenceDate
    let points = [TouchPoint(x: 100, y: 100), TouchPoint(x: 120, y: 100), TouchPoint(x: 140, y: 100)]

    _ = recognizer.process(TouchEvent(timestamp: now, fingerCount: 3, points: points, phase: .moved))
    let r1 = recognizer.process(TouchEvent(timestamp: now + 0.1, fingerCount: 3, points: points, phase: .ended))
    #expect(r1 == .threeFingerTap)

    _ = recognizer.process(TouchEvent(timestamp: now + 0.15, fingerCount: 3, points: points, phase: .moved))
    let r2 = recognizer.process(TouchEvent(timestamp: now + 0.25, fingerCount: 3, points: points, phase: .ended))
    #expect(r2 == nil) // within 300ms cooldown
}

