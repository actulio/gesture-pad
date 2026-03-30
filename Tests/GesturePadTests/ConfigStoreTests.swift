import Foundation
import Testing
@testable import GesturePad

@Test func defaultMappingsAreSet() {
    let store = ConfigStore(defaults: .init(suiteName: "test-defaults-\(UUID().uuidString)")!)
    let mapping = store.action(for: .threeFingerTap)
    #expect(mapping == .middleClick)
}

@Test func saveAndLoadCustomMapping() {
    let defaults = UserDefaults(suiteName: "test-save-\(UUID().uuidString)")!
    let store = ConfigStore(defaults: defaults)
    store.setAction(.keyboardShortcut(modifiers: 256, keyCode: 48), for: .threeFingerTap)

    let store2 = ConfigStore(defaults: defaults)
    #expect(store2.action(for: .threeFingerTap) == .keyboardShortcut(modifiers: 256, keyCode: 48))
}

@Test func isEnabledDefaultsToTrue() {
    let store = ConfigStore(defaults: .init(suiteName: "test-enabled-\(UUID().uuidString)")!)
    #expect(store.isEnabled == true)
}
