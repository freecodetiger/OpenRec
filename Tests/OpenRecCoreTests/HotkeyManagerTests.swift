import Testing
@testable import OpenRecCore

@Test func hotkeyManagerRejectsConflictingHotkeyBeforeSaving() {
    let existing = Hotkey(keyCode: 49, modifiers: [.command, .shift])
    let registry = InMemoryHotkeyRegistry(registeredHotkeys: [existing])
    let manager = HotkeyManager(registry: registry)

    #expect(throws: OpenRecError.hotkeyConflict) {
        try manager.saveAndRegister(existing)
    }
    #expect(manager.savedHotkey == nil)
}

@Test func hotkeyManagerExposesRegistrationFailureAndDoesNotSaveHotkey() {
    let hotkey = Hotkey(keyCode: 49, modifiers: [.command, .shift])
    let registry = InMemoryHotkeyRegistry(registrationFailure: .registrationFailed("system rejected hotkey"))
    let manager = HotkeyManager(registry: registry)

    #expect(throws: HotkeyRegistrationError.registrationFailed("system rejected hotkey")) {
        try manager.saveAndRegister(hotkey)
    }
    #expect(manager.savedHotkey == nil)
}

@Test func hotkeyManagerSavesHotkeyAfterSuccessfulRegistration() throws {
    let hotkey = Hotkey(keyCode: 49, modifiers: [.command, .shift])
    let registry = InMemoryHotkeyRegistry()
    let manager = HotkeyManager(registry: registry)

    try manager.saveAndRegister(hotkey)

    #expect(manager.savedHotkey == hotkey)
    #expect(registry.contains(hotkey))
}
