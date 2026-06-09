import Foundation
import Testing
@testable import OpenRecCore

@Test func resolverUsesSourceOriginalPixelSizeWithoutScaling() throws {
    let source = CaptureSource.display(DisplayID(rawValue: 1))
    let metadata = CaptureSourceMetadata(
        source: source,
        pixelSize: CGSize(width: 3024, height: 1964),
        isAvailable: true
    )
    let settings = RecordingSettings.defaults

    let config = try ConfigurationResolver.resolve(
        source: source,
        metadata: metadata,
        settings: settings
    )

    #expect(config.source == source)
    #expect(config.pixelSize.width == 3024)
    #expect(config.pixelSize.height == 1964)
    #expect(config.outputFormat == .mp4)
    #expect(config.videoCodec == .h264)
    #expect(config.frameRate == 30)
    #expect(config.includeCursor)
    #expect(config.microphoneDeviceID == nil)
}

@Test func resolverMapsEveryFrameRatePresetToRawFrameRate() throws {
    let source = CaptureSource.window(WindowID(rawValue: 7))
    let metadata = CaptureSourceMetadata(
        source: source,
        pixelSize: CGSize(width: 1920, height: 1080),
        isAvailable: true
    )

    for preset in FrameRatePreset.allCases {
        var settings = RecordingSettings.defaults
        settings.frameRate = preset

        let config = try ConfigurationResolver.resolve(
            source: source,
            metadata: metadata,
            settings: settings
        )

        #expect(config.frameRate == preset.rawValue)
    }
}

@Test func resolverCarriesEveryRecordingSettingIntoResolvedConfiguration() throws {
    let source = CaptureSource.display(DisplayID(rawValue: 9))
    let metadata = CaptureSourceMetadata(
        source: source,
        pixelSize: CGSize(width: 2560, height: 1440),
        isAvailable: true
    )
    let settings = RecordingSettings(
        defaultMode: .display,
        outputFormat: .mov,
        videoCodec: .hevc,
        qualityPreset: .high,
        frameRate: .fps60,
        includeCursor: false,
        microphoneDeviceID: "StudioMic",
        audioPreset: .high,
        globalHotkey: Hotkey(keyCode: 15, modifiers: [.command, .shift])
    )

    let config = try ConfigurationResolver.resolve(
        source: source,
        metadata: metadata,
        settings: settings
    )

    #expect(config.source == source)
    #expect(config.pixelSize == metadata.pixelSize)
    #expect(config.outputFormat == .mov)
    #expect(config.videoCodec == .hevc)
    #expect(config.frameRate == 60)
    #expect(config.audioPreset == .high)
    #expect(config.includeCursor == false)
    #expect(config.microphoneDeviceID == "StudioMic")
    #expect(config.bitrate == ConfigurationResolver.videoBitrate(
        pixelSize: metadata.pixelSize,
        frameRate: .fps60,
        qualityPreset: .high,
        codec: .hevc
    ))
}

@Test func resolverDerivesBitrateFromSizeFrameRateQualityAndCodec() throws {
    let source = CaptureSource.display(DisplayID(rawValue: 8))
    let metadata = CaptureSourceMetadata(
        source: source,
        pixelSize: CGSize(width: 1920, height: 1080),
        isAvailable: true
    )

    var compactH264 = RecordingSettings.defaults
    compactH264.qualityPreset = .compact
    compactH264.videoCodec = .h264

    var standardH264 = compactH264
    standardH264.qualityPreset = .standard

    var highH264 = compactH264
    highH264.qualityPreset = .high

    var highH264Fps60 = highH264
    highH264Fps60.frameRate = .fps60

    var highHEVC = highH264
    highHEVC.videoCodec = .hevc

    let compact = try ConfigurationResolver.resolve(
        source: source,
        metadata: metadata,
        settings: compactH264
    )
    let standard = try ConfigurationResolver.resolve(
        source: source,
        metadata: metadata,
        settings: standardH264
    )
    let high = try ConfigurationResolver.resolve(
        source: source,
        metadata: metadata,
        settings: highH264
    )
    let highFps60 = try ConfigurationResolver.resolve(
        source: source,
        metadata: metadata,
        settings: highH264Fps60
    )
    let hevc = try ConfigurationResolver.resolve(
        source: source,
        metadata: metadata,
        settings: highHEVC
    )

    #expect(compact.bitrate < standard.bitrate)
    #expect(standard.bitrate < high.bitrate)
    #expect(high.bitrate < highFps60.bitrate)
    #expect(hevc.bitrate < high.bitrate)
}

@Test func resolverFailsBeforeStartWhenSourceMetadataIsUnavailable() {
    let source = CaptureSource.window(WindowID(rawValue: 99))
    let metadata = CaptureSourceMetadata(
        source: source,
        pixelSize: CGSize(width: 1280, height: 720),
        isAvailable: false
    )

    #expect(throws: OpenRecError.captureSourceUnavailable(source)) {
        try ConfigurationResolver.resolve(
            source: source,
            metadata: metadata,
            settings: .defaults
        )
    }
}

@Test func resolverFailsBeforeStartWhenSourceMetadataIsInvalid() {
    let source = CaptureSource.display(DisplayID(rawValue: 77))
    let metadata = CaptureSourceMetadata(
        source: source,
        pixelSize: CGSize(width: 0, height: 1080),
        isAvailable: true
    )

    #expect(throws: OpenRecError.captureConfigurationInvalid("Capture source metadata has invalid pixel size.")) {
        try ConfigurationResolver.resolve(
            source: source,
            metadata: metadata,
            settings: .defaults
        )
    }
}

@Test func resolverFailsBeforeStartWhenMetadataDoesNotMatchSource() {
    let source = CaptureSource.display(DisplayID(rawValue: 3))
    let metadata = CaptureSourceMetadata(
        source: .display(DisplayID(rawValue: 4)),
        pixelSize: CGSize(width: 1920, height: 1080),
        isAvailable: true
    )

    #expect(throws: OpenRecError.captureConfigurationInvalid("Capture source metadata does not match the selected source.")) {
        try ConfigurationResolver.resolve(
            source: source,
            metadata: metadata,
            settings: .defaults
        )
    }
}
