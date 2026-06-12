import Testing
@testable import OpenRecCore

@Test func audioLevelPreviewSessionActivityDeactivatesStoppedPreviewSessions() {
    let activity = AudioLevelPreviewSessionActivity()

    #expect(activity.isActive)

    activity.deactivate()

    #expect(activity.isActive == false)
}
