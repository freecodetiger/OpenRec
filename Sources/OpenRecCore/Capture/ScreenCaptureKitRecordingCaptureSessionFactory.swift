import Foundation
import ScreenCaptureKit

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
    public init() {}

    public func startCapture(
        configuration: ResolvedRecordingConfiguration,
        writer: any RecordingOutputWriter
    ) throws -> any RecordingCaptureSession {
        _ = writer
        let streamConfiguration = SCStreamConfiguration()
        streamConfiguration.width = Int(configuration.pixelSize.width.rounded())
        streamConfiguration.height = Int(configuration.pixelSize.height.rounded())
        streamConfiguration.minimumFrameInterval = CMTime(
            value: 1,
            timescale: CMTimeScale(configuration.frameRate)
        )
        streamConfiguration.showsCursor = configuration.includeCursor

        throw OpenRecError.captureConfigurationInvalid(
            "ScreenCaptureKit recording capture is not implemented."
        )
    }
}
