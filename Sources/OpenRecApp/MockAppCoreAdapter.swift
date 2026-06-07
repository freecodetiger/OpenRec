import Foundation
import OpenRecCore

final class MockAppCoreAdapter: AppShellAdapter {
    private(set) var snapshot: AppShellSnapshot
    private(set) var saveRecordingCallCount = 0
    private(set) var retrySaveCallCount = 0
    private(set) var discardRecordingCallCount = 0

    init(initialSnapshot: AppShellSnapshot = .ready) {
        self.snapshot = initialSnapshot
    }

    func refresh() async -> AppShellSnapshot {
        snapshot
    }

    func startRecording() -> AppShellSnapshot {
        guard snapshot.status == .ready else { return snapshot }
        snapshot.status = .recording
        snapshot.elapsedTimeText = "00:00"
        snapshot.errorMessage = nil
        return snapshot
    }

    func stopRecording() -> AppShellSnapshot {
        guard snapshot.status == .recording else { return snapshot }
        snapshot.status = .ready
        snapshot.elapsedTimeText = nil
        return snapshot
    }

    func selectMode(_ mode: CaptureMode) -> AppShellSnapshot {
        snapshot.mode = mode
        if let target = snapshot.availableTargets.first(where: { $0.mode == mode }) {
            snapshot.selectedTarget = target
        }
        return snapshot
    }

    func selectTarget(id: String) -> AppShellSnapshot {
        if let target = snapshot.availableTargets.first(where: { $0.id == id }) {
            snapshot.selectedTarget = target
            snapshot.mode = target.mode
        }
        return snapshot
    }

    func selectMicrophone(id: String) -> AppShellSnapshot {
        if snapshot.microphones.contains(where: { $0.id == id }) {
            snapshot.selectedMicrophoneID = id
        }
        return snapshot
    }

    func saveRecording() -> AppShellSnapshot {
        guard snapshot.status == .awaitingSave else { return snapshot }
        saveRecordingCallCount += 1
        snapshot.status = .ready
        snapshot.errorMessage = nil
        snapshot.pendingSaveURL = nil
        return snapshot
    }

    func retrySave() -> AppShellSnapshot {
        guard snapshot.status == .awaitingSave else { return snapshot }
        retrySaveCallCount += 1
        snapshot.errorMessage = "Choose a save location or discard the recording."
        return snapshot
    }

    func discardRecording() -> AppShellSnapshot {
        guard snapshot.status == .awaitingSave else { return snapshot }
        discardRecordingCallCount += 1
        snapshot.status = .ready
        snapshot.errorMessage = nil
        snapshot.pendingSaveURL = nil
        return snapshot
    }

    func selectScenario(_ snapshot: AppShellSnapshot) -> AppShellSnapshot {
        self.snapshot = snapshot
        return snapshot
    }
}
