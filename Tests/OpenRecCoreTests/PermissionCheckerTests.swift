import Testing
import AVFoundation
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

@Test func systemPermissionProviderMapsMicrophoneAuthorizationStatus() {
    let granted = SystemPermissionStatusProvider(microphoneAuthorizationStatus: { .authorized })
    let denied = SystemPermissionStatusProvider(microphoneAuthorizationStatus: { .denied })
    let restricted = SystemPermissionStatusProvider(microphoneAuthorizationStatus: { .restricted })
    let notDetermined = SystemPermissionStatusProvider(microphoneAuthorizationStatus: { .notDetermined })

    #expect(granted.status(for: .microphone) == .granted)
    #expect(denied.status(for: .microphone) == .denied)
    #expect(restricted.status(for: .microphone) == .denied)
    #expect(notDetermined.status(for: .microphone) == .notDetermined)
}

@Test func systemPermissionProviderUsesConservativeStatusesForUnsupportedSystemPermissions() {
    let provider = SystemPermissionStatusProvider(microphoneAuthorizationStatus: { .authorized })

    #expect(provider.status(for: .screenRecording) == .unknown)
    #expect(provider.status(for: .accessibility) == .notDetermined)
    #expect(provider.status(for: .inputMonitoring) == .notDetermined)
}

@Test func systemPermissionProviderAllowsInjectingNonMicrophoneStatusLookups() {
    let provider = SystemPermissionStatusProvider(
        microphoneAuthorizationStatus: { .authorized },
        screenRecordingStatus: { .granted },
        accessibilityStatus: { .denied },
        inputMonitoringStatus: { .unknown }
    )

    #expect(provider.status(for: .screenRecording) == .granted)
    #expect(provider.status(for: .accessibility) == .denied)
    #expect(provider.status(for: .inputMonitoring) == .unknown)
}
