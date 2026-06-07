import Foundation

public struct FileTemporaryRecordingFinalizer: TemporaryRecordingFinalizing, @unchecked Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func discardTemporaryRecording(at url: URL) throws {
        let path = url.path(percentEncoded: false)
        guard fileManager.fileExists(atPath: path) else {
            return
        }

        try fileManager.removeItem(at: url)
    }
}
