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
            if (event.phase == .began || event.phase == .moved) && event.fingerCount == requiredFingers {
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
