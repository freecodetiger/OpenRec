import Foundation
@preconcurrency import ScreenCaptureKit

public protocol RecordingCaptureSession: AnyObject, Sendable {
    func stop() throws
}

public protocol RecordingCaptureSessionFactory: Sendable {
    func startCapture(
        configuration: ResolvedRecordingConfiguration,
        writer: any RecordingOutputWriter
    ) throws -> any RecordingCaptureSession
}

public struct ScreenCaptureKitRecordingCaptureSessionFactory: RecordingCaptureSessionFactory {
    private let shareableContentProvider: any ScreenCaptureKitShareableContentProviding
    private let streamBuilder: any ScreenCaptureKitStreamBuilding

    public init() {
        self.shareableContentProvider = ScreenCaptureKitSystemShareableContentProvider()
        self.streamBuilder = ScreenCaptureKitSystemStreamBuilder()
    }

    init(
        shareableContentProvider: any ScreenCaptureKitShareableContentProviding,
        streamBuilder: any ScreenCaptureKitStreamBuilding
    ) {
        self.shareableContentProvider = shareableContentProvider
        self.streamBuilder = streamBuilder
    }

    public func startCapture(
        configuration: ResolvedRecordingConfiguration,
        writer: any RecordingOutputWriter
    ) throws -> any RecordingCaptureSession {
        let streamConfiguration = try ScreenCaptureKitStreamConfiguration(
            configuration: configuration
        )
        let filter = try makeFilter(for: configuration.source)
        let outputHandler = ScreenCaptureKitStreamOutputHandler(writer: writer)
        let stream = try streamBuilder.makeStream(
            filter: filter,
            configuration: streamConfiguration
        )
        try stream.addOutput(
            outputHandler,
            type: .screen,
            sampleHandlerQueue: DispatchQueue(label: "openrec.screencapturekit.video")
        )
        try stream.startCapture()

        return ScreenCaptureKitRecordingCaptureSession(
            stream: stream,
            outputHandler: outputHandler
        )
    }

    private func makeFilter(for source: CaptureSource) throws -> ScreenCaptureKitFilter {
        switch source {
        case let .display(displayID):
            let displays = try shareableContentProvider.displays()
            guard let display = displays.first(where: { $0.id == displayID }) else {
                throw OpenRecError.captureSourceUnavailable(source)
            }
            return ScreenCaptureKitFilter(display: display)
        case let .window(windowID):
            let windows = try shareableContentProvider.windows()
            guard let window = windows.first(where: { $0.id == windowID }) else {
                throw OpenRecError.captureSourceUnavailable(source)
            }
            return ScreenCaptureKitFilter(window: window)
        }
    }
}

struct ScreenCaptureKitDisplay: Equatable, @unchecked Sendable {
    var id: DisplayID
    fileprivate var scDisplay: SCDisplay?

    init(id: DisplayID) {
        self.id = id
        self.scDisplay = nil
    }

    fileprivate init(_ display: SCDisplay) {
        self.id = DisplayID(rawValue: display.displayID)
        self.scDisplay = display
    }

    static func == (lhs: ScreenCaptureKitDisplay, rhs: ScreenCaptureKitDisplay) -> Bool {
        lhs.id == rhs.id
    }
}

struct ScreenCaptureKitWindow: Equatable, @unchecked Sendable {
    var id: WindowID
    fileprivate var scWindow: SCWindow?

    init(id: WindowID) {
        self.id = id
        self.scWindow = nil
    }

    fileprivate init(_ window: SCWindow) {
        self.id = WindowID(rawValue: window.windowID)
        self.scWindow = window
    }

    static func == (lhs: ScreenCaptureKitWindow, rhs: ScreenCaptureKitWindow) -> Bool {
        lhs.id == rhs.id
    }
}

struct ScreenCaptureKitFilter: Equatable, @unchecked Sendable {
    enum Kind: Equatable, Sendable {
        case display(DisplayID)
        case window(WindowID)
    }

    var kind: Kind
    fileprivate var contentFilter: SCContentFilter?

    fileprivate init(kind: Kind, contentFilter: SCContentFilter?) {
        self.kind = kind
        self.contentFilter = contentFilter
    }

    static func display(_ id: DisplayID) -> ScreenCaptureKitFilter {
        ScreenCaptureKitFilter(kind: .display(id), contentFilter: nil)
    }

    static func window(_ id: WindowID) -> ScreenCaptureKitFilter {
        ScreenCaptureKitFilter(kind: .window(id), contentFilter: nil)
    }

