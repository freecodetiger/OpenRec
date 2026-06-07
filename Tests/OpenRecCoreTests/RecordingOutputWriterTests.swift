import AVFoundation
import Foundation
import Testing
@testable import OpenRecCore

@Test func outputWriterSettingsMapMP4H264AAC() throws {
    let configuration = resolvedConfiguration(outputFormat: .mp4, videoCodec: .h264)

    let settings = try RecordingOutputWriterSettings(configuration: configuration)

    #expect(settings.fileType == .mp4)
    #expect(settings.fileExtension == "mp4")
    #expect(settings.videoCodec == .h264)
    #expect(settings.audioFormatID == kAudioFormatMPEG4AAC)
    #expect(settings.videoWidth == 1920)
    #expect(settings.videoHeight == 1080)
    #expect(settings.videoBitrate == 7_464_960)
    #expect(settings.frameRate == 30)
}

@Test func outputWriterSettingsMapMOVHEVCAAC() throws {
    let configuration = resolvedConfiguration(outputFormat: .mov, videoCodec: .hevc)

    let settings = try RecordingOutputWriterSettings(configuration: configuration)

    #expect(settings.fileType == .mov)
    #expect(settings.fileExtension == "mov")
    #expect(settings.videoCodec == .hevc)
    #expect(settings.audioFormatID == kAudioFormatMPEG4AAC)
}

@Test func outputWriterSettingsRejectInvalidPixelSize() {
    let configuration = ResolvedRecordingConfiguration(
        source: .display(DisplayID(rawValue: 1)),
        pixelSize: CGSize(width: 0, height: 1080),
        outputFormat: .mp4,
        videoCodec: .h264,
        bitrate: 7_464_960,
        frameRate: 30,
        includeCursor: true,
        microphoneDeviceID: nil
    )

    #expect(throws: OpenRecError.captureConfigurationInvalid("Recording output pixel size must be positive.")) {
        try RecordingOutputWriterSettings(configuration: configuration)
    }
}

@Test func temporaryRecordingURLUsesContainerExtensionAndOpenRecPrefix() throws {
    let directory = try temporaryDirectory()
    let engine = ScreenCaptureRecordingEngine(
        outputDirectory: directory,
        writerFactory: FailingRecordingOutputWriterFactory(error: .writerInitializationFailed("unsupported test path"))
    )

    let url = try engine.temporaryRecordingURL(for: resolvedConfiguration(outputFormat: .mov, videoCodec: .h264))

    #expect(
        url.deletingLastPathComponent().standardizedFileURL ==
            directory.standardizedFileURL
    )
    #expect(url.lastPathComponent.hasPrefix("openrec-"))
    #expect(url.pathExtension == "mov")
}

@Test func screenCaptureRecordingEngineDoesNotReturnFakeSessionWhenWriterCannotStart() {
    let engine = ScreenCaptureRecordingEngine(
        outputDirectory: FileManager.default.temporaryDirectory,
        writerFactory: FailingRecordingOutputWriterFactory(error: .writerInitializationFailed("writer unavailable"))
    )

    #expect(throws: RecordingEngineFailure(error: .writerInitializationFailed("writer unavailable"))) {
        _ = try engine.start(configuration: resolvedConfiguration(outputFormat: .mp4, videoCodec: .h264))
    }
}

@Test func screenCaptureRecordingEngineFailsExplicitlyWhenScreenCaptureKitCaptureIsNotImplemented() {
    let engine = ScreenCaptureRecordingEngine(
        writerFactory: SuccessfulRecordingOutputWriterFactory()
    )

    do {
        _ = try engine.start(configuration: resolvedConfiguration(outputFormat: .mp4, videoCodec: .h264))
        Issue.record("Expected ScreenCaptureRecordingEngine.start to fail.")
    } catch let failure as RecordingEngineFailure {
        #expect(failure.error == .captureConfigurationInvalid("ScreenCaptureKit recording capture is not implemented."))
        #expect(failure.temporaryFileURL?.pathExtension == "mp4")
    } catch {
        Issue.record("Expected RecordingEngineFailure, got \(error).")
    }
}

@Test func screenCaptureRecordingEngineRejectsStopForUnknownSession() {
    let engine = ScreenCaptureRecordingEngine(
        writerFactory: FailingRecordingOutputWriterFactory(error: .writerInitializationFailed("unused"))
    )
    let session = RecordingSession(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000042")!,
        source: .display(DisplayID(rawValue: 1)),
        temporaryFileURL: URL(filePath: "/tmp/openrec-unknown.mp4")
    )

    #expect(throws: OpenRecError.captureConfigurationInvalid("Recording session is not active.")) {
        _ = try engine.stop(session: session)
    }
}

private func resolvedConfiguration(
    outputFormat: OutputFormat,
    videoCodec: VideoCodec
) -> ResolvedRecordingConfiguration {
    ResolvedRecordingConfiguration(
        source: .display(DisplayID(rawValue: 1)),
        pixelSize: CGSize(width: 1920, height: 1080),
        outputFormat: outputFormat,
        videoCodec: videoCodec,
        bitrate: 7_464_960,
        frameRate: 30,
        includeCursor: true,
        microphoneDeviceID: nil
    )
}

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "OpenRecRecordingOutputWriterTests")
        .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private struct FailingRecordingOutputWriterFactory: RecordingOutputWriterFactory {
    var error: OpenRecError

    func makeWriter(
        settings: RecordingOutputWriterSettings,
        outputURL: URL
    ) throws -> any RecordingOutputWriter {
        throw error
    }
}

private struct SuccessfulRecordingOutputWriterFactory: RecordingOutputWriterFactory {
    func makeWriter(
        settings: RecordingOutputWriterSettings,
        outputURL: URL
    ) throws -> any RecordingOutputWriter {
        StubRecordingOutputWriter(outputURL: outputURL)
    }
}

private final class StubRecordingOutputWriter: RecordingOutputWriter, @unchecked Sendable {
    let outputURL: URL
    private(set) var isStarted = false

    init(outputURL: URL) {
        self.outputURL = outputURL
    }

    func start() throws {
        isStarted = true
    }

    func appendVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) throws {}

    func appendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) throws {}

    func finish() throws -> URL {
        outputURL
    }
}
