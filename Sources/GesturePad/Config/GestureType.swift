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
