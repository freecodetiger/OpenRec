import AVFoundation
import CoreMedia
import Foundation
import ScreenCaptureKit
import Testing
@testable import OpenRecCore

@Test func screenCaptureKitFactoryBuildsDisplayStreamConfigurationAndStartsCapture() throws {
    let streamBuilder = SpyScreenCaptureKitStreamBuilder()
    let factory = ScreenCaptureKitRecordingCaptureSessionFactory(
        shareableContentProvider: StubScreenCaptureKitShareableContentProvider(
            displays: [ScreenCaptureKitDisplay(id: DisplayID(rawValue: 42))],
            windows: []
        ),
        streamBuilder: streamBuilder
    )
    let writer = SpyRecordingOutputWriter(outputURL: URL(filePath: "/tmp/openrec-display.mp4"))

    let session = try factory.startCapture(
        configuration: resolvedConfiguration(
            source: .display(DisplayID(rawValue: 42)),
            pixelSize: CGSize(width: 3024, height: 1964),
            frameRate: 60,
            includeCursor: false
        ),
        writer: writer
    )

    #expect(streamBuilder.builtStreams.count == 1)
    #expect(streamBuilder.builtStreams[0].filter == .display(DisplayID(rawValue: 42)))
    #expect(streamBuilder.builtStreams[0].configuration.width == 3024)
    #expect(streamBuilder.builtStreams[0].configuration.height == 1964)
    #expect(streamBuilder.builtStreams[0].configuration.minimumFrameInterval == CMTime(value: 1, timescale: 60))
    #expect(streamBuilder.builtStreams[0].configuration.showsCursor == false)
    #expect(streamBuilder.builtStreams[0].configuration.capturesAudio == false)
    #expect(streamBuilder.builtStreams[0].configuration.captureMicrophone == false)
    #expect(streamBuilder.builtStreams[0].stream.addedOutputTypes == [.screen])
    #expect(streamBuilder.builtStreams[0].stream.didStartCapture)

    try session.stop()

    #expect(streamBuilder.builtStreams[0].stream.didStopCapture)
}

@Test func screenCaptureKitFactoryBuildsWindowFilter() throws {
    let streamBuilder = SpyScreenCaptureKitStreamBuilder()
    let factory = ScreenCaptureKitRecordingCaptureSessionFactory(
        shareableContentProvider: StubScreenCaptureKitShareableContentProvider(
            displays: [],
            windows: [ScreenCaptureKitWindow(id: WindowID(rawValue: 99))]
        ),
        streamBuilder: streamBuilder
    )

    _ = try factory.startCapture(
        configuration: resolvedConfiguration(source: .window(WindowID(rawValue: 99))),
        writer: SpyRecordingOutputWriter(outputURL: URL(filePath: "/tmp/openrec-window.mp4"))
    )

    #expect(streamBuilder.builtStreams.count == 1)
    #expect(streamBuilder.builtStreams[0].filter == .window(WindowID(rawValue: 99)))
}

@Test func screenCaptureKitFactoryMapsMissingDisplayToSourceUnavailable() {
    let factory = ScreenCaptureKitRecordingCaptureSessionFactory(
        shareableContentProvider: StubScreenCaptureKitShareableContentProvider(
            displays: [ScreenCaptureKitDisplay(id: DisplayID(rawValue: 7))],
            windows: []
        ),
        streamBuilder: SpyScreenCaptureKitStreamBuilder()
    )

    #expect(throws: OpenRecError.captureSourceUnavailable(.display(DisplayID(rawValue: 42)))) {
        _ = try factory.startCapture(
            configuration: resolvedConfiguration(source: .display(DisplayID(rawValue: 42))),
            writer: SpyRecordingOutputWriter(outputURL: URL(filePath: "/tmp/openrec-missing.mp4"))
        )
    }
}

@Test func screenCaptureKitOutputHandlerAppendsOnlyScreenSamples() throws {
    let writer = SpyRecordingOutputWriter(outputURL: URL(filePath: "/tmp/openrec-output.mp4"))
    let handler = ScreenCaptureKitStreamOutputHandler(writer: writer)
    let sampleBuffer = try emptySampleBuffer()

    handler.handle(sampleBuffer, type: .screen)
    handler.handle(sampleBuffer, type: .audio)
    if #available(macOS 15.0, *) {
        handler.handle(sampleBuffer, type: .microphone)
    }

    #expect(writer.videoAppendCount == 1)
    #expect(writer.audioAppendCount == 0)
}

