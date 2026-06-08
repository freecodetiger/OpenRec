import Foundation
import OpenRecCore

@MainActor
protocol AppShellAdapter: AnyObject {
    var snapshot: AppShellSnapshot { get }
    var onHotkeyTriggered: (@MainActor @Sendable () -> Void)? { get set }

    func refresh() async -> AppShellSnapshot
    func registerSavedHotkey() -> AppShellSnapshot
    func startRecording() -> AppShellSnapshot
    func stopRecording() -> AppShellSnapshot
    func selectMode(_ mode: CaptureMode) -> AppShellSnapshot
    func selectTarget(id: String) -> AppShellSnapshot
    func selectMicrophone(id: String) -> AppShellSnapshot
    func updateSettings(_ settings: RecordingSettings) -> AppShellSnapshot
    func openPermissionSettings(for kind: PermissionKind) -> AppShellSnapshot
    func requestPermission(for kind: PermissionKind) async -> AppShellSnapshot
    func reopenApplication()
    func refreshPermissions() -> AppShellSnapshot
    func saveRecording() -> AppShellSnapshot
    func retrySave() -> AppShellSnapshot
    func discardRecording() -> AppShellSnapshot
    func selectScenario(_ snapshot: AppShellSnapshot) -> AppShellSnapshot
}

@MainActor
final class AppShellViewModel: ObservableObject {
    @Published private(set) var snapshot: AppShellSnapshot
    @Published private(set) var windowRecordingWorkflow: WindowRecordingWorkflowState = .idle

    private let adapter: AppShellAdapter
    private let now: () -> Date
    private var recordingStartedAt: Date?

    init(adapter: AppShellAdapter, now: @escaping () -> Date = Date.init) {
        self.adapter = adapter
        self.now = now
        self.snapshot = adapter.snapshot
        self.adapter.onHotkeyTriggered = { [weak self] in
            self?.toggleRecording()
        }
    }

    var canStartRecording: Bool {
        snapshot.status == .ready
    }

    var canSaveRecording: Bool {
        snapshot.status == .awaitingSave
    }

    var canRetrySave: Bool {
        snapshot.status == .awaitingSave
    }

    var canDiscardRecording: Bool {
        snapshot.status == .awaitingSave
    }

    var isRecording: Bool {
        snapshot.status == .recording
    }

    var primaryActionTitle: String {
        isRecording ? "Stop Recording" : "Start Recording"
    }

    var menuBarSymbolName: String {
        switch snapshot.status {
        case .ready:
            "record.circle"
        case .recording:
            "stop.circle.fill"
        case .awaitingSave:
            "square.and.arrow.down.fill"
        case .permissionRequired:
            "exclamationmark.triangle.fill"
        case .error:
            "xmark.octagon.fill"
        }
    }

    var visibleTargets: [SourceTargetOption] {
        snapshot.availableTargets.filter { $0.mode == snapshot.mode }
    }

    var applicationTargets: [ApplicationTargetOption] {
        let windows = snapshot.availableTargets.filter { $0.mode == .window }
        let grouped = Dictionary(grouping: windows, by: \.applicationName)

        return grouped
            .map { applicationName, windows in
                ApplicationTargetOption(
                    id: applicationName,
                    title: applicationName,
                    windows: windows.sorted { $0.title < $1.title }
                )
            }
            .sorted { $0.title < $1.title }
    }

    @MainActor
    func refresh() async {
        snapshot = await adapter.refresh()
    }

