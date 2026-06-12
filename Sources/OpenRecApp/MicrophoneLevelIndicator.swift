import SwiftUI
import OpenRecCore

struct MicrophoneLevelPresentation: Equatable {
    var microphoneName: String
    var statusText: String
    var rmsText: String
    var peakText: String
    var levelFraction: Double
    var tone: MicrophoneLevelTone
    var symbolName: String
    var detailText: String

    var primaryText: String { microphoneName }
    var stateText: String { statusText }
    var normalizedLevel: Double { levelFraction }
    var tint: MicrophoneLevelTone { tone }

    static func make(
        snapshot: AppShellSnapshot,
        strings: OpenRecLocalization
    ) -> MicrophoneLevelPresentation {
        var presentation = make(
            microphoneName: snapshot.selectedMicrophone.title,
            snapshot: snapshot.audioLevel,
            strings: MicrophoneLevelPresentationStrings(strings)
        )
        if snapshot.audioLevel.state == .inactive {
            presentation.detailText = strings.microphoneLevelAwaitingRecording
        }
        return presentation
    }

    static func make(
        microphoneName: String,
        snapshot: AudioLevelSnapshot,
        strings: MicrophoneLevelPresentationStrings
    ) -> MicrophoneLevelPresentation {
        let tone = MicrophoneLevelTone(snapshot.state)
        let rmsText = strings.dbfsText(label: strings.rmsLabel, value: snapshot.rmsDBFS)
        let peakText = strings.dbfsText(label: strings.peakLabel, value: snapshot.peakDBFS)
        let clampedLevel = min(1, max(0, snapshot.normalizedLevel))
        return MicrophoneLevelPresentation(
            microphoneName: microphoneName,
            statusText: strings.statusText(snapshot.state),
            rmsText: rmsText,
            peakText: peakText,
            levelFraction: snapshot.state == .inactive ? 0 : clampedLevel,
            tone: tone,
            symbolName: tone.symbolName,
            detailText: snapshot.state == .inactive ? strings.statusText(snapshot.state) : "\(rmsText) · \(peakText)"
        )
    }
}

struct MicrophoneLevelPresentationStrings: Equatable {
    var inactive: String
    var noInput: String
    var low: String
    var normal: String
    var high: String
    var clippingRisk: String
    var rmsLabel: String
    var peakLabel: String

    init(
        inactive: String,
        noInput: String,
        low: String,
        normal: String,
        high: String,
        clippingRisk: String,
        rmsLabel: String,
        peakLabel: String
    ) {
        self.inactive = inactive
        self.noInput = noInput
        self.low = low
        self.normal = normal
        self.high = high
        self.clippingRisk = clippingRisk
        self.rmsLabel = rmsLabel
        self.peakLabel = peakLabel
    }

    init(_ strings: OpenRecLocalization) {
        self.init(
            inactive: strings.microphoneLevelInactive,
            noInput: strings.microphoneLevelNoInput,
            low: strings.microphoneLevelLow,
            normal: strings.microphoneLevelNormal,
            high: strings.microphoneLevelHigh,
            clippingRisk: strings.microphoneLevelClippingRisk,
            rmsLabel: strings.rmsLevelLabel,
            peakLabel: strings.peakLevelLabel
        )
    }

    func statusText(_ state: AudioInputLevelState) -> String {
        switch state {
        case .inactive:
            inactive
        case .noInput:
            noInput
        case .low:
            low
        case .normal:
            normal
        case .high:
            high
        case .clippingRisk:
            clippingRisk
        }
    }

    func dbfsText(label: String, value: Double) -> String {
        "\(label) \(String(format: "%.1f", value)) dBFS"
    }
}

enum MicrophoneLevelTone: Equatable {
    case inactive
    case low
    case normal
    case warning
    case critical

    init(_ state: AudioInputLevelState) {
        switch state {
        case .inactive, .noInput:
            self = .inactive
        case .low:
            self = .low
        case .normal:
            self = .normal
        case .high:
            self = .warning
        case .clippingRisk:
            self = .critical
        }
    }

    var symbolName: String {
        switch self {
        case .inactive:
            "mic.slash"
        case .low, .normal, .warning:
            "mic.fill"
        case .critical:
            "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .inactive:
            .secondary
        case .low:
            .orange
        case .normal:
            .green
        case .warning:
            .yellow
        case .critical:
            .red
        }
    }
}

struct MicrophoneLevelIndicator: View {
    var presentation: MicrophoneLevelPresentation
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: presentation.symbolName)
                .foregroundStyle(presentation.tone.color)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: compact ? 3 : 4) {
                HStack(spacing: 6) {
                    Text(presentation.microphoneName)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(presentation.statusText)
                        .font(.caption2)
                        .foregroundStyle(presentation.tone.color)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.secondary.opacity(0.18))
                            Capsule()
                                .fill(presentation.tone.color)
                                .frame(width: proxy.size.width * presentation.levelFraction)
                        }
                    }
                    .frame(height: 5)

                    Text(compact ? presentation.rmsText : presentation.detailText)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(presentation.microphoneName), \(presentation.statusText), \(presentation.detailText)")
    }
}
