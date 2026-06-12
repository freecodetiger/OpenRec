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

@Test func outputWriterSettingsMapAudioPresetToAACBitrate() throws {
    let standard = try RecordingOutputWriterSettings(
        configuration: resolvedConfiguration(outputFormat: .mp4, videoCodec: .h264, audioPreset: .standard)
    )
    let high = try RecordingOutputWriterSettings(
        configuration: resolvedConfiguration(outputFormat: .mp4, videoCodec: .h264, audioPreset: .high)
    )

    #expect(standard.audioSampleRate == 48_000)
    #expect(standard.audioChannelCount == 2)
    #expect(standard.audioBitrate == 128_000)
    #expect(high.audioSampleRate == 48_000)
    #expect(high.audioChannelCount == 2)
    #expect(high.audioBitrate == 256_000)
}

@Test func outputWriterSettingsExposeAVFoundationEncoderParameters() throws {
    let configuration = ResolvedRecordingConfiguration(
        source: .display(DisplayID(rawValue: 1)),
        pixelSize: CGSize(width: 2560, height: 1440),
        outputFormat: .mov,
        videoCodec: .hevc,
        bitrate: 25_000_000,
        frameRate: 60,
        audioPreset: .high,
        includeCursor: false,
        microphoneDeviceID: "StudioMic"
    )

    let settings = try RecordingOutputWriterSettings(configuration: configuration)
    let compression = try #require(
        settings.videoOutputSettings[AVVideoCompressionPropertiesKey] as? [String: Any]
    )

    #expect(settings.fileType == .mov)
    #expect(settings.fileExtension == "mov")
    #expect(settings.videoCodec == .hevc)
    #expect(settings.videoWidth == 2560)
    #expect(settings.videoHeight == 1440)
    #expect(compression[AVVideoAverageBitRateKey] as? Int == 25_000_000)
    #expect(compression[AVVideoExpectedSourceFrameRateKey] as? Int == 60)
    #expect(compression[AVVideoAllowFrameReorderingKey] as? Bool == false)
    #expect(settings.audioOutputSettings[AVFormatIDKey] as? AudioFormatID == kAudioFormatMPEG4AAC)
    #expect(settings.audioOutputSettings[AVSampleRateKey] as? Int == 48_000)
    #expect(settings.audioOutputSettings[AVNumberOfChannelsKey] as? Int == 2)
    #expect(settings.audioOutputSettings[AVEncoderBitRateKey] as? Int == 256_000)
}

@Test func outputWriterSettingsExposeStableSDRColorMetadata() throws {
    let settings = try RecordingOutputWriterSettings(
        configuration: resolvedConfiguration(outputFormat: .mp4, videoCodec: .h264)
    )
    let colorProperties = try #require(
        settings.videoOutputSettings[AVVideoColorPropertiesKey] as? [String: String]
    )

    #expect(colorProperties[AVVideoColorPrimariesKey] == AVVideoColorPrimaries_ITU_R_709_2)
    #expect(colorProperties[AVVideoTransferFunctionKey] == AVVideoTransferFunction_ITU_R_709_2)
    #expect(colorProperties[AVVideoYCbCrMatrixKey] == AVVideoYCbCrMatrix_ITU_R_709_2)
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

@Test func avAssetRecordingOutputWriterIgnoresAudioBeforeFirstVideoFrameForSessionStart() async throws {
    let directory = try temporaryDirectory()
    let outputURL = directory.appending(path: "audio-before-video.mov")
    let settings = try smallWriterSettings()
    let writer = try AVAssetRecordingOutputWriter(settings: settings, outputURL: outputURL)
    let firstVideoPTS = CMTime(seconds: 10, preferredTimescale: 600)

    try writer.start()
    try writer.appendAudioSampleBuffer(try audioSampleBuffer(presentationTime: .zero))
    try writer.appendVideoSampleBuffer(
        try videoSampleBuffer(size: CGSize(width: 64, height: 64), presentationTime: firstVideoPTS)
    )
    try writer.appendVideoSampleBuffer(
        try videoSampleBuffer(
            size: CGSize(width: 64, height: 64),
            presentationTime: firstVideoPTS + CMTime(value: 1, timescale: 30)
        )
    )
    let finalizedURL = try writer.finish()

    let asset = AVURLAsset(url: finalizedURL)
    let duration = try await asset.load(.duration)
    #expect(duration < CMTime(seconds: 1, preferredTimescale: 600))
}

@Test func avAssetRecordingOutputWriterRejectsFinishBeforeFirstVideoFrame() throws {
    let directory = try temporaryDirectory()
    let outputURL = directory.appending(path: "no-video-frame.mov")
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

    try writer.start()

    #expect(throws: OpenRecError.writerFailed("No video frames were captured.")) {
        _ = try writer.finish()
    }
}

