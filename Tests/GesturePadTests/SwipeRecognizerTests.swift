import Foundation
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
