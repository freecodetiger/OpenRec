import Testing
@testable import OpenRecCore

@Test func audioLevelMeterReportsSilenceAsNoInput() {
    let snapshot = AudioLevelMeter.measure(samples: Array(repeating: Float(0), count: 128))

    #expect(snapshot.rmsDBFS == -80)
    #expect(snapshot.peakDBFS == -80)
    #expect(snapshot.state == .noInput)
    #expect(snapshot.normalizedLevel == 0)
}

@Test func audioLevelMeterMapsNormalSpeechRange() {
    let samples = Array(repeating: Float(0.1), count: 128)

    let snapshot = AudioLevelMeter.measure(samples: samples)

    #expect(snapshot.rmsDBFS > -21)
    #expect(snapshot.rmsDBFS < -19)
    #expect(snapshot.peakDBFS > -21)
    #expect(snapshot.peakDBFS < -19)
    #expect(snapshot.state == .normal)
    #expect(snapshot.normalizedLevel > 0)
}

@Test func audioLevelMeterFlagsLowAndClippingRiskRanges() {
    let low = AudioLevelMeter.measure(samples: Array(repeating: Float(0.01), count: 128))
    let clippingRisk = AudioLevelMeter.measure(samples: Array(repeating: Float(0.95), count: 128))

    #expect(low.state == .low)
    #expect(clippingRisk.state == .clippingRisk)
    #expect(clippingRisk.normalizedLevel > low.normalizedLevel)
}

@Test func audioLevelMeterKeepsPeakSeparateFromRMS() {
    var samples = Array(repeating: Float(0.01), count: 128)
    samples[0] = 1

    let snapshot = AudioLevelMeter.measure(samples: samples)

    #expect(snapshot.peakDBFS == 0)
    #expect(snapshot.rmsDBFS < -20)
    #expect(snapshot.state == .clippingRisk)
}
