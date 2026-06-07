import Foundation
import Testing
@testable import OpenRecCore

@Suite(.serialized)
struct RecordingCoordinatorTests {
    @Test func startTransitionsFromIdleToRecordingAfterValidationAndEngineStart() throws {
        let source = CaptureSource.display(DisplayID(rawValue: 1))
        let configuration = resolvedConfiguration(for: source)
        let engine = StubRecordingEngine(startedSession: session(for: source))
        let coordinator = RecordingCoordinator(
            permissionValidator: StubPermissionValidator(),
            configurationResolver: StubRecordingConfigurationResolving(configuration: configuration),
            engine: engine,
            finalizer: StubTemporaryRecordingFinalizer()
        )

        let session = try coordinator.start(source: source, settings: .defaults)

        #expect(coordinator.state == .recording(session))
        #expect(session.source == source)
        #expect(engine.startedConfigurations == [configuration])
    }

    @Test func startRejectsReentryWhileRecordingAndLeavesCurrentSessionUnchanged() throws {
        let source = CaptureSource.display(DisplayID(rawValue: 1))
        let initialSession = session(for: source)
        let engine = StubRecordingEngine(startedSession: initialSession)
        let coordinator = RecordingCoordinator(
            permissionValidator: StubPermissionValidator(),
            configurationResolver: StubRecordingConfigurationResolving(configuration: resolvedConfiguration(for: source)),
            engine: engine,
            finalizer: StubTemporaryRecordingFinalizer()
        )
        _ = try coordinator.start(source: source, settings: .defaults)

        #expect(throws: OpenRecError.captureConfigurationInvalid("Cannot start recording while state is recording.")) {
            try coordinator.start(source: source, settings: .defaults)
        }
        #expect(coordinator.state == .recording(initialSession))
        #expect(engine.startedConfigurations.count == 1)
    }

    @Test func stopOnlyWorksWhileRecording() throws {
        let coordinator = RecordingCoordinator(
            permissionValidator: StubPermissionValidator(),
            configurationResolver: StubRecordingConfigurationResolving(configuration: resolvedConfiguration(for: .display(DisplayID(rawValue: 1)))),
            engine: StubRecordingEngine(startedSession: session(for: .display(DisplayID(rawValue: 1)))),
            finalizer: StubTemporaryRecordingFinalizer()
        )

        #expect(throws: OpenRecError.captureConfigurationInvalid("Cannot stop recording while state is idle.")) {
            try coordinator.stop()
        }
        #expect(coordinator.state == .idle)
    }

    @Test func stopFinalizesRecordingAndMovesToAwaitingSave() throws {
        let source = CaptureSource.window(WindowID(rawValue: 42))
        let startedSession = session(for: source)
        let finalizedURL = URL(filePath: "/tmp/openrec-finalized.mov")
        let engine = StubRecordingEngine(
            startedSession: startedSession,
            finalizedURL: finalizedURL
        )
        let coordinator = RecordingCoordinator(
            permissionValidator: StubPermissionValidator(),
            configurationResolver: StubRecordingConfigurationResolving(configuration: resolvedConfiguration(for: source)),
            engine: engine,
            finalizer: StubTemporaryRecordingFinalizer()
        )
        _ = try coordinator.start(source: source, settings: .defaults)

        let url = try coordinator.stop()

        #expect(url == finalizedURL)
        #expect(coordinator.state == .awaitingSave(finalizedURL))
        #expect(engine.stoppedSessions == [startedSession])
    }

    @Test func markSavedFromAwaitingSaveReturnsToIdleAndForgetsTempFile() throws {
        let finalizedURL = URL(filePath: "/tmp/openrec-finalized.mp4")
        let finalizer = StubTemporaryRecordingFinalizer()
        let coordinator = try coordinatorAwaitingSave(finalizedURL: finalizedURL, finalizer: finalizer)

        try coordinator.markSaved()

        #expect(coordinator.state == .idle)
        #expect(finalizer.discardedURLs.isEmpty)
    }

    @Test func discardFromAwaitingSaveDeletesTempFileAndReturnsToIdle() throws {
        let finalizedURL = URL(filePath: "/tmp/openrec-finalized.mp4")
        let finalizer = StubTemporaryRecordingFinalizer()
        let coordinator = try coordinatorAwaitingSave(finalizedURL: finalizedURL, finalizer: finalizer)

        try coordinator.discard()

        #expect(coordinator.state == .idle)
        #expect(finalizer.discardedURLs == [finalizedURL])
    }

    @Test func saveCancelledFromAwaitingSaveKeepsTempFileAvailableForRetry() throws {
        let finalizedURL = URL(filePath: "/tmp/openrec-finalized.mp4")
        let finalizer = StubTemporaryRecordingFinalizer()
        let coordinator = try coordinatorAwaitingSave(finalizedURL: finalizedURL, finalizer: finalizer)

        let error = coordinator.saveCancelled()

        #expect(error == .saveCancelled(finalizedURL.path(percentEncoded: false)))
        #expect(coordinator.state == .awaitingSave(finalizedURL))
        #expect(finalizer.discardedURLs.isEmpty)
    }

    @Test func permissionFailureMapsErrorAndLeavesCoordinatorFailed() {
        let source = CaptureSource.display(DisplayID(rawValue: 1))
        let coordinator = RecordingCoordinator(
            permissionValidator: StubPermissionValidator(error: .permissionDenied(.screenRecording)),
            configurationResolver: StubRecordingConfigurationResolving(configuration: resolvedConfiguration(for: source)),
            engine: StubRecordingEngine(startedSession: session(for: source)),
            finalizer: StubTemporaryRecordingFinalizer()
        )

        #expect(throws: OpenRecError.permissionDenied(.screenRecording)) {
            try coordinator.start(source: source, settings: .defaults)
        }
        #expect(coordinator.state == .failed(.permissionDenied(.screenRecording)))
    }

    @Test func writerInitializationFailureCleansTemporaryFileAndMovesToFailed() {
        let source = CaptureSource.display(DisplayID(rawValue: 1))
        let temporaryURL = URL(filePath: "/tmp/openrec-start-failed.mp4")
        let finalizer = StubTemporaryRecordingFinalizer()
        let engine = StubRecordingEngine(
            startError: RecordingEngineFailure(
                error: .writerInitializationFailed("writer could not be created"),
                temporaryFileURL: temporaryURL
            )
        )
        let coordinator = RecordingCoordinator(
            permissionValidator: StubPermissionValidator(),
            configurationResolver: StubRecordingConfigurationResolving(configuration: resolvedConfiguration(for: source)),
            engine: engine,
            finalizer: finalizer
        )

        #expect(throws: OpenRecError.writerInitializationFailed("writer could not be created")) {
            try coordinator.start(source: source, settings: .defaults)
        }
        #expect(coordinator.state == .failed(.writerInitializationFailed("writer could not be created")))
        #expect(finalizer.discardedURLs == [temporaryURL])
    }

    @Test func writerFailureDuringStopCleansTemporaryFileAndMovesToFailed() throws {
        let source = CaptureSource.display(DisplayID(rawValue: 1))
        let startedSession = session(for: source)
        let finalizer = StubTemporaryRecordingFinalizer()
        let engine = StubRecordingEngine(
            startedSession: startedSession,
            stopError: RecordingEngineFailure(
                error: .writerFailed("writer finalization failed"),
                temporaryFileURL: startedSession.temporaryFileURL
            )
        )
        let coordinator = RecordingCoordinator(
            permissionValidator: StubPermissionValidator(),
            configurationResolver: StubRecordingConfigurationResolving(configuration: resolvedConfiguration(for: source)),
            engine: engine,
            finalizer: finalizer
        )
        _ = try coordinator.start(source: source, settings: .defaults)

        #expect(throws: OpenRecError.writerFailed("writer finalization failed")) {
            try coordinator.stop()
        }
        #expect(coordinator.state == .failed(.writerFailed("writer finalization failed")))
        #expect(finalizer.discardedURLs == [startedSession.temporaryFileURL])
    }

    @Test func defaultConfigurationResolverUsesSourceMetadataProvider() throws {
        let source = CaptureSource.display(DisplayID(rawValue: 10))
        let metadata = CaptureSourceMetadata(
            source: source,
            pixelSize: CGSize(width: 3024, height: 1964),
            isAvailable: true
        )
        let resolver = DefaultRecordingConfigurationResolver(
            sourceValidator: StubCaptureSourceValidator(metadata: metadata)
        )

        let configuration = try resolver.resolve(source: source, settings: .defaults)

        #expect(configuration.source == source)
        #expect(configuration.pixelSize.width == 3024)
        #expect(configuration.pixelSize.height == 1964)
        #expect(configuration.frameRate == 30)
    }

    @Test func defaultPermissionValidatorRequiresScreenRecordingAndMicrophone() {
        let checker = PermissionChecker(provider: InMemoryPermissionStatusProvider(statuses: [
            .screenRecording: .granted,
            .microphone: .denied
        ]))
        let validator = DefaultRecordingPermissionValidator(permissionChecker: checker)

        #expect(throws: OpenRecError.permissionDenied(.microphone)) {
            try validator.validateRecordingPermissions()
        }
    }

    @Test func fileTemporaryRecordingFinalizerDeletesExistingFileAndIgnoresMissingFile() throws {
        let directory = try temporaryDirectory()
        let temporaryFile = directory.appending(path: "openrec-temp.mp4")
        try Data("recording".utf8).write(to: temporaryFile)
        let finalizer = FileTemporaryRecordingFinalizer()

        try finalizer.discardTemporaryRecording(at: temporaryFile)
        try finalizer.discardTemporaryRecording(at: temporaryFile)

        #expect(!FileManager.default.fileExists(atPath: temporaryFile.path(percentEncoded: false)))
    }

    private func coordinatorAwaitingSave(
        finalizedURL: URL,
        finalizer: StubTemporaryRecordingFinalizer
    ) throws -> RecordingCoordinator {
        let source = CaptureSource.display(DisplayID(rawValue: 3))
        let engine = StubRecordingEngine(
            startedSession: session(for: source),
            finalizedURL: finalizedURL
        )
        let coordinator = RecordingCoordinator(
            permissionValidator: StubPermissionValidator(),
            configurationResolver: StubRecordingConfigurationResolving(configuration: resolvedConfiguration(for: source)),
            engine: engine,
            finalizer: finalizer
        )
        _ = try coordinator.start(source: source, settings: .defaults)
        _ = try coordinator.stop()
        return coordinator
    }

    private func resolvedConfiguration(for source: CaptureSource) -> ResolvedRecordingConfiguration {
        ResolvedRecordingConfiguration(
            source: source,
            pixelSize: CGSize(width: 1920, height: 1080),
            outputFormat: .mp4,
            videoCodec: .h264,
            bitrate: 7_464_960,
            frameRate: 30,
            includeCursor: true,
            microphoneDeviceID: nil
        )
    }

    private func session(for source: CaptureSource) -> RecordingSession {
        RecordingSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            source: source,
            temporaryFileURL: URL(filePath: "/tmp/openrec-recording.tmp")
        )
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "OpenRecRecordingCoordinatorTests")
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private final class StubPermissionValidator: RecordingPermissionValidating, @unchecked Sendable {
    private let error: OpenRecError?

    init(error: OpenRecError? = nil) {
        self.error = error
    }

    func validateRecordingPermissions() throws {
        if let error {
            throw error
        }
    }
}

