import Foundation
import os

private let tapLogger = Logger(subsystem: "com.gesturepad", category: "TapRecognizer")

struct TapRecognizer: Sendable {
    private enum State {
        case idle
        case fingersDown(startTime: TimeInterval, startPoints: [TouchPoint])
        case cancelled
    }

    private var state: State = .idle

    // Tolerant thresholds for real trackpad use
    private let maxDuration: TimeInterval = 0.4    // 400ms — real 3-finger taps take ~200-350ms
    private let maxDisplacement: Float = 50.0      // on 0-1000 scale = 5% of trackpad
    private let requiredFingers = 3

    mutating func process(_ event: TouchEvent) -> RecognizedGesture? {
        switch state {
        case .idle:
            // Start tracking when 3 fingers touch simultaneously
            if event.fingerCount >= requiredFingers && event.phase == .moved {
                state = .fingersDown(startTime: event.timestamp, startPoints: event.points)
                tapLogger.debug("3-finger touch started")
            }
            return nil

        case .fingersDown(let startTime, let startPoints):
            // Still touching — check for excessive movement
            if event.phase == .moved && event.fingerCount >= requiredFingers {
                if displacement(from: startPoints, to: event.points) > maxDisplacement {
                    tapLogger.debug("Tap cancelled: too much movement")
                    state = .cancelled
                }
                return nil
            }

            // Fingers lifted
            if event.phase == .ended {
                let duration = event.timestamp - startTime
                let moved = displacement(from: startPoints, to: event.points)
                state = .idle

                if duration <= maxDuration && moved <= maxDisplacement {
                    tapLogger.info("✅ 3-finger tap recognized! duration=\(duration)s")
                    return .threeFingerTap
                } else {
                    tapLogger.debug("Tap rejected: duration=\(duration)s displacement=\(moved)")
                }
                return nil
            }

            // Wrong finger count
            if event.fingerCount < requiredFingers {
                state = .cancelled
            }
            return nil

        case .cancelled:
            if event.phase == .ended {
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
