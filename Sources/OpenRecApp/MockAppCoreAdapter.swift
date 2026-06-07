import Foundation
import OpenRecCore

final class MockAppCoreAdapter: AppShellAdapter {
    private(set) var snapshot: AppShellSnapshot

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

    func selectScenario(_ snapshot: AppShellSnapshot) -> AppShellSnapshot {
        self.snapshot = snapshot
        return snapshot
    }
}