    fileprivate init(display: ScreenCaptureKitDisplay) {
        self.kind = .display(display.id)
        if let scDisplay = display.scDisplay {
            self.contentFilter = SCContentFilter(display: scDisplay, excludingWindows: [])
        } else {
            self.contentFilter = nil
        }
    }

    fileprivate init(window: ScreenCaptureKitWindow) {
        self.kind = .window(window.id)
        if let scWindow = window.scWindow {
            self.contentFilter = SCContentFilter(desktopIndependentWindow: scWindow)
        } else {
            self.contentFilter = nil
        }
    }

    static func == (lhs: ScreenCaptureKitFilter, rhs: ScreenCaptureKitFilter) -> Bool {
        lhs.kind == rhs.kind
    }
}

struct ScreenCaptureKitStreamConfiguration: Equatable, Sendable {
    var width: Int
    var height: Int
    var minimumFrameInterval: CMTime
    var showsCursor: Bool
    var capturesAudio: Bool
    var captureMicrophone: Bool

    init(configuration: ResolvedRecordingConfiguration) throws {
        guard configuration.pixelSize.width.isFinite,
              configuration.pixelSize.height.isFinite,
              configuration.pixelSize.width > 0,
              configuration.pixelSize.height > 0
        else {
            throw OpenRecError.captureConfigurationInvalid(
                "ScreenCaptureKit pixel size must be positive."
            )
        }

        guard configuration.frameRate > 0 else {
            throw OpenRecError.captureConfigurationInvalid(
                "ScreenCaptureKit frame rate must be positive."
            )
        }

        self.width = Int(configuration.pixelSize.width.rounded())
        self.height = Int(configuration.pixelSize.height.rounded())
        self.minimumFrameInterval = CMTime(
            value: 1,
            timescale: CMTimeScale(configuration.frameRate)
        )
        self.showsCursor = configuration.includeCursor
        self.capturesAudio = false
        self.captureMicrophone = false
    }

    fileprivate func makeSCStreamConfiguration() -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.width = width
        configuration.height = height
        configuration.minimumFrameInterval = minimumFrameInterval
        configuration.showsCursor = showsCursor
        configuration.capturesAudio = capturesAudio
        if #available(macOS 15.0, *) {
            configuration.captureMicrophone = captureMicrophone
        }
        return configuration
    }
}

enum ScreenCaptureKitOutputType: Equatable, Sendable {
    case screen
    case audio
    case microphone
    case unsupported

    fileprivate init(_ type: SCStreamOutputType) {
        switch type {
        case .screen:
            self = .screen
        case .audio:
            self = .audio
        case .microphone:
            self = .microphone
        @unknown default:
            self = .unsupported
        }
    }

    fileprivate var scStreamOutputType: SCStreamOutputType {
        switch self {
        case .screen:
            .screen
        case .audio:
            .audio
        case .microphone:
            if #available(macOS 15.0, *) {
                .microphone
            } else {
                .audio
            }
        case .unsupported:
            .screen
        }
    }
}

protocol ScreenCaptureKitShareableContentProviding: Sendable {
    func displays() throws -> [ScreenCaptureKitDisplay]
    func windows() throws -> [ScreenCaptureKitWindow]
}

struct ScreenCaptureKitSystemShareableContentProvider: ScreenCaptureKitShareableContentProviding {
    func displays() throws -> [ScreenCaptureKitDisplay] {
        let content = try shareableContent()
        return content.displays.map(ScreenCaptureKitDisplay.init)
    }

    func windows() throws -> [ScreenCaptureKitWindow] {
        let content = try shareableContent()
        return content.windows.map(ScreenCaptureKitWindow.init)
    }

    private func shareableContent() throws -> SCShareableContent {
        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var result: Result<SCShareableContent, Error>?

        SCShareableContent.getExcludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        ) { content, error in
            lock.withLock {
                if let error {
                    result = .failure(error)
                } else if let content {
                    result = .success(content)
                } else {
                    result = .failure(
                        OpenRecError.captureConfigurationInvalid(
                            "ScreenCaptureKit returned no shareable content."
                        )
                    )
                }
            }
            semaphore.signal()
        }

        semaphore.wait()

        return try lock.withLock {
            try result?.get() ?? {
                throw OpenRecError.unknown("ScreenCaptureKit shareable content returned no result.")
            }()
        }
    }
}