@Test func avAssetRecordingOutputWriterRejectsFinishAfterOnlyAudioFrames() throws {
    let directory = try temporaryDirectory()
    let outputURL = directory.appending(path: "only-audio.mov")
    let settings = try smallWriterSettings()
    let writer = try AVAssetRecordingOutputWriter(settings: settings, outputURL: outputURL)

    try writer.start()
    try writer.appendAudioSampleBuffer(try audioSampleBuffer(presentationTime: .zero))

    #expect(throws: OpenRecError.writerFailed("No video frames were captured.")) {
        _ = try writer.finish()
    }
}

@Test func avAssetRecordingOutputWriterSerializesConcurrentVideoAndAudioAppends() throws {
    let directory = try temporaryDirectory()
    let outputURL = directory.appending(path: "concurrent-appends.mov")
    let settings = try smallWriterSettings()
    let writer = try AVAssetRecordingOutputWriter(settings: settings, outputURL: outputURL)
    let firstPTS = CMTime(seconds: 2, preferredTimescale: 600)
    let videoSamples = try (0..<3).map { frame in
        UncheckedSampleBuffer(
            try videoSampleBuffer(
                size: CGSize(width: 64, height: 64),
                presentationTime: firstPTS + CMTime(value: CMTimeValue(frame), timescale: 30)
            )
        )
    }
    let audioSamples = try (0..<3).map { packet in
        UncheckedSampleBuffer(
            try audioSampleBuffer(
                presentationTime: firstPTS + CMTime(value: CMTimeValue(packet * 480), timescale: 48_000)
            )
        )
    }
    let startGate = DispatchSemaphore(value: 0)
    let group = DispatchGroup()
    let errorRecorder = ErrorRecorder()

    try writer.start()

    group.enter()
    DispatchQueue(label: "openrec.writer-test.video").async {
        startGate.wait()
        for sample in videoSamples {
            do {
                try writer.appendVideoSampleBuffer(sample.value)
            } catch {
                errorRecorder.record(error)
            }
        }
        group.leave()
    }

    group.enter()
    DispatchQueue(label: "openrec.writer-test.audio").async {
        startGate.wait()
        for sample in audioSamples {
            do {
                try writer.appendAudioSampleBuffer(sample.value)
            } catch {
                errorRecorder.record(error)
            }
        }
        group.leave()
    }

    startGate.signal()
    startGate.signal()
    group.wait()

    #expect(errorRecorder.values.isEmpty)
    let finalizedURL = try writer.finish()
    #expect(FileManager.default.fileExists(atPath: finalizedURL.path(percentEncoded: false)))
}

@Test func avAssetRecordingOutputWriterWritesAudioAfterFirstVideoFrame() async throws {
    let directory = try temporaryDirectory()
    let outputURL = directory.appending(path: "video-then-audio.mov")
    let settings = try smallWriterSettings()
    let writer = try AVAssetRecordingOutputWriter(settings: settings, outputURL: outputURL)
    let firstPTS = CMTime(seconds: 4, preferredTimescale: 600)

    try writer.start()
    try writer.appendVideoSampleBuffer(
        try videoSampleBuffer(size: CGSize(width: 64, height: 64), presentationTime: firstPTS)
    )
    try writer.appendAudioSampleBuffer(try audioSampleBuffer(presentationTime: firstPTS))
    try writer.appendVideoSampleBuffer(
        try videoSampleBuffer(
            size: CGSize(width: 64, height: 64),
            presentationTime: firstPTS + CMTime(value: 1, timescale: 30)
        )
    )
    let finalizedURL = try writer.finish()

    let asset = AVURLAsset(url: finalizedURL)
    let audioTracks = try await asset.loadTracks(withMediaType: .audio)
    #expect(!audioTracks.isEmpty)
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
    let microphoneSession = StubMicrophoneCaptureSession()
    let microphoneSessionFactory = SuccessfulMicrophoneCaptureSessionFactory(microphoneSession: microphoneSession)
    let audioLevelMonitor = AudioLevelMonitor()
    let engine = ScreenCaptureRecordingEngine(
        writerFactory: SuccessfulRecordingOutputWriterFactory(),
        captureSessionFactory: captureSessionFactory,
        microphoneCaptureSessionFactory: microphoneSessionFactory,
        audioLevelMonitor: audioLevelMonitor,
        idProvider: { UUID(uuidString: "00000000-0000-0000-0000-000000000123")! }
    )
    let configuration = resolvedConfiguration(
        outputFormat: .mp4,
        videoCodec: .h264,
        microphoneDeviceID: "BuiltInMic"
    )

    let session = try engine.start(configuration: configuration)
    let finalizedURL = try engine.stop(session: session)

    #expect(session.source == configuration.source)
    #expect(finalizedURL == session.temporaryFileURL)
    #expect(captureSessionFactory.startedConfigurations == [configuration])
    #expect(captureSessionFactory.writers.count == 1)
    let injectedCaptureMonitor = try #require(captureSessionFactory.audioLevelMonitors.first ?? nil)
    #expect(injectedCaptureMonitor === audioLevelMonitor)
    #expect(microphoneSessionFactory.startedDeviceIDs == ["BuiltInMic"])
    #expect(microphoneSessionFactory.writers.count == 1)
    let injectedMicrophoneMonitor = try #require(microphoneSessionFactory.audioLevelMonitors.first ?? nil)
    #expect(injectedMicrophoneMonitor === audioLevelMonitor)
    #expect(captureSession.didStop)
    #expect(microphoneSession.didStop)
}