private final class StubRecordingConfigurationResolving: RecordingConfigurationResolving, @unchecked Sendable {
    private let configuration: ResolvedRecordingConfiguration

    init(configuration: ResolvedRecordingConfiguration) {
        self.configuration = configuration
    }

    func resolve(source: CaptureSource, settings: RecordingSettings) throws -> ResolvedRecordingConfiguration {
        configuration
    }
}

private final class StubRecordingEngine: RecordingEngine, @unchecked Sendable {
    private let startedSession: RecordingSession?
    private let finalizedURL: URL
    private let startError: RecordingEngineFailure?
    private let stopError: RecordingEngineFailure?
    private(set) var startedConfigurations: [ResolvedRecordingConfiguration] = []
    private(set) var stoppedSessions: [RecordingSession] = []

    init(
        startedSession: RecordingSession? = nil,
        finalizedURL: URL = URL(filePath: "/tmp/openrec-finalized.mp4"),
        startError: RecordingEngineFailure? = nil,
        stopError: RecordingEngineFailure? = nil
    ) {
        self.startedSession = startedSession
        self.finalizedURL = finalizedURL
        self.startError = startError
        self.stopError = stopError
    }

    func start(configuration: ResolvedRecordingConfiguration) throws -> RecordingSession {
        startedConfigurations.append(configuration)
        if let startError {
            throw startError
        }
        return startedSession ?? RecordingSession(
            id: UUID(),
            source: configuration.source,
            temporaryFileURL: URL(filePath: "/tmp/openrec-recording.tmp")
        )
    }

    func stop(session: RecordingSession) throws -> URL {
        stoppedSessions.append(session)
        if let stopError {
            throw stopError
        }
        return finalizedURL
    }
}

private final class StubTemporaryRecordingFinalizer: TemporaryRecordingFinalizing, @unchecked Sendable {
    private(set) var discardedURLs: [URL] = []

    func discardTemporaryRecording(at url: URL) throws {
        discardedURLs.append(url)
    }
}

private final class StubCaptureSourceValidator: CaptureSourceValidating, @unchecked Sendable {
    private let metadata: CaptureSourceMetadata

    init(metadata: CaptureSourceMetadata) {
        self.metadata = metadata
    }

    func metadata(for source: CaptureSource) throws -> CaptureSourceMetadata {
        metadata
    }
}
