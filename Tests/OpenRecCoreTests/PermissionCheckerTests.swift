import Testing
@testable import OpenRecCore

@Test func permissionCheckerReturnsInjectedStatusesForAllPermissionKinds() {
    let provider = InMemoryPermissionStatusProvider(statuses: [
        .screenRecording: .granted,
        .microphone: .denied,
        .accessibility: .notDetermined,
        .inputMonitoring: .unknown
    ])
    let checker = PermissionChecker(provider: provider)

    #expect(checker.status(for: .screenRecording) == .granted)
    #expect(checker.status(for: .microphone) == .denied)
    #expect(checker.status(for: .accessibility) == .notDetermined)
    #expect(checker.status(for: .inputMonitoring) == .unknown)
}

@Test func permissionCheckerReportsDeniedPermissionWhenRequiredPermissionIsMissing() {
    let provider = InMemoryPermissionStatusProvider(statuses: [
        .screenRecording: .granted,
        .microphone: .denied
    ])
    let checker = PermissionChecker(provider: provider)

    #expect(throws: OpenRecError.permissionDenied(.microphone)) {
        try checker.requireGranted([.screenRecording, .microphone])
    }
}
