import Testing
@testable import OpenRecCore

@Test func audioDeviceProviderReturnsSelectedMicrophoneWhenAvailable() throws {
    let selected = MicrophoneDevice(id: "external", name: "External Mic", isDefault: false)
    let provider = InMemoryAudioDeviceProvider(
        devices: [
            MicrophoneDevice(id: "built-in", name: "MacBook Microphone", isDefault: true),
            selected
        ]
    )

    let resolved = try provider.resolveMicrophoneDevice(selectedDeviceID: "external")

    #expect(resolved == selected)
}

@Test func audioDeviceProviderFallsBackToDefaultWhenSelectedMicrophoneIsMissing() throws {
    let defaultDevice = MicrophoneDevice(id: "built-in", name: "MacBook Microphone", isDefault: true)
    let provider = InMemoryAudioDeviceProvider(devices: [defaultDevice])

    let resolved = try provider.resolveMicrophoneDevice(selectedDeviceID: "missing")

    #expect(resolved == defaultDevice)
}

@Test func audioDeviceProviderThrowsWhenNoMicrophoneIsAvailable() {
    let provider = InMemoryAudioDeviceProvider(devices: [])

    #expect(throws: OpenRecError.microphoneUnavailable("missing")) {
        try provider.resolveMicrophoneDevice(selectedDeviceID: "missing")
    }
}

@Test func avFoundationAudioDeviceProviderMapsCaptureDevices() {
    let provider = AVFoundationAudioDeviceProvider(
        captureDevices: {
            [
                AVFoundationAudioDeviceProvider.CaptureDeviceDescriptor(
                    uniqueID: "built-in",
                    localizedName: "MacBook Microphone"
                ),
                AVFoundationAudioDeviceProvider.CaptureDeviceDescriptor(
                    uniqueID: "external",
                    localizedName: "External Mic"
                )
            ]
        },
        defaultDeviceID: { "external" }
    )

    let devices = provider.microphoneDevices()

    #expect(devices == [
        MicrophoneDevice(id: "built-in", name: "MacBook Microphone", isDefault: false),
        MicrophoneDevice(id: "external", name: "External Mic", isDefault: true)
    ])
}

@Test func avFoundationAudioDeviceProviderFallsBackToFirstDeviceWhenDefaultIsUnavailable() {
    let provider = AVFoundationAudioDeviceProvider(
        captureDevices: {
            [
                AVFoundationAudioDeviceProvider.CaptureDeviceDescriptor(
                    uniqueID: "built-in",
                    localizedName: "MacBook Microphone"
                ),
                AVFoundationAudioDeviceProvider.CaptureDeviceDescriptor(
                    uniqueID: "external",
                    localizedName: "External Mic"
                )
            ]
        },
        defaultDeviceID: { nil }
    )

    #expect(provider.defaultMicrophoneDevice() == MicrophoneDevice(
        id: "built-in",
        name: "MacBook Microphone",
        isDefault: true
    ))
}

@Test func avFoundationAudioDeviceProviderFallsBackWhenSystemDefaultIDIsNotEnumerated() {
    let provider = AVFoundationAudioDeviceProvider(
        captureDevices: {
            [
                AVFoundationAudioDeviceProvider.CaptureDeviceDescriptor(
                    uniqueID: "built-in",
                    localizedName: "MacBook Microphone"
                )
            ]
        },
        defaultDeviceID: { "missing" }
    )

    #expect(provider.microphoneDevices() == [
        MicrophoneDevice(id: "built-in", name: "MacBook Microphone", isDefault: true)
    ])
}
