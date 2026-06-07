public enum HotkeyRegistrationError: Error, Equatable, Sendable {
    case registrationFailed(String)
}

public protocol HotkeyRegistry: AnyObject, Sendable {
    func contains(_ hotkey: Hotkey) -> Bool
    func register(_ hotkey: Hotkey) throws
    func unregister(_ hotkey: Hotkey)
}

public final class HotkeyManager: @unchecked Sendable {
    private let registry: any HotkeyRegistry

    public private(set) var savedHotkey: Hotkey?

    public init(registry: any HotkeyRegistry, savedHotkey: Hotkey? = nil) {
        self.registry = registry
        self.savedHotkey = savedHotkey
    }

    public func saveAndRegister(_ hotkey: Hotkey) throws {
        if registry.contains(hotkey), savedHotkey != hotkey {
            throw OpenRecError.hotkeyConflict
        }

        try registry.register(hotkey)
        savedHotkey = hotkey
    }

    public func clearSavedHotkey() {
        if let savedHotkey {
            registry.unregister(savedHotkey)
        }
        savedHotkey = nil
    }
}

public final class InMemoryHotkeyRegistry: HotkeyRegistry, @unchecked Sendable {
    private var registeredHotkeys: [Hotkey]
    private let registrationFailure: HotkeyRegistrationError?

    public init(
        registeredHotkeys: [Hotkey] = [],
        registrationFailure: HotkeyRegistrationError? = nil
    ) {
        self.registeredHotkeys = registeredHotkeys
        self.registrationFailure = registrationFailure
    }

    public func contains(_ hotkey: Hotkey) -> Bool {
        registeredHotkeys.contains(hotkey)
    }

    public func register(_ hotkey: Hotkey) throws {
        if let registrationFailure {
            throw registrationFailure
        }

        if !contains(hotkey) {
            registeredHotkeys.append(hotkey)
        }
    }

    public func unregister(_ hotkey: Hotkey) {
        registeredHotkeys.removeAll { $0 == hotkey }
    }
}

#if os(macOS)
public final class SystemHotkeyRegistry: HotkeyRegistry, @unchecked Sendable {
    public static let unimplementedRegistrationMessage = "System hotkey registration is not implemented yet"

    public init() {}

    public func contains(_ hotkey: Hotkey) -> Bool {
        false
    }

    public func register(_ hotkey: Hotkey) throws {
        throw HotkeyRegistrationError.registrationFailed(Self.unimplementedRegistrationMessage)
    }

    public func unregister(_ hotkey: Hotkey) {}
}
#endif
