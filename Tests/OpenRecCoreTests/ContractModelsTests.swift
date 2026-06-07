import Testing
import Foundation
@testable import OpenRecCore

@Test func defaultSettingsUseMvpPresets() {
    let settings = AppSettings.defaults

    #expect(settings.schemaVersion == 1)
    #expect(settings.recording.defaultMode == .display)
    #expect(settings.recording.outputFormat == .mp4)
    #expect(settings.recording.videoCodec == .h264)
    #expect(settings.recording.qualityPreset == .standard)
    #expect(settings.recording.frameRate == .fps30)
    #expect(settings.recording.includeCursor)
    #expect(settings.recording.microphoneDeviceID == nil)
    #expect(settings.recording.audioPreset == .standard)
    #expect(settings.recording.globalHotkey == nil)
}

@Test func captureSourceCanRepresentDisplayAndWindow() {
    #expect(CaptureSource.display(DisplayID(rawValue: 42)).displayID == DisplayID(rawValue: 42))
    #expect(CaptureSource.window(WindowID(rawValue: 7)).windowID == WindowID(rawValue: 7))
}

@Test func resolvedConfigurationAlwaysCarriesSourcePixelSize() {
    let config = ResolvedRecordingConfiguration(
        source: .display(DisplayID(rawValue: 1)),
        pixelSize: CGSize(width: 3024, height: 1964),
        outputFormat: .mp4,
        videoCodec: .h264,
        bitrate: 16_000_000,
        frameRate: 30,
        includeCursor: true,
        microphoneDeviceID: nil
    )

    #expect(config.pixelSize.width == 3024)
    #expect(config.pixelSize.height == 1964)
    #expect(config.frameRate == 30)
}

@Test func openRecErrorExposesStructuredCases() {
    let error = OpenRecError.permissionDenied(.screenRecording)
    #expect(error == .permissionDenied(.screenRecording))
}
