#if os(macOS)
import Carbon
#endif

public enum HotkeyRegistrationError: Error, Equatable, Sendable {
    case registrationFailed(String)
}

public protocol HotkeyRegistry: AnyObject, Sendable {
    var eventHandler: (@Sendable (Hotkey) -> Void)? { get set }

    func contains(_ hotkey: Hotkey) -> Bool
    func register(_ hotkey: Hotkey) throws
    func unregister(_ hotkey: Hotkey)
}

public final class HotkeyManager: @unchecked Sendable {
    private let registry: any HotkeyRegistry

    public private(set) var savedHotkey: Hotkey?
    public var onHotkeyTriggered: (@Sendable (Hotkey) -> Void)?

    public init(registry: any HotkeyRegistry, savedHotkey: Hotkey? = nil) {
        self.registry = registry
        self.savedHotkey = savedHotkey
        self.registry.eventHandler = { [weak self] hotkey in
            self?.handleTriggeredHotkey(hotkey)
        }
    }

    public func saveAndRegister(_ hotkey: Hotkey) throws {
        if registry.contains(hotkey), savedHotkey != hotkey {
            throw OpenRecError.hotkeyConflict
        }

        try registry.register(hotkey)
        savedHotkey = hotkey
    }

    public func registerSavedHotkey() throws {
        guard let savedHotkey else { return }
        try registry.register(savedHotkey)
    }

    public func clearSavedHotkey() {
        if let savedHotkey {
            registry.unregister(savedHotkey)
        }
        savedHotkey = nil
    }

    private func handleTriggeredHotkey(_ hotkey: Hotkey) {
        guard hotkey == savedHotkey, registry.contains(hotkey) else {
            return
        }

        onHotkeyTriggered?(hotkey)
    }
}

public final class InMemoryHotkeyRegistry: HotkeyRegistry, @unchecked Sendable {
    public var eventHandler: (@Sendable (Hotkey) -> Void)?

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

    public func trigger(_ hotkey: Hotkey) {
        eventHandler?(hotkey)
    }
}

#if os(macOS)
struct CarbonHotkey: Equatable, Sendable {
    var keyCode: UInt32
    var modifiers: UInt32
}

struct CarbonHotkeyToken: Equatable, Sendable {
    var rawValue: UInt
}

protocol CarbonHotkeyRegistering: AnyObject, Sendable {
    var eventHandler: (@Sendable (CarbonHotkey) -> Void)? { get set }

    func register(_ hotkey: CarbonHotkey) throws -> CarbonHotkeyToken
    func unregister(_ token: CarbonHotkeyToken)
}

final class CarbonHotkeyAdapter: CarbonHotkeyRegistering, @unchecked Sendable {
    private let signature: OSType = 0x4F526563
    private let hotkeyEventClass = UInt32(kEventClassKeyboard)
    private let hotkeyEventKind = UInt32(kEventHotKeyPressed)
    private var eventHandlerReference: EventHandlerRef?

    var eventHandler: (@Sendable (CarbonHotkey) -> Void)?

    init() {
        installEventHandler()
    }

    deinit {
        if let eventHandlerReference {
            RemoveEventHandler(eventHandlerReference)
        }
    }

    func register(_ hotkey: CarbonHotkey) throws -> CarbonHotkeyToken {
        var hotkeyReference: EventHotKeyRef?
        let hotkeyID = EventHotKeyID(signature: signature, id: hotkey.keyCode)
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyReference
        )

        guard status == noErr, let hotkeyReference else {
            throw HotkeyRegistrationError.registrationFailed("RegisterEventHotKey failed with status \(status)")
        }

        return CarbonHotkeyToken(rawValue: UInt(bitPattern: hotkeyReference))
    }

    func unregister(_ token: CarbonHotkeyToken) {
        guard let hotkeyReference = EventHotKeyRef(bitPattern: token.rawValue) else {
            return
        }

        _ = UnregisterEventHotKey(hotkeyReference)
    }

    private func installEventHandler() {
        var eventSpec = EventTypeSpec(
            eventClass: hotkeyEventClass,
            eventKind: hotkeyEventKind
        )
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else {
                    return noErr
                }

                let adapter = Unmanaged<CarbonHotkeyAdapter>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                return adapter.handle(event: event)
            },
            1,
            &eventSpec,
            userData,
            &eventHandlerReference
        )
    }

    private func handle(event: EventRef) -> OSStatus {
        var hotkeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotkeyID
        )
        guard status == noErr, hotkeyID.signature == signature else {
            return noErr
        }

        eventHandler?(CarbonHotkey(keyCode: hotkeyID.id, modifiers: 0))
        return noErr
    }
}

public final class SystemHotkeyRegistry: HotkeyRegistry, @unchecked Sendable {
    private let adapter: any CarbonHotkeyRegistering
    private var registeredTokens: [(hotkey: Hotkey, token: CarbonHotkeyToken)] = []
    public var eventHandler: (@Sendable (Hotkey) -> Void)?

    public init() {
        self.adapter = CarbonHotkeyAdapter()
        installAdapterEventHandler()
    }

    init(adapter: any CarbonHotkeyRegistering) {
        self.adapter = adapter
        installAdapterEventHandler()
    }

    public func contains(_ hotkey: Hotkey) -> Bool {
        registeredTokens.contains { $0.hotkey == hotkey }
    }

    public func register(_ hotkey: Hotkey) throws {
        let carbonHotkey = CarbonHotkey(
            keyCode: UInt32(hotkey.keyCode),
            modifiers: carbonModifiers(for: hotkey.modifiers)
        )
        unregisterAllRegisteredHotkeys()
        let token = try adapter.register(carbonHotkey)
        registeredTokens = [(hotkey: hotkey, token: token)]
    }

    public func unregister(_ hotkey: Hotkey) {
        guard let index = registeredTokens.firstIndex(where: { $0.hotkey == hotkey }) else {
            return
        }

        let token = registeredTokens.remove(at: index).token
        adapter.unregister(token)
    }

    private func unregisterAllRegisteredHotkeys() {
        let tokens = registeredTokens.map(\.token)
        registeredTokens.removeAll()
        for token in tokens {
            adapter.unregister(token)
        }
    }

    private func carbonModifiers(for modifiers: HotkeyModifiers) -> UInt32 {
        var carbonModifiers: UInt32 = 0
        if modifiers.contains(.command) {
            carbonModifiers |= UInt32(cmdKey)
        }
        if modifiers.contains(.option) {
            carbonModifiers |= UInt32(optionKey)
        }
        if modifiers.contains(.control) {
            carbonModifiers |= UInt32(controlKey)
        }
        if modifiers.contains(.shift) {
            carbonModifiers |= UInt32(shiftKey)
        }
        return carbonModifiers
    }

    private func installAdapterEventHandler() {
        adapter.eventHandler = { [weak self] carbonHotkey in
            guard let self,
                  let hotkey = self.hotkey(for: carbonHotkey) else {
                return
            }

            self.eventHandler?(hotkey)
        }
    }

    private func hotkey(for carbonHotkey: CarbonHotkey) -> Hotkey? {
        registeredTokens.first {
            UInt32($0.hotkey.keyCode) == carbonHotkey.keyCode
        }?.hotkey
    }
}
#endif
