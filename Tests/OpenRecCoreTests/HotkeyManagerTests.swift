import Testing
@testable import OpenRecCore
#if os(macOS)
import Carbon
#endif

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

@Test func systemHotkeyRegistryRegistersHotkeyWithCarbonAdapterAndTracksToken() throws {
    let hotkey = Hotkey(keyCode: 49, modifiers: [.command, .shift])
    let adapter = MockCarbonHotkeyAdapter(registerResult: .success(CarbonHotkeyToken(rawValue: 100)))
    let registry = SystemHotkeyRegistry(adapter: adapter)

    try registry.register(hotkey)

    #expect(adapter.registeredHotkeys == [
        .init(keyCode: 49, modifiers: UInt32(cmdKey | shiftKey))
    ])
    #expect(registry.contains(hotkey))
}

@Test func systemHotkeyRegistryUnregistersExistingTokenBeforeRegisteringReplacement() throws {
    let firstHotkey = Hotkey(keyCode: 49, modifiers: [.command])
    let replacementHotkey = Hotkey(keyCode: 12, modifiers: [.option])
    let adapter = MockCarbonHotkeyAdapter(registerResults: [
        .success(CarbonHotkeyToken(rawValue: 100)),
        .success(CarbonHotkeyToken(rawValue: 200))
    ])
    let registry = SystemHotkeyRegistry(adapter: adapter)

    try registry.register(firstHotkey)
    try registry.register(replacementHotkey)

    #expect(adapter.calls == [
        .register(.init(keyCode: 49, modifiers: UInt32(cmdKey))),
        .unregister(CarbonHotkeyToken(rawValue: 100)),
        .register(.init(keyCode: 12, modifiers: UInt32(optionKey)))
    ])
    #expect(adapter.unregisteredTokens == [CarbonHotkeyToken(rawValue: 100)])
    #expect(registry.contains(firstHotkey) == false)
    #expect(registry.contains(replacementHotkey))
}

@Test func systemHotkeyRegistryRegistrationFailureDoesNotTrackHotkey() {
    let hotkey = Hotkey(keyCode: 49, modifiers: [.command])
    let adapter = MockCarbonHotkeyAdapter(
        registerResult: .failure(.registrationFailed("RegisterEventHotKey failed with status -9876"))
    )
    let registry = SystemHotkeyRegistry(adapter: adapter)

    #expect(throws: HotkeyRegistrationError.registrationFailed("RegisterEventHotKey failed with status -9876")) {
        try registry.register(hotkey)
    }
    #expect(registry.contains(hotkey) == false)
}

@Test func hotkeyManagerDoesNotSaveHotkeyWhenSystemRegistryRegistrationFails() {
    let hotkey = Hotkey(keyCode: 49, modifiers: [.command])
    let adapter = MockCarbonHotkeyAdapter(registerResult: .failure(.registrationFailed("system rejected hotkey")))
    let registry = SystemHotkeyRegistry(adapter: adapter)
    let manager = HotkeyManager(registry: registry)

    #expect(throws: HotkeyRegistrationError.registrationFailed("system rejected hotkey")) {
        try manager.saveAndRegister(hotkey)
    }
    #expect(manager.savedHotkey == nil)
    #expect(registry.contains(hotkey) == false)
}

@Test func systemHotkeyRegistryUnregisterCleansStoredToken() throws {
    let hotkey = Hotkey(keyCode: 49, modifiers: [.control])
    let adapter = MockCarbonHotkeyAdapter(registerResult: .success(CarbonHotkeyToken(rawValue: 100)))
    let registry = SystemHotkeyRegistry(adapter: adapter)

    try registry.register(hotkey)
    registry.unregister(hotkey)

    #expect(adapter.unregisteredTokens == [CarbonHotkeyToken(rawValue: 100)])
    #expect(registry.contains(hotkey) == false)
}

@Test func systemHotkeyRegistryMapsAllSupportedModifiersAndKeyCodeToCarbonHotkey() throws {
    let hotkey = Hotkey(keyCode: 36, modifiers: [.command, .option, .control, .shift])
    let adapter = MockCarbonHotkeyAdapter(registerResult: .success(CarbonHotkeyToken(rawValue: 100)))
    let registry = SystemHotkeyRegistry(adapter: adapter)

    try registry.register(hotkey)

    #expect(adapter.registeredHotkeys == [
        .init(keyCode: 36, modifiers: UInt32(cmdKey | optionKey | controlKey | shiftKey))
    ])
}

private final class MockCarbonHotkeyAdapter: CarbonHotkeyRegistering, @unchecked Sendable {
    enum Call: Equatable {
        case register(CarbonHotkey)
        case unregister(CarbonHotkeyToken)
    }

    var calls: [Call] = []
    var registeredHotkeys: [CarbonHotkey] = []
    var unregisteredTokens: [CarbonHotkeyToken] = []
    private var registerResults: [Result<CarbonHotkeyToken, HotkeyRegistrationError>]

    init(registerResult: Result<CarbonHotkeyToken, HotkeyRegistrationError>) {
        self.registerResults = [registerResult]
    }

    init(registerResults: [Result<CarbonHotkeyToken, HotkeyRegistrationError>]) {
        self.registerResults = registerResults
    }

    func register(_ hotkey: CarbonHotkey) throws -> CarbonHotkeyToken {
        calls.append(.register(hotkey))
        registeredHotkeys.append(hotkey)
        return try registerResults.removeFirst().get()
    }

    func unregister(_ token: CarbonHotkeyToken) {
        calls.append(.unregister(token))
        unregisteredTokens.append(token)
    }
}
