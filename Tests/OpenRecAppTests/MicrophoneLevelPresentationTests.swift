import Testing
@testable import OpenRecApp
import OpenRecCore

@Test func microphoneLevelPresentationFormatsActiveInputReadout() {
    let snapshot = AudioLevelSnapshot(
        rmsDBFS: -18.42,
        peakDBFS: -5.96,
        normalizedLevel: 0.77,
        state: .normal
    )

    let presentation = MicrophoneLevelPresentation.make(
        microphoneName: "Studio Microphone",
        snapshot: snapshot,
        strings: .testEnglish
    )

    #expect(presentation.microphoneName == "Studio Microphone")
    #expect(presentation.statusText == "Input normal")
    #expect(presentation.rmsText == "RMS -18.4 dBFS")
    #expect(presentation.peakText == "Peak -6.0 dBFS")
    #expect(presentation.detailText == "RMS -18.4 dBFS · Peak -6.0 dBFS")
    #expect(presentation.levelFraction == 0.77)
    #expect(presentation.tone == .normal)
    #expect(presentation.symbolName == "mic.fill")
}

@Test func microphoneLevelPresentationClampsMeterFractionAndFlagsClippingRisk() {
    let snapshot = AudioLevelSnapshot(
        rmsDBFS: -2.1,
        peakDBFS: 0.2,
        normalizedLevel: 1.4,
        state: .clippingRisk
    )

    let presentation = MicrophoneLevelPresentation.make(
        microphoneName: "USB Mic",
        snapshot: snapshot,
        strings: .testEnglish
    )

    #expect(presentation.statusText == "Clipping risk")
    #expect(presentation.levelFraction == 1)
    #expect(presentation.tone == .critical)
    #expect(presentation.symbolName == "exclamationmark.triangle.fill")
}

@Test func microphoneLevelPresentationAcceptsChineseStringsWithoutLocalizationDependency() {
    let snapshot = AudioLevelSnapshot(
        rmsDBFS: -52.0,
        peakDBFS: -41.2,
        normalizedLevel: 0.35,
        state: .low
    )

    let presentation = MicrophoneLevelPresentation.make(
        microphoneName: "系统默认麦克风",
        snapshot: snapshot,
        strings: .testChinese
    )

    #expect(presentation.microphoneName == "系统默认麦克风")
    #expect(presentation.statusText == "输入偏低")
    #expect(presentation.rmsText == "RMS -52.0 dBFS")
    #expect(presentation.peakText == "Peak -41.2 dBFS")
    #expect(presentation.tone == .low)
}

@Test func microphoneLevelPresentationTreatsInactiveInputAsMutedMeter() {
    let presentation = MicrophoneLevelPresentation.make(
        microphoneName: "MacBook Pro Microphone",
        snapshot: .inactive,
        strings: .testEnglish
    )

    #expect(presentation.statusText == "Inactive")
    #expect(presentation.levelFraction == 0)
    #expect(presentation.tone == .inactive)
    #expect(presentation.symbolName == "mic.slash")
}

private extension MicrophoneLevelPresentationStrings {
    static let testEnglish = MicrophoneLevelPresentationStrings(
        inactive: "Inactive",
        noInput: "No input",
        low: "Input low",
        normal: "Input normal",
        high: "Input high",
        clippingRisk: "Clipping risk",
        rmsLabel: "RMS",
        peakLabel: "Peak"
    )

    static let testChinese = MicrophoneLevelPresentationStrings(
        inactive: "未启用",
        noInput: "无输入",
        low: "输入偏低",
        normal: "输入正常",
        high: "输入偏高",
        clippingRisk: "削波风险",
        rmsLabel: "RMS",
        peakLabel: "Peak"
    )
}
