import CoreGraphics
import Foundation
import os

final class ActionExecutor: Sendable {
    private let logger = Logger(subsystem: "com.gesturepad", category: "ActionExecutor")

    func execute(_ action: ActionType) {
        switch action {
        case .middleClick:
            postMiddleClick()
        case .keyboardShortcut(let modifiers, let keyCode):
            postKeyboardShortcut(modifiers: modifiers, keyCode: keyCode)
        case .disabled:
            break
        }
    }

    private func postMiddleClick() {
        let position = CGEvent(source: nil)?.location ?? .zero

        guard let downEvent = CGEvent(mouseEventSource: nil, mouseType: .otherMouseDown,
                                       mouseCursorPosition: position, mouseButton: .center),
              let upEvent = CGEvent(mouseEventSource: nil, mouseType: .otherMouseUp,
                                     mouseCursorPosition: position, mouseButton: .center) else {
            logger.error("Failed to create middle click events")
            return
        }

        downEvent.post(tap: .cghidEventTap)
        upEvent.post(tap: .cghidEventTap)
        logger.debug("Posted middle click at \(position.x), \(position.y)")
    }

    private func postKeyboardShortcut(modifiers: UInt64, keyCode: UInt16) {
        guard let downEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let upEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            logger.error("Failed to create keyboard events")
            return
        }

        let flags = CGEventFlags(rawValue: modifiers)
        downEvent.flags = flags
        upEvent.flags = flags

        downEvent.post(tap: .cghidEventTap)
        upEvent.post(tap: .cghidEventTap)
        logger.debug("Posted key \(keyCode) with modifiers \(modifiers)")
    }
}
