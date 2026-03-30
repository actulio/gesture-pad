import Foundation
import CoreGraphics

enum ActionType: Codable, Hashable, Sendable {
    case middleClick
    case keyboardShortcut(modifiers: UInt64, keyCode: UInt16)
    case disabled

    var displayName: String {
        switch self {
        case .middleClick:
            "🖱️ Middle Click"
        case .keyboardShortcut(let modifiers, let keyCode):
            "⌨️ \(Self.formatShortcut(modifiers: modifiers, keyCode: keyCode))"
        case .disabled:
            "Disabled"
        }
    }

    static func formatShortcut(modifiers: UInt64, keyCode: UInt16) -> String {
        var parts: [String] = []
        let flags = CGEventFlags(rawValue: modifiers)
        if flags.contains(.maskControl) { parts.append("⌃") }
        if flags.contains(.maskAlternate) { parts.append("⌥") }
        if flags.contains(.maskShift) { parts.append("⇧") }
        if flags.contains(.maskCommand) { parts.append("⌘") }
        parts.append(KeyCodeNames.name(for: keyCode))
        return parts.joined()
    }
}
