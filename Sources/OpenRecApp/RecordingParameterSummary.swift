import Foundation
import OpenRecCore

struct RecordingParameterSummary: Equatable {
    var bitrateText: String
    var videoDetailText: String
    var audioDetailText: String

    static func make(
        target: SourceTargetOption,
        settings: RecordingSettings,
        strings: OpenRecLocalization
    ) -> RecordingParameterSummary {
        let pixelSize = target.sourcePixelSize
        let bitrate = ConfigurationResolver.videoBitrate(
            pixelSize: pixelSize,
            frameRate: settings.frameRate,
            qualityPreset: settings.qualityPreset,
            codec: settings.videoCodec
        )
        let audioBitrate = RecordingOutputWriterSettings.audioBitrate(for: settings.audioPreset)

        return RecordingParameterSummary(
            bitrateText: strings.videoBitrateValue(bitrate),
            videoDetailText: strings.videoParameterDetail(
                resolution: Self.resolutionText(pixelSize),
                frameRate: settings.frameRate.label,
                codec: settings.videoCodec.label,
                format: settings.outputFormat.label
            ),
            audioDetailText: strings.audioParameterDetail(
                codec: "AAC-LC",
                sampleRate: "48 kHz",
                channels: "2 ch",
                bitrate: strings.audioBitrateValue(audioBitrate),
                preset: strings.audioPresetLabel(settings.audioPreset)
            )
        )
    }

    private static func resolutionText(_ pixelSize: CGSize) -> String {
        "\(Int(pixelSize.width.rounded())) x \(Int(pixelSize.height.rounded()))"
    }
}

private extension SourceTargetOption {
    var sourcePixelSize: CGSize {
        let components = subtitle.split(separator: ",", maxSplits: 1)
        guard let resolution = components.first else {
            return screenFrame?.size ?? CGSize(width: 1, height: 1)
        }

        let values = resolution
            .replacingOccurrences(of: "×", with: "x")
            .split(separator: "x", maxSplits: 1)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard values.count == 2,
              let width = Double(values[0]),
              let height = Double(values[1]),
              width > 0,
              height > 0 else {
            return screenFrame?.size ?? CGSize(width: 1, height: 1)
        }

        return CGSize(width: width, height: height)
    }
}
