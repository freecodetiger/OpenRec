import Foundation
import OpenRecCore

final class MockAppCoreAdapter: AppShellAdapter {
    private(set) var snapshot: AppShellSnapshot
    var onHotkeyTriggered: (@MainActor @Sendable () -> Void)?

    private(set) var startRecordingCallCount = 0
    private(set) var stopRecordingCallCount = 0
    private(set) var saveRecordingCallCount = 0
    private(set) var discardRecordingCallCount = 0
    private(set) var refreshCallCount = 0
    private(set) var refreshPermissionsCallCount = 0
    private(set) var selectModes: [CaptureMode] = []
    private(set) var selectTargetIDs: [String] = []
    private(set) var updatedSettings: [RecordingSettings] = []
    private(set) var updatedLanguages: [AppLanguage] = []
    private(set) var openedPermissionSettings: [PermissionKind] = []
    private(set) var requestedPermissions: [PermissionKind] = []
    private(set) var reopenApplicationCallCount = 0
    var permissionRefreshSnapshot: AppShellSnapshot?
    var stopRecordingSnapshot: AppShellSnapshot?
    var onSaveRecording: (() -> Void)?
    private let hotkeyManager: HotkeyManager?

    init(initialSnapshot: AppShellSnapshot = .ready, hotkeyManager: HotkeyManager? = nil) {
        self.snapshot = initialSnapshot
        self.hotkeyManager = hotkeyManager
        self.hotkeyManager?.onHotkeyTriggered = { [weak self] _ in
            Task { @MainActor in
                self?.onHotkeyTriggered?()
            }
        }
    }

    func refresh() async -> AppShellSnapshot {
        refreshCallCount += 1
        if let permissionRefreshSnapshot {
            snapshot = permissionRefreshSnapshot
        }
        return snapshot
    }

    func registerSavedHotkey() -> AppShellSnapshot {
        do {
            try hotkeyManager?.registerSavedHotkey()
        } catch {
            hotkeyManager?.clearSavedHotkey()
            snapshot = snapshot.withHotkeyRegistrationFailure()
        }
        return snapshot
    }

    func startRecording() -> AppShellSnapshot {
        guard snapshot.status == .ready else { return snapshot }
        startRecordingCallCount += 1
        snapshot.status = .recording
        snapshot.elapsedTimeText = "00:00"
        snapshot.errorMessage = nil
        return snapshot
    }

    func stopRecording() -> AppShellSnapshot {
        guard snapshot.status == .recording else { return snapshot }
        stopRecordingCallCount += 1
        if let stopRecordingSnapshot {
            snapshot = stopRecordingSnapshot
            return snapshot
        }
        snapshot.status = .ready
        snapshot.elapsedTimeText = nil
        return snapshot
    }

    func selectMode(_ mode: CaptureMode) -> AppShellSnapshot {
        selectModes.append(mode)
        snapshot.mode = mode
        if let target = snapshot.availableTargets.first(where: { $0.mode == mode }) {
            snapshot.selectedTarget = target
        }
        return snapshot
    }

    func selectTarget(id: String) -> AppShellSnapshot {
        selectTargetIDs.append(id)
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

    func updateSettings(_ settings: RecordingSettings) -> AppShellSnapshot {
        updatedSettings.append(settings)
        snapshot.settings = settings
        snapshot.mode = .display
        if let target = snapshot.availableTargets.first(where: { $0.mode == .display }) {
            snapshot.selectedTarget = target
        }
        if let microphoneDeviceID = settings.microphoneDeviceID,
           let microphone = snapshot.microphones.first(where: { $0.deviceID == microphoneDeviceID }) {
            snapshot.selectedMicrophoneID = microphone.id
        }
        return snapshot
    }

    func updateAppLanguage(_ language: AppLanguage) -> AppShellSnapshot {
        updatedLanguages.append(language)
        snapshot.appLanguage = language
        return snapshot
    }

    func openPermissionSettings(for kind: PermissionKind) -> AppShellSnapshot {
        openedPermissionSettings.append(kind)
        return snapshot
    }

    func requestPermission(for kind: PermissionKind) async -> AppShellSnapshot {
        requestedPermissions.append(kind)
        return await refresh()
    }

    func reopenApplication() {
        reopenApplicationCallCount += 1
    }

    func refreshPermissions() -> AppShellSnapshot {
        refreshPermissionsCallCount += 1
        if let permissionRefreshSnapshot {
            snapshot = permissionRefreshSnapshot
        }
        return snapshot
    }

    func saveRecording() -> AppShellSnapshot {
        guard snapshot.status == .awaitingSave else { return snapshot }
        saveRecordingCallCount += 1
        onSaveRecording?()
        snapshot.status = .ready
        snapshot.errorMessage = nil
        snapshot.pendingSaveURL = nil
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

private extension AppShellSnapshot {
    func withHotkeyRegistrationFailure() -> AppShellSnapshot {
        var next = self
        next.status = .error
        next.settings.globalHotkey = nil
        next.errorMessage = "OpenRec could not register the global shortcut."
        next.elapsedTimeText = nil
        next.pendingSaveURL = nil
        return next
    }
}
