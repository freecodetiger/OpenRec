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
        self.audioBitrate = Self.audioBitrate(for: configuration.audioPreset)
    }

    public static func audioBitrate(for preset: AudioPreset) -> Int {
        switch preset {
        case .standard:
            128_000
        case .high:
            256_000
        }
    }

    public var videoOutputSettings: [String: Any] {
        [
            AVVideoCodecKey: videoCodec,
            AVVideoWidthKey: videoWidth,
            AVVideoHeightKey: videoHeight,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ],
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
    private let writerQueue = DispatchQueue(label: "openrec.avasset-recording-output-writer")
    private var didStartSession = false

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
        try writerQueue.sync {
            guard assetWriter.startWriting() else {
                throw OpenRecError.writerInitializationFailed(
                    assetWriter.error?.localizedDescription ?? "AVAssetWriter failed to start."
                )
            }
        }
    }

    public func appendVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) throws {
        try writerQueue.sync {
            try appendVideo(sampleBuffer)
        }
    }

    public func appendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) throws {
        try writerQueue.sync {
            try appendAudio(sampleBuffer)
        }
    }

    public func finish() throws -> URL {
        try writerQueue.sync {
            guard didStartSession else {
                throw OpenRecError.writerFailed("No video frames were captured.")
            }

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
    }

    private func appendVideo(_ sampleBuffer: CMSampleBuffer) throws {
        guard assetWriter.status == .writing else {
            throw OpenRecError.writerFailed("AVAssetWriter is not writing.")
        }

        guard videoInput.isReadyForMoreMediaData else {
            throw OpenRecError.writerFailed("AVAssetWriter video input is not ready.")
        }

        if !didStartSession {
            assetWriter.startSession(atSourceTime: sampleBuffer.presentationTimeStamp)
            didStartSession = true
        }

        guard videoInput.append(sampleBuffer) else {
            throw OpenRecError.writerFailed(
                assetWriter.error?.localizedDescription ??
                    "AVAssetWriter failed to append video sample."
            )
        }
    }

    private func appendAudio(_ sampleBuffer: CMSampleBuffer) throws {
        guard assetWriter.status == .writing else {
            throw OpenRecError.writerFailed("AVAssetWriter is not writing.")
        }

        guard didStartSession else {
            return
        }

        guard audioInput.isReadyForMoreMediaData else {
            throw OpenRecError.writerFailed("AVAssetWriter audio input is not ready.")
        }

        guard audioInput.append(sampleBuffer) else {
            throw OpenRecError.writerFailed(
                assetWriter.error?.localizedDescription ??
                    "AVAssetWriter failed to append audio sample."
            )
        }
    }
}
