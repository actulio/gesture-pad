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
