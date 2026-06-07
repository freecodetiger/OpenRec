import Foundation

public enum RecordingState: Equatable, Sendable {
    case idle
    case preparing(CaptureSource)
    case recording(RecordingSession)
    case stopping(RecordingSession)
    case awaitingSave(URL)
    case failed(OpenRecError)
}

public struct RecordingSession: Equatable, Sendable {
    public var id: UUID
    public var source: CaptureSource
    public var temporaryFileURL: URL

    public init(id: UUID, source: CaptureSource, temporaryFileURL: URL) {
        self.id = id
        self.source = source
        self.temporaryFileURL = temporaryFileURL
    }
}