    func startRecording() {
        guard canStartRecording else { return }
        snapshot = adapter.startRecording()
        if snapshot.status == .recording {
            recordingStartedAt = now()
            refreshElapsedTime()
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        snapshot = adapter.stopRecording()
        recordingStartedAt = nil
        if snapshot.status == .awaitingSave {
            snapshot = adapter.saveRecording()
        }
    }

    func refreshElapsedTime() {
        guard snapshot.status == .recording, let recordingStartedAt else { return }
        let elapsedSeconds = max(0, Int(now().timeIntervalSince(recordingStartedAt)))
        snapshot.elapsedTimeText = Self.formatElapsedTime(seconds: elapsedSeconds)
    }

    func toggleRecording() {
        switch snapshot.status {
        case .ready:
            startRecording()
        case .recording:
            stopRecording()
        case .awaitingSave, .permissionRequired, .error:
            return
        }
    }

    func startHotkeyMonitoring() {
        snapshot = adapter.registerSavedHotkey()
    }

    func selectMode(_ mode: CaptureMode) {
        guard mode != snapshot.mode else { return }
        windowRecordingWorkflow = .idle
        snapshot = adapter.selectMode(mode)
    }

    func requestWindowRecordingWorkflow() -> Bool {
        guard snapshot.status == .ready else { return false }
        windowRecordingWorkflow = .selectingWindow(
            previousMode: snapshot.mode,
            previousTargetID: snapshot.selectedTarget.id
        )
        return true
    }

    func requestApplicationRecordingWorkflow() -> Bool {
        guard snapshot.status == .ready else { return false }
        windowRecordingWorkflow = .selectingApplication(
            previousMode: snapshot.mode,
            previousTargetID: snapshot.selectedTarget.id
        )
        return true
    }

    func selectApplicationForRecording(applicationName: String) {
        guard case let .selectingApplication(previousMode, previousTargetID) = windowRecordingWorkflow,
              applicationTargets.contains(where: { $0.id == applicationName }) else {
            return
        }

        windowRecordingWorkflow = .selectingApplicationWindow(
            previousMode: previousMode,
            previousTargetID: previousTargetID,
            applicationName: applicationName
        )
    }

    func selectWindowForRecording(targetID: String) {
        let previousSelection: (mode: CaptureMode, targetID: String)
        let allowedTargetIDs: Set<String>?

        switch windowRecordingWorkflow {
        case let .selectingWindow(previousMode, previousTargetID):
            previousSelection = (previousMode, previousTargetID)
            allowedTargetIDs = nil
        case let .selectingApplicationWindow(previousMode, previousTargetID, applicationName):
            previousSelection = (previousMode, previousTargetID)
            allowedTargetIDs = Set(
                applicationTargets.first(where: { $0.id == applicationName })?.windows.map(\.id) ?? []
            )
        case .idle, .selectingApplication, .configuringWindow:
            return
        }

        guard let target = snapshot.availableTargets.first(where: { $0.id == targetID && $0.mode == .window }),
              allowedTargetIDs?.contains(target.id) ?? true else {
            return
        }

        if snapshot.mode != .window {
            snapshot = adapter.selectMode(.window)
        }
        snapshot = adapter.selectTarget(id: target.id)
        windowRecordingWorkflow = .configuringWindow(
            previousMode: previousSelection.mode,
            previousTargetID: previousSelection.targetID,
            selectedTargetID: target.id
        )
    }

    func cancelWindowRecordingWorkflow() {
        let previousSelection: (mode: CaptureMode, targetID: String)?
        switch windowRecordingWorkflow {
        case .idle:
            previousSelection = nil
        case let .selectingWindow(previousMode, previousTargetID),
             let .selectingApplication(previousMode, previousTargetID),
             let .selectingApplicationWindow(previousMode, previousTargetID, _),
             let .configuringWindow(previousMode, previousTargetID, _):
            previousSelection = (previousMode, previousTargetID)
        }

        windowRecordingWorkflow = .idle
        guard let previousSelection else { return }

        if snapshot.mode != previousSelection.mode {
            snapshot = adapter.selectMode(previousSelection.mode)
        }
        if snapshot.selectedTarget.id != previousSelection.targetID {
            snapshot = adapter.selectTarget(id: previousSelection.targetID)
        }
    }

    func startConfiguredWindowRecording() {
        guard case .configuringWindow = windowRecordingWorkflow else { return }
        windowRecordingWorkflow = .idle
        startRecording()
    }

    func selectTarget(id: String) {
        guard id != snapshot.selectedTarget.id else { return }
        snapshot = adapter.selectTarget(id: id)
    }

    func applySourceSelection(_ draft: SourceSelectionDraft) {
        guard draft.canApply else { return }

        let shouldSelectMode = draft.mode != snapshot.mode
        let shouldSelectTarget = shouldSelectMode || draft.selectedTargetID != snapshot.selectedTarget.id

        if shouldSelectMode {
            snapshot = adapter.selectMode(draft.mode)
        }
        if shouldSelectTarget {
            snapshot = adapter.selectTarget(id: draft.selectedTargetID)
        }
    }

    func selectMicrophone(id: String) {
        guard id != snapshot.selectedMicrophoneID else { return }
        snapshot = adapter.selectMicrophone(id: id)
    }

    func updateSettings(_ settings: RecordingSettings) {
        guard settings != snapshot.settings else { return }
        snapshot = adapter.updateSettings(settings)
    }

    func updateWindowControlBarSettings(_ settings: RecordingSettings) {
        let configuredTargetID: String?
        if case let .configuringWindow(_, _, selectedTargetID) = windowRecordingWorkflow {
            configuredTargetID = selectedTargetID
        } else {
            configuredTargetID = nil
        }

        updateSettings(settings)
        guard let configuredTargetID,
              snapshot.selectedTarget.id != configuredTargetID,
              snapshot.availableTargets.contains(where: { $0.id == configuredTargetID }) else {
            return
        }
        snapshot = adapter.selectTarget(id: configuredTargetID)
    }

    func openPermissionSettings(for kind: PermissionKind) {
        snapshot = adapter.openPermissionSettings(for: kind)
    }

    func requestPermission(for kind: PermissionKind) {
        Task {
            snapshot = await adapter.requestPermission(for: kind)
        }
    }

    func reopenApplication() {
        adapter.reopenApplication()
    }

    func refreshPermissions() {
        Task {
            snapshot = await adapter.refresh()
        }
    }

    func saveRecording() {
        guard canSaveRecording else { return }
        snapshot = adapter.saveRecording()
    }

    func retrySave() {
        guard canRetrySave else { return }
        snapshot = adapter.retrySave()
    }

    func discardRecording() {
        guard canDiscardRecording else { return }
        snapshot = adapter.discardRecording()
    }

    func selectScenario(_ scenario: AppShellSnapshot) {
        snapshot = adapter.selectScenario(scenario)
    }

    private static func formatElapsedTime(seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
