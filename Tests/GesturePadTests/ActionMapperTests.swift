import Foundation
import Testing
@testable import GesturePad

@Test func mapsGestureToConfiguredAction() {
    let store = ConfigStore(defaults: .init(suiteName: "test-mapper-\(UUID().uuidString)")!)
    let mapper = ActionMapper(configStore: store)
    let action = mapper.action(for: GestureType.threeFingerTap)
    #expect(action == .middleClick)
}

@Test func disabledGestureReturnsNil() {
    let store = ConfigStore(defaults: .init(suiteName: "test-mapper-disabled-\(UUID().uuidString)")!)
    store.setAction(.disabled, for: .threeFingerTap)
    let mapper = ActionMapper(configStore: store)
    let action = mapper.action(for: GestureType.threeFingerTap)
    #expect(action == nil)
}

@Test func mapsRecognizedGestureToGestureType() {
    let result = ActionMapper.gestureType(from: .threeFingerTap)
    #expect(result == .threeFingerTap)

    let swipeResult = ActionMapper.gestureType(from: .threeFingerSwipe(.left))
    #expect(swipeResult == .threeFingerSwipeLeft)
}
