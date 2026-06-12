import Foundation

public enum AudioInputLevelState: String, Codable, Equatable, Sendable {
    case inactive
    case noInput
    case low
    case normal
    case high
    case clippingRisk
}

public struct AudioLevelSnapshot: Codable, Equatable, Sendable {
    public var rmsDBFS: Double
    public var peakDBFS: Double
    public var normalizedLevel: Double
    public var state: AudioInputLevelState

    public init(
        rmsDBFS: Double,
        peakDBFS: Double,
        normalizedLevel: Double,
        state: AudioInputLevelState
    ) {
        self.rmsDBFS = rmsDBFS
        self.peakDBFS = peakDBFS
        self.normalizedLevel = normalizedLevel
        self.state = state
    }

    public static let inactive = AudioLevelSnapshot(
        rmsDBFS: -80,
        peakDBFS: -80,
        normalizedLevel: 0,
        state: .inactive
    )
}

public enum AudioLevelMeter {
    public static let floorDBFS: Double = -80
    public static let ceilingDBFS: Double = 0

    public static func measure(samples: [Float]) -> AudioLevelSnapshot {
        guard !samples.isEmpty else {
            return .inactive
        }

        var sumOfSquares: Double = 0
        var peak: Double = 0
        for sample in samples {
            guard sample.isFinite else { continue }
            let amplitude = min(1, abs(Double(sample)))
            sumOfSquares += amplitude * amplitude
            peak = max(peak, amplitude)
        }

        let rms = sqrt(sumOfSquares / Double(samples.count))
        let rmsDBFS = decibels(forAmplitude: rms)
        let peakDBFS = decibels(forAmplitude: peak)
        return AudioLevelSnapshot(
            rmsDBFS: rmsDBFS,
            peakDBFS: peakDBFS,
            normalizedLevel: normalizedLevel(for: rmsDBFS),
            state: state(rmsDBFS: rmsDBFS, peakDBFS: peakDBFS)
        )
    }

    private static func decibels(forAmplitude amplitude: Double) -> Double {
        guard amplitude > 0 else { return floorDBFS }
        return max(floorDBFS, min(ceilingDBFS, 20 * log10(amplitude)))
    }

    private static func normalizedLevel(for dbfs: Double) -> Double {
        let clamped = max(floorDBFS, min(ceilingDBFS, dbfs))
        return (clamped - floorDBFS) / abs(floorDBFS)
    }

    private static func state(rmsDBFS: Double, peakDBFS: Double) -> AudioInputLevelState {
        if peakDBFS >= -1 {
            return .clippingRisk
        }
        if rmsDBFS <= -60 {
            return .noInput
        }
        if rmsDBFS < -35 {
            return .low
        }
        if rmsDBFS > -6 {
            return .high
        }
        return .normal
    }
}

public final class AudioLevelMonitor: @unchecked Sendable {
    private let lock = NSLock()
    private var storedSnapshot: AudioLevelSnapshot

    public init(snapshot: AudioLevelSnapshot = .inactive) {
        self.storedSnapshot = snapshot
    }

    public var snapshot: AudioLevelSnapshot {
        lock.withLock { storedSnapshot }
    }

    public func update(_ snapshot: AudioLevelSnapshot) {
        lock.withLock {
            storedSnapshot = snapshot
        }
    }

    public func reset() {
        update(.inactive)
    }
}
