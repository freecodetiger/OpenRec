public struct MicrophoneDevice: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var isDefault: Bool

    public init(id: String, name: String, isDefault: Bool) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
    }
}

public protocol AudioDeviceProvider: Sendable {
    func microphoneDevices() -> [MicrophoneDevice]
    func defaultMicrophoneDevice() -> MicrophoneDevice?
}

public extension AudioDeviceProvider {
    func resolveMicrophoneDevice(selectedDeviceID: String?) throws -> MicrophoneDevice {
        let devices = microphoneDevices()

        if let selectedDeviceID, let selectedDevice = devices.first(where: { $0.id == selectedDeviceID }) {
            return selectedDevice
        }

        if let defaultDevice = defaultMicrophoneDevice() {
            return defaultDevice
        }

        throw OpenRecError.microphoneUnavailable(selectedDeviceID)
    }
}

public struct InMemoryAudioDeviceProvider: AudioDeviceProvider {
    private let devices: [MicrophoneDevice]

    public init(devices: [MicrophoneDevice]) {
        self.devices = devices
    }

    public func microphoneDevices() -> [MicrophoneDevice] {
        devices
    }

    public func defaultMicrophoneDevice() -> MicrophoneDevice? {
        devices.first(where: \.isDefault) ?? devices.first
    }
}
