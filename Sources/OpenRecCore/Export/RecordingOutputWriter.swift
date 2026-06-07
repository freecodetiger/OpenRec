@preconcurrency import AVFoundation
import Foundation

public struct RecordingOutputWriterSettings {
    public var fileType: AVFileType
    public var fileExtension: String
    public var videoCodec: AVVideoCodecType
    public var audioFormatID: AudioFormatID
    public var videoWidth: Int
    public var videoHeight: Int
    public var videoBitrate: Int
    public var frameRate: Int
    public var audioSampleRate: Int
    public var audioChannelCount: Int
    public var audioBitrate: Int

    public init(configuration: ResolvedRecordingConfiguration) throws {
        guard configuration.pixelSize.width.isFinite,
              configuration.pixelSize.height.isFinite,
              configuration.pixelSize.width > 0,
              configuration.pixelSize.height > 0
        else {
            throw OpenRecError.captureConfigurationInvalid(
                "Recording output pixel size must be positive."
            )
        }

        guard configuration.bitrate > 0 else {
            throw OpenRecError.captureConfigurationInvalid(
                "Recording output video bitrate must be positive."
            )
        }

        guard configuration.frameRate > 0 else {
            throw OpenRecError.captureConfigurationInvalid(
                "Recording output frame rate must be positive."
            )
        }

        self.fileType = switch configuration.outputFormat {
        case .mp4:
            .mp4
        case .mov:
            .mov
        }
        self.fileExtension = configuration.outputFormat.rawValue
        self.videoCodec = switch configuration.videoCodec {
        case .h264:
            .h264
        case .hevc:
            .hevc
        }
        self.audioFormatID = kAudioFormatMPEG4AAC
        self.videoWidth = Int(configuration.pixelSize.width.rounded())
        self.videoHeight = Int(configuration.pixelSize.height.rounded())
        self.videoBitrate = configuration.bitrate
        self.frameRate = configuration.frameRate
        self.audioSampleRate = 48_000
        self.audioChannelCount = 2
        self.audioBitrate = 128_000
    }

    public var videoOutputSettings: [String: Any] {
        [
            AVVideoCodecKey: videoCodec,
            AVVideoWidthKey: videoWidth,
            AVVideoHeightKey: videoHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: videoBitrate,
                AVVideoExpectedSourceFrameRateKey: frameRate,
                AVVideoAllowFrameReorderingKey: false
            ]
        ]
    }

    public var audioOutputSettings: [String: Any] {
        [
            AVFormatIDKey: audioFormatID,
            AVSampleRateKey: audioSampleRate,
            AVNumberOfChannelsKey: audioChannelCount,
            AVEncoderBitRateKey: audioBitrate
        ]
    }
}

public protocol RecordingOutputWriter: AnyObject, Sendable {
    var outputURL: URL { get }

    func start() throws
    func appendVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) throws
    func appendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) throws
    func finish() throws -> URL
}

public protocol RecordingOutputWriterFactory: Sendable {
    func makeWriter(
        settings: RecordingOutputWriterSettings,
        outputURL: URL
    ) throws -> any RecordingOutputWriter
}

public struct AVAssetRecordingOutputWriterFactory: RecordingOutputWriterFactory {
    public init() {}

    public func makeWriter(
        settings: RecordingOutputWriterSettings,
        outputURL: URL
    ) throws -> any RecordingOutputWriter {
        do {
            return try AVAssetRecordingOutputWriter(settings: settings, outputURL: outputURL)
        } catch let error as OpenRecError {
            throw error
        } catch {
            throw OpenRecError.writerInitializationFailed(String(describing: error))
        }
    }
}

public final class AVAssetRecordingOutputWriter: RecordingOutputWriter, @unchecked Sendable {
    public let outputURL: URL

    private let assetWriter: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let audioInput: AVAssetWriterInput

    public init(settings: RecordingOutputWriterSettings, outputURL: URL) throws {
        self.outputURL = outputURL
        self.assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: settings.fileType)
        self.videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: settings.videoOutputSettings
        )
        self.audioInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: settings.audioOutputSettings
        )

        videoInput.expectsMediaDataInRealTime = true
        audioInput.expectsMediaDataInRealTime = true

        guard assetWriter.canAdd(videoInput) else {
            throw OpenRecError.writerInitializationFailed(
                "AVAssetWriter cannot add the configured video input."
            )
        }

        guard assetWriter.canAdd(audioInput) else {
            throw OpenRecError.writerInitializationFailed(
                "AVAssetWriter cannot add the configured audio input."
            )
        }

        assetWriter.add(videoInput)
        assetWriter.add(audioInput)
    }

    public func start() throws {
        guard assetWriter.startWriting() else {
            throw OpenRecError.writerInitializationFailed(
                assetWriter.error?.localizedDescription ?? "AVAssetWriter failed to start."
            )
        }

        assetWriter.startSession(atSourceTime: .zero)
    }

    public func appendVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) throws {
        try append(sampleBuffer, to: videoInput, label: "video")
    }

    public func appendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) throws {
        try append(sampleBuffer, to: audioInput, label: "audio")
    }

    public func finish() throws -> URL {
        if assetWriter.status == .writing {
            videoInput.markAsFinished()
            audioInput.markAsFinished()
        }

        let semaphore = DispatchSemaphore(value: 0)
        assetWriter.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()

        guard assetWriter.status == .completed else {
            throw OpenRecError.writerFailed(
                assetWriter.error?.localizedDescription ?? "AVAssetWriter failed to finish."
            )
        }

        return outputURL
    }

    private func append(
        _ sampleBuffer: CMSampleBuffer,
        to input: AVAssetWriterInput,
        label: String
    ) throws {
        guard assetWriter.status == .writing else {
            throw OpenRecError.writerFailed("AVAssetWriter is not writing.")
        }

        guard input.isReadyForMoreMediaData else {
            throw OpenRecError.writerFailed("AVAssetWriter \(label) input is not ready.")
        }

        guard input.append(sampleBuffer) else {
            throw OpenRecError.writerFailed(
                assetWriter.error?.localizedDescription ??
                    "AVAssetWriter failed to append \(label) sample."
            )
        }
    }
}
