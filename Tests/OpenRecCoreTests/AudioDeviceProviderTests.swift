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
