import Foundation
import Testing
@testable import GesturePad

@Test func gestureTypeRoundTrip() throws {
    let gestures: [GestureType] = [.threeFingerTap, .threeFingerSwipeLeft, .threeFingerSwipeRight]
    let data = try JSONEncoder().encode(gestures)
    let decoded = try JSONDecoder().decode([GestureType].self, from: data)
    #expect(decoded == gestures)
}

@Test func actionTypeRoundTrip() throws {
    let actions: [ActionType] = [
        .middleClick,
        .keyboardShortcut(modifiers: 256, keyCode: 48), // ⌘+Tab
        .disabled,
    ]
    let data = try JSONEncoder().encode(actions)
    let decoded = try JSONDecoder().decode([ActionType].self, from: data)
    #expect(decoded == actions)
}
