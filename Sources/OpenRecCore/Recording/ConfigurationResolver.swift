import Foundation

public enum ConfigurationResolver {
    public static func resolve(
        source: CaptureSource,
        metadata: CaptureSourceMetadata,
        settings: RecordingSettings
    ) throws -> ResolvedRecordingConfiguration {
        guard metadata.source == source else {
            throw OpenRecError.captureConfigurationInvalid(
                "Capture source metadata does not match the selected source."
            )
        }

        guard metadata.isAvailable else {
            throw OpenRecError.captureSourceUnavailable(source)
        }

        guard Self.isValidPixelSize(metadata.pixelSize) else {
            throw OpenRecError.captureConfigurationInvalid(
                "Capture source metadata has invalid pixel size."
            )
        }

        return ResolvedRecordingConfiguration(
            source: source,
            pixelSize: metadata.pixelSize,
            outputFormat: settings.outputFormat,
            videoCodec: settings.videoCodec,
            bitrate: Self.bitrate(
                pixelSize: metadata.pixelSize,
                frameRate: settings.frameRate,
                qualityPreset: settings.qualityPreset,
                codec: settings.videoCodec
            ),
            frameRate: settings.frameRate.rawValue,
            includeCursor: settings.includeCursor,
            microphoneDeviceID: settings.microphoneDeviceID
        )
    }

    private static func isValidPixelSize(_ pixelSize: CGSize) -> Bool {
        pixelSize.width.isFinite &&
            pixelSize.height.isFinite &&
            pixelSize.width > 0 &&
            pixelSize.height > 0
    }

    private static func bitrate(
        pixelSize: CGSize,
        frameRate: FrameRatePreset,
        qualityPreset: QualityPreset,
        codec: VideoCodec
    ) -> Int {
        let qualityMultiplier: Double = switch qualityPreset {
        case .compact:
            0.08
        case .standard:
            0.12
        case .high:
            0.18
        }

        let codecMultiplier: Double = switch codec {
        case .h264:
            1.0
        case .hevc:
            0.65
        }

        let pixels = pixelSize.width * pixelSize.height
        let bitrate = pixels *
            Double(frameRate.rawValue) *
            qualityMultiplier *
            codecMultiplier

        return max(1, Int(bitrate.rounded()))
    }
}
