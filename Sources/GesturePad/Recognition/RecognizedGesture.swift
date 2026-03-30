import Foundation

enum RecognizedGesture: Equatable, Sendable {
    case threeFingerTap
    case threeFingerSwipe(SwipeDirection)
}

enum SwipeDirection: Equatable, Sendable {
    case left
    case right
}
