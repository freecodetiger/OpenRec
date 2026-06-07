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

@Test func avAssetRecordingOutputWriterStartsSessionAtFirstVideoSampleTime() async throws {
    let directory = try temporaryDirectory()
    let outputURL = directory.appending(path: "first-sample-time.mov")
    let settings = try RecordingOutputWriterSettings(
        configuration: ResolvedRecordingConfiguration(
            source: .display(DisplayID(rawValue: 1)),
            pixelSize: CGSize(width: 64, height: 64),
            outputFormat: .mov,
            videoCodec: .h264,
            bitrate: 500_000,
            frameRate: 30,
            includeCursor: true,
            microphoneDeviceID: nil
        )
    )
    let writer = try AVAssetRecordingOutputWriter(settings: settings, outputURL: outputURL)
    let firstPTS = CMTime(seconds: 10, preferredTimescale: 600)

    try writer.start()
    try writer.appendVideoSampleBuffer(
        try videoSampleBuffer(size: CGSize(width: 64, height: 64), presentationTime: firstPTS)
    )
    try writer.appendVideoSampleBuffer(
        try videoSampleBuffer(
            size: CGSize(width: 64, height: 64),
            presentationTime: firstPTS + CMTime(value: 1, timescale: 30)
        )
    )
    let finalizedURL = try writer.finish()

    let asset = AVURLAsset(url: finalizedURL)
    let duration = try await asset.load(.duration)
    #expect(duration < CMTime(seconds: 1, preferredTimescale: 600))
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

@Test func screenCaptureRecordingEngineStartsAndStopsCaptureSessionWhenFactoriesSucceed() throws {
    let captureSession = StubRecordingCaptureSession()
    let captureSessionFactory = SuccessfulRecordingCaptureSessionFactory(captureSession: captureSession)
    let engine = ScreenCaptureRecordingEngine(
        writerFactory: SuccessfulRecordingOutputWriterFactory(),
        captureSessionFactory: captureSessionFactory,
        idProvider: { UUID(uuidString: "00000000-0000-0000-0000-000000000123")! }
    )
    let configuration = resolvedConfiguration(outputFormat: .mp4, videoCodec: .h264)

    let session = try engine.start(configuration: configuration)
    let finalizedURL = try engine.stop(session: session)

    #expect(session.source == configuration.source)
    #expect(finalizedURL == session.temporaryFileURL)
    #expect(captureSessionFactory.startedConfigurations == [configuration])
    #expect(captureSessionFactory.writers.count == 1)
    #expect(captureSession.didStop)
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

private func videoSampleBuffer(size: CGSize, presentationTime: CMTime) throws -> CMSampleBuffer {
    var pixelBuffer: CVPixelBuffer?
    let createStatus = CVPixelBufferCreate(
        kCFAllocatorDefault,
        Int(size.width),
        Int(size.height),
        kCVPixelFormatType_32BGRA,
        nil,
        &pixelBuffer
    )
    guard createStatus == kCVReturnSuccess, let pixelBuffer else {
        throw OpenRecError.writerFailed("Could not create test pixel buffer.")
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
        memset(baseAddress, 0, CVPixelBufferGetDataSize(pixelBuffer))
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

    var formatDescription: CMVideoFormatDescription?
    let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: pixelBuffer,
        formatDescriptionOut: &formatDescription
    )
    guard formatStatus == noErr, let formatDescription else {
        throw OpenRecError.writerFailed("Could not create test format description.")
    }

    var timing = CMSampleTimingInfo(
        duration: CMTime(value: 1, timescale: 30),
        presentationTimeStamp: presentationTime,
        decodeTimeStamp: .invalid
    )
    var sampleBuffer: CMSampleBuffer?
    let sampleStatus = CMSampleBufferCreateForImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: pixelBuffer,
        dataReady: true,
        makeDataReadyCallback: nil,
        refcon: nil,
        formatDescription: formatDescription,
        sampleTiming: &timing,
        sampleBufferOut: &sampleBuffer
    )
    guard sampleStatus == noErr, let sampleBuffer else {
        throw OpenRecError.writerFailed("Could not create test video sample buffer.")
    }

    return sampleBuffer
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

private final class StubRecordingCaptureSession: RecordingCaptureSession, @unchecked Sendable {
    private(set) var didStop = false

    func stop() throws {
        didStop = true
    }
}

private final class SuccessfulRecordingCaptureSessionFactory: RecordingCaptureSessionFactory, @unchecked Sendable {
    private let captureSession: StubRecordingCaptureSession
    private(set) var startedConfigurations: [ResolvedRecordingConfiguration] = []
    private(set) var writers: [any RecordingOutputWriter] = []

    init(captureSession: StubRecordingCaptureSession) {
        self.captureSession = captureSession
    }

    func startCapture(
        configuration: ResolvedRecordingConfiguration,
        writer: any RecordingOutputWriter
    ) throws -> any RecordingCaptureSession {
        startedConfigurations.append(configuration)
        writers.append(writer)
        return captureSession
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
