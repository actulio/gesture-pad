import CoreGraphics
import Foundation
import Observation

@Observable
final class ConfigStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private static let mappingsKey = "gestureMappings"
    private static let enabledKey = "gesturesEnabled"

    private(set) var mappings: [GestureType: ActionType]
    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.enabledKey) }
    }

    static let defaultMappings: [GestureType: ActionType] = [
        .threeFingerTap: .middleClick,
        .threeFingerSwipeRight: .keyboardShortcut(
            modifiers: CGEventFlags.maskCommand.rawValue,
            keyCode: 48
        ),
        .threeFingerSwipeLeft: .keyboardShortcut(
            modifiers: CGEventFlags([.maskCommand, .maskShift]).rawValue,
            keyCode: 48
        ),
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: Self.mappingsKey),
           let decoded = try? JSONDecoder().decode([GestureType: ActionType].self, from: data) {
            self.mappings = decoded
        } else {
            self.mappings = Self.defaultMappings
        }

        if defaults.object(forKey: Self.enabledKey) != nil {
            self.isEnabled = defaults.bool(forKey: Self.enabledKey)
        } else {
            self.isEnabled = true
        }
    }

    func action(for gesture: GestureType) -> ActionType {
        mappings[gesture] ?? .disabled
    }

    func setAction(_ action: ActionType, for gesture: GestureType) {
        mappings[gesture] = action
        if let data = try? JSONEncoder().encode(mappings) {
            defaults.set(data, forKey: Self.mappingsKey)
        }
    }
}
