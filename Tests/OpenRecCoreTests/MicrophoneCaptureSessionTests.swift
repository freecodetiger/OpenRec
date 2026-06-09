import AVFoundation
import Testing
@testable import OpenRecCore

@Test func avFoundationMicrophoneCaptureOutputSettingsRequestsLinearPCMWithoutUnsupportedFormatClaims() {
    let settings = AVFoundationMicrophoneCaptureOutputSettings()

    #expect(settings.audioSettings[AVFormatIDKey] as? AudioFormatID == kAudioFormatLinearPCM)
    #expect(settings.audioSettings[AVSampleRateKey] == nil)
    #expect(settings.audioSettings[AVNumberOfChannelsKey] == nil)
}
