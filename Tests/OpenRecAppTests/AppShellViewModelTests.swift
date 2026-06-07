import Testing
@testable import OpenRecApp
import OpenRecCore

@Test func mockScenariosCoverRequiredMenuStates() {
    let scenarios = AppShellSnapshot.mockScenarios

    #expect(scenarios.map(\.status).contains(.ready))
    #expect(scenarios.map(\.status).contains(.recording))
    #expect(scenarios.map(\.status).contains(.permissionRequired))
    #expect(scenarios.map(\.status).contains(.error))
}

@Test func primaryActionReflectsRecordingStatus() {
    let adapter = MockAppCoreAdapter(initialSnapshot: .recording)
    let viewModel = AppShellViewModel(adapter: adapter)

    #expect(viewModel.primaryActionTitle == "Stop Recording")

    viewModel.stopRecording()

    #expect(viewModel.snapshot.status == .ready)
    #expect(viewModel.primaryActionTitle == "Start Recording")
}

@Test func startRecordingRequiresPermissionsBeforeRecording() {
    let adapter = MockAppCoreAdapter(initialSnapshot: .permissionRequired)
    let viewModel = AppShellViewModel(adapter: adapter)

    viewModel.startRecording()

    #expect(viewModel.snapshot.status == .permissionRequired)
    #expect(viewModel.canStartRecording == false)
}

@Test func sourceSummaryUsesCoreCaptureSource() {
    let snapshot = AppShellSnapshot.ready

    #expect(snapshot.selectedTarget.source == .display(DisplayID(rawValue: 1)))
    #expect(snapshot.selectedTarget.summary == "Built-in Display")
}
