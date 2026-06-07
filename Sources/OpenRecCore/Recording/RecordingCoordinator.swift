import Foundation

public protocol RecordingPermissionValidating: Sendable {
    func validateRecordingPermissions() throws
}

public struct DefaultRecordingPermissionValidator: RecordingPermissionValidating {
    private let permissionChecker: PermissionChecker

    public init(permissionChecker: PermissionChecker) {
        self.permissionChecker = permissionChecker
    }

    public func validateRecordingPermissions() throws {
        try permissionChecker.requireGranted([.screenRecording, .microphone])
    }
}

public protocol RecordingConfigurationResolving: Sendable {
    func resolve(
        source: CaptureSource,
        settings: RecordingSettings
    ) throws -> ResolvedRecordingConfiguration
}

public protocol RecordingEngine: Sendable {
    func start(configuration: ResolvedRecordingConfiguration) throws -> RecordingSession
    func stop(session: RecordingSession) throws -> URL
}

public protocol TemporaryRecordingFinalizing: Sendable {
    func discardTemporaryRecording(at url: URL) throws
}

public struct RecordingEngineFailure: Error, Equatable, Sendable {
    public var error: OpenRecError
    public var temporaryFileURL: URL?

    public init(error: OpenRecError, temporaryFileURL: URL? = nil) {
        self.error = error
        self.temporaryFileURL = temporaryFileURL
    }
}

public final class RecordingCoordinator {
    public private(set) var state: RecordingState

    private let permissionValidator: any RecordingPermissionValidating
    private let configurationResolver: any RecordingConfigurationResolving
    private let engine: any RecordingEngine
    private let finalizer: any TemporaryRecordingFinalizing

    public init(
        permissionValidator: any RecordingPermissionValidating,
        configurationResolver: any RecordingConfigurationResolving,
        engine: any RecordingEngine,
        finalizer: any TemporaryRecordingFinalizing,
        initialState: RecordingState = .idle
    ) {
        self.permissionValidator = permissionValidator
        self.configurationResolver = configurationResolver
        self.engine = engine
        self.finalizer = finalizer
        self.state = initialState
    }

    @discardableResult
    public func start(
        source: CaptureSource,
        settings: RecordingSettings
    ) throws -> RecordingSession {
        guard case .idle = state else {
            throw invalidTransition("Cannot start recording while state is \(stateName).")
        }

        state = .preparing(source)

        do {
            try permissionValidator.validateRecordingPermissions()
            let configuration = try configurationResolver.resolve(
                source: source,
                settings: settings
            )
            let session = try engine.start(configuration: configuration)
            state = .recording(session)
            return session
        } catch {
            let openRecError = mapError(error)
            cleanupTemporaryFile(from: error)
            state = .failed(openRecError)
            throw openRecError
        }
    }

    @discardableResult
    public func stop() throws -> URL {
        guard case let .recording(session) = state else {
            throw invalidTransition("Cannot stop recording while state is \(stateName).")
        }

        state = .stopping(session)

        do {
            let finalizedURL = try engine.stop(session: session)
            state = .awaitingSave(finalizedURL)
            return finalizedURL
        } catch {
            let openRecError = mapError(error)
            cleanupTemporaryFile(from: error, fallbackURL: session.temporaryFileURL)
            state = .failed(openRecError)
            throw openRecError
        }
    }

    public func markSaved() throws {
        guard case .awaitingSave = state else {
            throw invalidTransition("Cannot mark recording saved while state is \(stateName).")
        }

        state = .idle
    }

    public func discard() throws {
        guard case let .awaitingSave(url) = state else {
            throw invalidTransition("Cannot discard recording while state is \(stateName).")
        }

        do {
            try finalizer.discardTemporaryRecording(at: url)
            state = .idle
        } catch {
            let openRecError = mapError(error)
            state = .failed(openRecError)
            throw openRecError
        }
    }

    public func saveCancelled() -> OpenRecError {
        guard case let .awaitingSave(url) = state else {
            return invalidTransition("Cannot cancel save while state is \(stateName).")
        }

        return .saveCancelled(url.path(percentEncoded: false))
    }

    private var stateName: String {
        switch state {
        case .idle:
            "idle"
        case .preparing:
            "preparing"
        case .recording:
            "recording"
        case .stopping:
            "stopping"
        case .awaitingSave:
            "awaitingSave"
        case .failed:
            "failed"
        }
    }

    private func invalidTransition(_ message: String) -> OpenRecError {
        .captureConfigurationInvalid(message)
    }

    private func mapError(_ error: any Error) -> OpenRecError {
        if let failure = error as? RecordingEngineFailure {
            return failure.error
        }

        if let openRecError = error as? OpenRecError {
            return openRecError
        }

        return .unknown(String(describing: error))
    }

    private func cleanupTemporaryFile(
        from error: any Error,
        fallbackURL: URL? = nil
    ) {
        let url = (error as? RecordingEngineFailure)?.temporaryFileURL ?? fallbackURL
        guard let url else { return }
        try? finalizer.discardTemporaryRecording(at: url)
    }
}
