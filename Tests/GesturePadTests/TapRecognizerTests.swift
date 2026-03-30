import Foundation
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
