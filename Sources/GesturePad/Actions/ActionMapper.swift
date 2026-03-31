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
