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
    func refreshPermissions() -> AppShellSnapshot
    func saveRecording() -> AppShellSnapshot
    func retrySave() -> AppShellSnapshot
    func discardRecording() -> AppShellSnapshot
    func selectScenario(_ snapshot: AppShellSnapshot) -> AppShellSnapshot
}

@MainActor
final class AppShellViewModel: ObservableObject {
    @Published private(set) var snapshot: AppShellSnapshot

    private let adapter: AppShellAdapter

    init(adapter: AppShellAdapter) {
        self.adapter = adapter
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

    @MainActor
    func refresh() async {
        snapshot = await adapter.refresh()
    }

    func startRecording() {
        guard canStartRecording else { return }
        snapshot = adapter.startRecording()
    }

    func stopRecording() {
        guard isRecording else { return }
        snapshot = adapter.stopRecording()
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
        snapshot = adapter.selectMode(mode)
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

    func openPermissionSettings(for kind: PermissionKind) {
        snapshot = adapter.openPermissionSettings(for: kind)
    }

    func refreshPermissions() {
        snapshot = adapter.refreshPermissions()
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
}