private func resolvedConfiguration(
    source: CaptureSource,
    pixelSize: CGSize = CGSize(width: 1920, height: 1080),
    frameRate: Int = 30,
    includeCursor: Bool = true
) -> ResolvedRecordingConfiguration {
    ResolvedRecordingConfiguration(
        source: source,
        pixelSize: pixelSize,
        outputFormat: .mp4,
        videoCodec: .h264,
        bitrate: 7_464_960,
        frameRate: frameRate,
        includeCursor: includeCursor,
        microphoneDeviceID: nil
    )
}

private func emptySampleBuffer() throws -> CMSampleBuffer {
    var sampleBuffer: CMSampleBuffer?
    let status = CMSampleBufferCreate(
        allocator: kCFAllocatorDefault,
        dataBuffer: nil,
        dataReady: true,
        makeDataReadyCallback: nil,
        refcon: nil,
        formatDescription: nil,
        sampleCount: 0,
        sampleTimingEntryCount: 0,
        sampleTimingArray: nil,
        sampleSizeEntryCount: 0,
        sampleSizeArray: nil,
        sampleBufferOut: &sampleBuffer
    )

    guard status == noErr, let sampleBuffer else {
        throw OpenRecError.writerFailed("Could not create test sample buffer.")
    }

    return sampleBuffer
}

private final class SpyRecordingOutputWriter: RecordingOutputWriter, @unchecked Sendable {
    let outputURL: URL
    private(set) var videoAppendCount = 0
    private(set) var audioAppendCount = 0

    init(outputURL: URL) {
        self.outputURL = outputURL
    }

    func start() throws {}

    func appendVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) throws {
        videoAppendCount += 1
    }

    func appendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) throws {
        audioAppendCount += 1
    }

    func finish() throws -> URL {
        outputURL
    }
}

private struct StubScreenCaptureKitShareableContentProvider: ScreenCaptureKitShareableContentProviding {
    var stubDisplays: [ScreenCaptureKitDisplay]
    var stubWindows: [ScreenCaptureKitWindow]

    init(displays: [ScreenCaptureKitDisplay], windows: [ScreenCaptureKitWindow]) {
        self.stubDisplays = displays
        self.stubWindows = windows
    }

    func displays() throws -> [ScreenCaptureKitDisplay] {
        stubDisplays
    }

    func windows() throws -> [ScreenCaptureKitWindow] {
        stubWindows
    }
}

private final class SpyScreenCaptureKitStreamBuilder: ScreenCaptureKitStreamBuilding, @unchecked Sendable {
    struct BuiltStream {
        var filter: ScreenCaptureKitFilter
        var configuration: ScreenCaptureKitStreamConfiguration
        var stream: SpyScreenCaptureKitStream
    }

    private(set) var builtStreams: [BuiltStream] = []

    func makeStream(
        filter: ScreenCaptureKitFilter,
        configuration: ScreenCaptureKitStreamConfiguration
    ) throws -> any ScreenCaptureKitStream {
        let stream = SpyScreenCaptureKitStream()
        builtStreams.append(
            BuiltStream(
                filter: filter,
                configuration: configuration,
                stream: stream
            )
        )
        return stream
    }
}

private final class SpyScreenCaptureKitStream: ScreenCaptureKitStream, @unchecked Sendable {
    private(set) var addedOutputTypes: [ScreenCaptureKitOutputType] = []
    private(set) var didStartCapture = false
    private(set) var didStopCapture = false

    func addOutput(
        _ output: ScreenCaptureKitStreamOutputHandler,
        type: ScreenCaptureKitOutputType,
        sampleHandlerQueue: DispatchQueue?
    ) throws {
        addedOutputTypes.append(type)
    }

    func startCapture() throws {
        didStartCapture = true
    }

    func stopCapture() throws {
        didStopCapture = true
    }
}
