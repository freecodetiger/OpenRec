import Foundation

public final class ScreenCaptureRecordingEngine: RecordingEngine, @unchecked Sendable {
    private struct ActiveRecording {
        var writer: any RecordingOutputWriter
        var captureSession: any RecordingCaptureSession
    }

    private let outputDirectory: URL
    private let writerFactory: any RecordingOutputWriterFactory
    private let captureSessionFactory: any RecordingCaptureSessionFactory
    private let idProvider: @Sendable () -> UUID
    private let fileManager: FileManager
    private let lock = NSLock()
    private var activeRecordings: [UUID: ActiveRecording] = [:]

    public init(
        outputDirectory: URL = FileManager.default.temporaryDirectory,
        writerFactory: any RecordingOutputWriterFactory = AVAssetRecordingOutputWriterFactory(),
        captureSessionFactory: any RecordingCaptureSessionFactory = ScreenCaptureKitRecordingCaptureSessionFactory(),
        idProvider: @escaping @Sendable () -> UUID = { UUID() },
        fileManager: FileManager = .default
    ) {
        self.outputDirectory = outputDirectory
        self.writerFactory = writerFactory
        self.captureSessionFactory = captureSessionFactory
        self.idProvider = idProvider
        self.fileManager = fileManager
    }

    public func temporaryRecordingURL(
        for configuration: ResolvedRecordingConfiguration
    ) throws -> URL {
        let settings = try RecordingOutputWriterSettings(configuration: configuration)
        return temporaryRecordingURL(fileExtension: settings.fileExtension, id: idProvider())
    }

    public func start(configuration: ResolvedRecordingConfiguration) throws -> RecordingSession {
        let settings = try RecordingOutputWriterSettings(configuration: configuration)
        let sessionID = idProvider()
        let outputURL = temporaryRecordingURL(
            fileExtension: settings.fileExtension,
            id: sessionID
        )

        var writer: (any RecordingOutputWriter)?

        do {
            try fileManager.createDirectory(
                at: outputDirectory,
                withIntermediateDirectories: true
            )
            let createdWriter = try writerFactory.makeWriter(
                settings: settings,
                outputURL: outputURL
            )
            writer = createdWriter
            try createdWriter.start()

            let captureSession = try captureSessionFactory.startCapture(
                configuration: configuration,
                writer: createdWriter
            )

            let session = RecordingSession(
                id: sessionID,
                source: configuration.source,
                temporaryFileURL: outputURL
            )

            lock.withLock {
                activeRecordings[sessionID] = ActiveRecording(
                    writer: createdWriter,
                    captureSession: captureSession
                )
            }

            return session
        } catch {
            if writer != nil {
                try? fileManager.removeItem(at: outputURL)
            }

            throw RecordingEngineFailure(
                error: Self.mapError(error),
                temporaryFileURL: writer == nil ? nil : outputURL
            )
        }
    }

    public func stop(session: RecordingSession) throws -> URL {
        guard let activeRecording = lock.withLock({
            activeRecordings.removeValue(forKey: session.id)
        }) else {
            throw OpenRecError.captureConfigurationInvalid("Recording session is not active.")
        }

        do {
            try activeRecording.captureSession.stop()
            return try activeRecording.writer.finish()
        } catch {
            try? fileManager.removeItem(at: session.temporaryFileURL)
            throw RecordingEngineFailure(
                error: Self.mapError(error),
                temporaryFileURL: session.temporaryFileURL
            )
        }
    }

    private func temporaryRecordingURL(fileExtension: String, id: UUID) -> URL {
        outputDirectory.appending(
            path: "openrec-\(id.uuidString.lowercased()).\(fileExtension)"
        )
    }

    private static func mapError(_ error: any Error) -> OpenRecError {
        if let failure = error as? RecordingEngineFailure {
            return failure.error
        }

        if let openRecError = error as? OpenRecError {
            return openRecError
        }

        return .unknown(String(describing: error))
    }
}
