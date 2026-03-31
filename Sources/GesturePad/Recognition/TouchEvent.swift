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
