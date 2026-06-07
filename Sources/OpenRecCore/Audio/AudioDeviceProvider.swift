#if os(macOS)
import AVFoundation
#endif

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

#if os(macOS)
public struct AVFoundationAudioDeviceProvider: AudioDeviceProvider {
    public struct CaptureDeviceDescriptor: Equatable, Sendable {
        public var uniqueID: String
        public var localizedName: String

        public init(uniqueID: String, localizedName: String) {
            self.uniqueID = uniqueID
            self.localizedName = localizedName
        }
    }

    private let captureDevices: @Sendable () -> [CaptureDeviceDescriptor]
    private let defaultDeviceID: @Sendable () -> String?

    public init(
        captureDevices: @escaping @Sendable () -> [CaptureDeviceDescriptor] = {
            AVCaptureDevice.DiscoverySession(
                deviceTypes: [.microphone, .external],
                mediaType: .audio,
                position: .unspecified
            )
            .devices
            .map {
                CaptureDeviceDescriptor(
                    uniqueID: $0.uniqueID,
                    localizedName: $0.localizedName
                )
            }
        },
        defaultDeviceID: @escaping @Sendable () -> String? = {
            AVCaptureDevice.default(for: .audio)?.uniqueID
        }
    ) {
        self.captureDevices = captureDevices
        self.defaultDeviceID = defaultDeviceID
    }

    public func microphoneDevices() -> [MicrophoneDevice] {
        let descriptors = captureDevices()
        let defaultID = defaultDeviceID()
        let fallbackDefaultID = descriptors.contains { $0.uniqueID == defaultID }
            ? defaultID
            : descriptors.first?.uniqueID

        return descriptors.map {
            MicrophoneDevice(
                id: $0.uniqueID,
                name: $0.localizedName,
                isDefault: $0.uniqueID == fallbackDefaultID
            )
        }
    }

    public func defaultMicrophoneDevice() -> MicrophoneDevice? {
        microphoneDevices().first(where: \.isDefault) ?? microphoneDevices().first
    }
}
#endif
