import Foundation

public struct ResolvedRecordingConfiguration: Equatable, Sendable {
    public var source: CaptureSource
    public var pixelSize: CGSize
    public var outputFormat: OutputFormat
    public var videoCodec: VideoCodec
    public var bitrate: Int
    public var frameRate: Int
    public var includeCursor: Bool
    public var microphoneDeviceID: String?

    public init(
        source: CaptureSource,
        pixelSize: CGSize,
        outputFormat: OutputFormat,
        videoCodec: VideoCodec,
        bitrate: Int,
        frameRate: Int,
        includeCursor: Bool,
        microphoneDeviceID: String?
    ) {
        self.source = source
        self.pixelSize = pixelSize
        self.outputFormat = outputFormat
        self.videoCodec = videoCodec
        self.bitrate = bitrate
        self.frameRate = frameRate
        self.includeCursor = includeCursor
        self.microphoneDeviceID = microphoneDeviceID
    }

    public static func == (
        lhs: ResolvedRecordingConfiguration,
        rhs: ResolvedRecordingConfiguration
    ) -> Bool {
        lhs.source == rhs.source &&
            lhs.pixelSize.width == rhs.pixelSize.width &&
            lhs.pixelSize.height == rhs.pixelSize.height &&
            lhs.outputFormat == rhs.outputFormat &&
            lhs.videoCodec == rhs.videoCodec &&
            lhs.bitrate == rhs.bitrate &&
            lhs.frameRate == rhs.frameRate &&
            lhs.includeCursor == rhs.includeCursor &&
            lhs.microphoneDeviceID == rhs.microphoneDeviceID
    }
}