@Test func screenCaptureRecordingEngineDoesNotStartMicrophoneCaptureWithoutMicrophoneDevice() throws {
    let microphoneSessionFactory = SuccessfulMicrophoneCaptureSessionFactory(
        microphoneSession: StubMicrophoneCaptureSession()
    )
    let engine = ScreenCaptureRecordingEngine(
        writerFactory: SuccessfulRecordingOutputWriterFactory(),
        captureSessionFactory: SuccessfulRecordingCaptureSessionFactory(captureSession: StubRecordingCaptureSession()),
        microphoneCaptureSessionFactory: microphoneSessionFactory
    )

    _ = try engine.start(configuration: resolvedConfiguration(outputFormat: .mp4, videoCodec: .h264))

    #expect(microphoneSessionFactory.startedDeviceIDs.isEmpty)
}

@Test func screenCaptureRecordingEngineCleansTemporaryFileWhenMicrophoneCaptureFails() throws {
    let directory = try temporaryDirectory()
    let captureSession = StubRecordingCaptureSession()
    let engine = ScreenCaptureRecordingEngine(
        outputDirectory: directory,
        writerFactory: SuccessfulRecordingOutputWriterFactory(),
        captureSessionFactory: SuccessfulRecordingCaptureSessionFactory(captureSession: captureSession),
        microphoneCaptureSessionFactory: FailingMicrophoneCaptureSessionFactory(
            error: .microphoneUnavailable("missing-mic")
        ),
        idProvider: { UUID(uuidString: "00000000-0000-0000-0000-000000000124")! }
    )
    let configuration = resolvedConfiguration(
        outputFormat: .mp4,
        videoCodec: .h264,
        microphoneDeviceID: "missing-mic"
    )

    let expectedURL = directory.appending(
        path: "openrec-00000000-0000-0000-0000-000000000124.mp4"
    )

    #expect(throws: RecordingEngineFailure(
        error: .microphoneUnavailable("missing-mic"),
        temporaryFileURL: expectedURL
    )) {
        _ = try engine.start(configuration: configuration)
    }

    #expect(!FileManager.default.fileExists(atPath: expectedURL.path(percentEncoded: false)))
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
    videoCodec: VideoCodec,
    microphoneDeviceID: String? = nil,
    audioPreset: AudioPreset = .standard
) -> ResolvedRecordingConfiguration {
    ResolvedRecordingConfiguration(
        source: .display(DisplayID(rawValue: 1)),
        pixelSize: CGSize(width: 1920, height: 1080),
        outputFormat: outputFormat,
        videoCodec: videoCodec,
        bitrate: 7_464_960,
        frameRate: 30,
        audioPreset: audioPreset,
        includeCursor: true,
        microphoneDeviceID: microphoneDeviceID
    )
}

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "OpenRecRecordingOutputWriterTests")
        .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func smallWriterSettings() throws -> RecordingOutputWriterSettings {
    try RecordingOutputWriterSettings(
        configuration: ResolvedRecordingConfiguration(
            source: .display(DisplayID(rawValue: 1)),
            pixelSize: CGSize(width: 64, height: 64),
            outputFormat: .mov,
            videoCodec: .h264,
            bitrate: 500_000,
            frameRate: 30,
            includeCursor: true,
            microphoneDeviceID: "TestMic"
        )
    )
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

private func audioSampleBuffer(
    presentationTime: CMTime,
    sampleCount: CMItemCount = 480
) throws -> CMSampleBuffer {
    var streamDescription = AudioStreamBasicDescription(
        mSampleRate: 48_000,
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
        mBytesPerPacket: 4,
        mFramesPerPacket: 1,
        mBytesPerFrame: 4,
        mChannelsPerFrame: 2,
        mBitsPerChannel: 16,
        mReserved: 0
    )
    var formatDescription: CMAudioFormatDescription?
    let formatStatus = CMAudioFormatDescriptionCreate(
        allocator: kCFAllocatorDefault,
        asbd: &streamDescription,
        layoutSize: 0,
        layout: nil,
        magicCookieSize: 0,
        magicCookie: nil,
        extensions: nil,
        formatDescriptionOut: &formatDescription
    )
    guard formatStatus == noErr, let formatDescription else {
        throw OpenRecError.writerFailed("Could not create test audio format description.")
    }

    let byteCount = Int(sampleCount) * Int(streamDescription.mBytesPerFrame)
    var blockBuffer: CMBlockBuffer?
    let blockStatus = CMBlockBufferCreateWithMemoryBlock(
        allocator: kCFAllocatorDefault,
        memoryBlock: nil,
        blockLength: byteCount,
        blockAllocator: kCFAllocatorDefault,
        customBlockSource: nil,
        offsetToData: 0,
        dataLength: byteCount,
        flags: 0,
        blockBufferOut: &blockBuffer
    )
    guard blockStatus == noErr, let blockBuffer else {
        throw OpenRecError.writerFailed("Could not create test audio block buffer.")
    }

    let fillStatus = CMBlockBufferFillDataBytes(
        with: 0,
        blockBuffer: blockBuffer,
        offsetIntoDestination: 0,
        dataLength: byteCount
    )
    guard fillStatus == noErr else {
        throw OpenRecError.writerFailed("Could not fill test audio block buffer.")
    }

    var timing = CMSampleTimingInfo(
        duration: CMTime(value: 1, timescale: 48_000),
        presentationTimeStamp: presentationTime,
        decodeTimeStamp: .invalid
    )
    var sampleBuffer: CMSampleBuffer?
    let sampleStatus = CMSampleBufferCreate(
        allocator: kCFAllocatorDefault,
        dataBuffer: blockBuffer,
        dataReady: true,
        makeDataReadyCallback: nil,
        refcon: nil,
        formatDescription: formatDescription,
        sampleCount: sampleCount,
        sampleTimingEntryCount: 1,
        sampleTimingArray: &timing,
        sampleSizeEntryCount: 0,
        sampleSizeArray: nil,
        sampleBufferOut: &sampleBuffer
    )
    guard sampleStatus == noErr, let sampleBuffer else {
        throw OpenRecError.writerFailed("Could not create test audio sample buffer.")
    }

    return sampleBuffer
}

private struct UncheckedSampleBuffer: @unchecked Sendable {
    var value: CMSampleBuffer

    init(_ value: CMSampleBuffer) {
        self.value = value
    }
}

private final class ErrorRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var errors: [String] = []

    var values: [String] {
        lock.withLock {
            errors
        }
    }

    func record(_ error: Error) {
        lock.withLock {
            errors.append(String(describing: error))
        }
    }
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

private final class StubMicrophoneCaptureSession: MicrophoneCaptureSession, @unchecked Sendable {
    private(set) var didStop = false

    func stop() throws {
        didStop = true
    }
}

private final class SuccessfulRecordingCaptureSessionFactory: RecordingCaptureSessionFactory, @unchecked Sendable {
    private let captureSession: StubRecordingCaptureSession
    private(set) var startedConfigurations: [ResolvedRecordingConfiguration] = []
    private(set) var writers: [any RecordingOutputWriter] = []
    private(set) var audioLevelMonitors: [AudioLevelMonitor?] = []

    init(captureSession: StubRecordingCaptureSession) {
        self.captureSession = captureSession
    }

    func startCapture(
        configuration: ResolvedRecordingConfiguration,
        writer: any RecordingOutputWriter,
        audioLevelMonitor: AudioLevelMonitor?
    ) throws -> any RecordingCaptureSession {
        startedConfigurations.append(configuration)
        writers.append(writer)
        audioLevelMonitors.append(audioLevelMonitor)
        return captureSession
    }
}

private final class SuccessfulMicrophoneCaptureSessionFactory: MicrophoneCaptureSessionFactory, @unchecked Sendable {
    private let microphoneSession: StubMicrophoneCaptureSession
    private(set) var startedDeviceIDs: [String] = []
    private(set) var writers: [any RecordingOutputWriter] = []
    private(set) var audioLevelMonitors: [AudioLevelMonitor?] = []

    init(microphoneSession: StubMicrophoneCaptureSession) {
        self.microphoneSession = microphoneSession
    }

    func startMicrophoneCapture(
        deviceID: String,
        writer: any RecordingOutputWriter,
        audioLevelMonitor: AudioLevelMonitor?
    ) throws -> any MicrophoneCaptureSession {
        startedDeviceIDs.append(deviceID)
        writers.append(writer)
        audioLevelMonitors.append(audioLevelMonitor)
        return microphoneSession
    }
}

private struct FailingMicrophoneCaptureSessionFactory: MicrophoneCaptureSessionFactory {
    var error: OpenRecError

    func startMicrophoneCapture(
        deviceID: String,
        writer: any RecordingOutputWriter,
        audioLevelMonitor: AudioLevelMonitor?
    ) throws -> any MicrophoneCaptureSession {
        throw error
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