protocol ScreenCaptureKitStreamBuilding: Sendable {
    func makeStream(
        filter: ScreenCaptureKitFilter,
        configuration: ScreenCaptureKitStreamConfiguration
    ) throws -> any ScreenCaptureKitStream
}

struct ScreenCaptureKitSystemStreamBuilder: ScreenCaptureKitStreamBuilding {
    func makeStream(
        filter: ScreenCaptureKitFilter,
        configuration: ScreenCaptureKitStreamConfiguration
    ) throws -> any ScreenCaptureKitStream {
        guard let contentFilter = filter.contentFilter else {
            throw OpenRecError.captureConfigurationInvalid(
                "ScreenCaptureKit content filter could not be created for \(filter.kind)."
            )
        }

        return ScreenCaptureKitStreamAdapter(
            stream: SCStream(
                filter: contentFilter,
                configuration: configuration.makeSCStreamConfiguration(),
                delegate: nil
            )
        )
    }
}

protocol ScreenCaptureKitStream: AnyObject, Sendable {
    func addOutput(
        _ output: ScreenCaptureKitStreamOutputHandler,
        type: ScreenCaptureKitOutputType,
        sampleHandlerQueue: DispatchQueue?
    ) throws
    func startCapture() throws
    func stopCapture() throws
}

final class ScreenCaptureKitStreamAdapter: ScreenCaptureKitStream, @unchecked Sendable {
    private let stream: SCStream

    init(stream: SCStream) {
        self.stream = stream
    }

    func addOutput(
        _ output: ScreenCaptureKitStreamOutputHandler,
        type: ScreenCaptureKitOutputType,
        sampleHandlerQueue: DispatchQueue?
    ) throws {
        do {
            try stream.addStreamOutput(
                output,
                type: type.scStreamOutputType,
                sampleHandlerQueue: sampleHandlerQueue
            )
        } catch {
            throw OpenRecError.captureConfigurationInvalid(
                "ScreenCaptureKit failed to add stream output: \(error.localizedDescription)"
            )
        }
    }

    func startCapture() throws {
        try waitForCallback { completion in
            stream.startCapture(completionHandler: completion)
        }
    }

    func stopCapture() throws {
        try waitForCallback { completion in
            stream.stopCapture(completionHandler: completion)
        }
    }
}

final class ScreenCaptureKitStreamOutputHandler: NSObject, SCStreamOutput, @unchecked Sendable {
    private let writer: any RecordingOutputWriter
    private let lock = NSLock()
    private var lastError: OpenRecError?

    init(writer: any RecordingOutputWriter) {
        self.writer = writer
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        handle(sampleBuffer, type: ScreenCaptureKitOutputType(type))
    }

    func handle(_ sampleBuffer: CMSampleBuffer, type: ScreenCaptureKitOutputType) {
        guard type == .screen else {
            return
        }

        do {
            try writer.appendVideoSampleBuffer(sampleBuffer)
        } catch let error as OpenRecError {
            setLastError(error)
        } catch {
            setLastError(.writerFailed(String(describing: error)))
        }
    }

    func takeLastError() -> OpenRecError? {
        lock.withLock {
            let error = lastError
            lastError = nil
            return error
        }
    }

    private func setLastError(_ error: OpenRecError) {
        lock.withLock {
            lastError = error
        }
    }
}

final class ScreenCaptureKitRecordingCaptureSession: RecordingCaptureSession, @unchecked Sendable {
    private let stream: any ScreenCaptureKitStream
    private let outputHandler: ScreenCaptureKitStreamOutputHandler

    init(stream: any ScreenCaptureKitStream, outputHandler: ScreenCaptureKitStreamOutputHandler) {
        self.stream = stream
        self.outputHandler = outputHandler
    }

    func stop() throws {
        try stream.stopCapture()

        if let error = outputHandler.takeLastError() {
            throw error
        }
    }
}

private func waitForCallback(
    _ operation: (@escaping (Error?) -> Void) -> Void
) throws {
    let semaphore = DispatchSemaphore(value: 0)
    let lock = NSLock()
    var callbackError: Error?

    operation { error in
        lock.withLock {
            callbackError = error
        }
        semaphore.signal()
    }

    semaphore.wait()

    if let callbackError = lock.withLock({ callbackError }) {
        throw OpenRecError.captureConfigurationInvalid(
            "ScreenCaptureKit stream operation failed: \(callbackError.localizedDescription)"
        )
    }
}
