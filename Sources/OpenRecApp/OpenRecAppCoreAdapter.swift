import AppKit
import Foundation
import OpenRecCore
import UniformTypeIdentifiers

@MainActor
protocol RecordingSavePanelPresenting: AnyObject {
    func destinationURL(defaultFileName: String) -> URL?
}

protocol RecordingFileMoving: AnyObject {
    func moveRecording(from sourceURL: URL, to destinationURL: URL) throws
}

final class OpenRecAppCoreAdapter: AppShellAdapter {
    private let settingsStore: SettingsStore
    private let captureSourceProvider: any CaptureSourceProvider
    private let audioDeviceProvider: any AudioDeviceProvider
    private let permissionChecker: PermissionChecker
    private let hotkeyManager: HotkeyManager
    private let recordingCoordinator: RecordingCoordinator
    private let sourceValidator: AppCaptureSourceValidator
    private let savePanel: any RecordingSavePanelPresenting
    private let fileMover: any RecordingFileMoving

    private(set) var snapshot: AppShellSnapshot
    private var displays: [DisplaySourceMetadata]
    private var windows: [WindowSourceMetadata]

    init(
        settingsStore: SettingsStore,
        captureSourceProvider: any CaptureSourceProvider,
        audioDeviceProvider: any AudioDeviceProvider,
        permissionChecker: PermissionChecker,
        hotkeyManager: HotkeyManager,
        recordingCoordinator: RecordingCoordinator? = nil,
        savePanel: any RecordingSavePanelPresenting = NSSavePanelRecordingSavePanel(),
        fileMover: any RecordingFileMoving = FileManagerRecordingFileMover()
    ) {
        self.settingsStore = settingsStore
        self.captureSourceProvider = captureSourceProvider
        self.audioDeviceProvider = audioDeviceProvider
        self.permissionChecker = permissionChecker
        self.hotkeyManager = hotkeyManager
        self.displays = []
        self.windows = []
        self.snapshot = Self.emptySnapshot()
        let sourceValidator = AppCaptureSourceValidator()
        self.sourceValidator = sourceValidator
        self.savePanel = savePanel
        self.fileMover = fileMover
        self.recordingCoordinator = recordingCoordinator ?? RecordingCoordinator(
            permissionValidator: DefaultRecordingPermissionValidator(permissionChecker: permissionChecker),
            configurationResolver: DefaultRecordingConfigurationResolver(
                sourceValidator: sourceValidator
            ),
            engine: DisabledRecordingEngine(),
            finalizer: FileTemporaryRecordingFinalizer()
        )
    }

    convenience init() throws {
        let settingsStore = try SettingsStore()
        let permissionChecker = PermissionChecker(provider: SystemPermissionStatusProvider())
        let hotkeyManager = HotkeyManager(
            registry: SystemHotkeyRegistry(),
            savedHotkey: try settingsStore.load().recording.globalHotkey
        )

        self.init(
            settingsStore: settingsStore,
            captureSourceProvider: ScreenCaptureKitCaptureSourceProvider(),
            audioDeviceProvider: AVFoundationAudioDeviceProvider(),
            permissionChecker: permissionChecker,
            hotkeyManager: hotkeyManager
        )
    }

    func refresh() async -> AppShellSnapshot {
        do {
            displays = try await captureSourceProvider.displays()
            windows = try await captureSourceProvider.windows()
            sourceValidator.update(displays: displays, windows: windows)
            let settings = try settingsStore.load().recording
            snapshot = buildSnapshot(settings: settings, recordingState: recordingCoordinator.state)
        } catch {
            snapshot = snapshot.withError(AppErrorPresenter.message(for: error))
        }
        return snapshot
    }

    func startRecording() -> AppShellSnapshot {
        guard snapshot.status == .ready else { return snapshot }

        do {
            _ = try recordingCoordinator.start(
                source: snapshot.selectedTarget.source,
                settings: snapshot.settings
            )
            snapshot = buildSnapshot(settings: snapshot.settings, recordingState: recordingCoordinator.state)
        } catch {
            snapshot = buildSnapshot(settings: snapshot.settings, recordingState: recordingCoordinator.state)
                .withError(AppErrorPresenter.message(for: error))
        }

        return snapshot
    }

    func stopRecording() -> AppShellSnapshot {
        guard snapshot.status == .recording else { return snapshot }

        do {
            _ = try recordingCoordinator.stop()
            snapshot = buildSnapshot(settings: snapshot.settings, recordingState: recordingCoordinator.state)
        } catch {
            snapshot = buildSnapshot(settings: snapshot.settings, recordingState: recordingCoordinator.state)
                .withError(AppErrorPresenter.message(for: error))
        }

        return snapshot
    }

    func selectMode(_ mode: CaptureMode) -> AppShellSnapshot {
        var next = snapshot
        next.mode = mode
        if let target = next.availableTargets.first(where: { $0.mode == mode }) {
            next.selectedTarget = target
        }
        next.settings.defaultMode = mode
        guard save(settings: next.settings) else {
            return snapshot
        }
        snapshot = next
        return snapshot
    }

    func selectTarget(id: String) -> AppShellSnapshot {
        guard let target = snapshot.availableTargets.first(where: { $0.id == id }) else {
            return snapshot
        }

        snapshot.selectedTarget = target
        snapshot.mode = target.mode
        return snapshot
    }

    func selectMicrophone(id: String) -> AppShellSnapshot {
        guard let microphone = snapshot.microphones.first(where: { $0.id == id }) else {
            return snapshot
        }

        var settings = snapshot.settings
        settings.microphoneDeviceID = microphone.deviceID
        guard save(settings: settings) else {
            return snapshot
        }

        snapshot.settings = settings
        snapshot.selectedMicrophoneID = id
        return snapshot
    }

    func selectScenario(_ snapshot: AppShellSnapshot) -> AppShellSnapshot {
        self.snapshot = snapshot
        return snapshot
    }

    private func buildSnapshot(
        settings: RecordingSettings,
        recordingState: RecordingState
    ) -> AppShellSnapshot {
        let targets = sourceTargetOptions(displays: displays, windows: windows)
        let mode = selectedMode(settings: settings, targets: targets)
        let selectedTarget = selectedTarget(for: mode, from: targets)
        let microphones = microphoneOptions()
        let selectedMicrophoneID = selectedMicrophoneID(
            settings: settings,
            microphones: microphones
        )
        let permissionStatuses = permissionChecker.statuses()
        let requiredPermissions = PermissionKind.allCases.filter {
            permissionStatuses[$0] != .granted
        }
        let status = status(
            for: recordingState,
            requiredPermissions: requiredPermissions,
            hasTarget: !targets.isEmpty
        )

        return AppShellSnapshot(
            status: status,
            mode: selectedTarget.mode,
            selectedTarget: selectedTarget,
            availableTargets: targets,
            selectedMicrophoneID: selectedMicrophoneID,
            microphones: microphones,
            settings: settings,
            permissionStatuses: permissionStatuses,
            requiredPermissions: requiredPermissions,
            errorMessage: errorMessage(for: recordingState),
            elapsedTimeText: elapsedTimeText(for: recordingState),
            pendingSaveURL: pendingSaveURL(for: recordingState)
        )
    }

    func saveRecording() -> AppShellSnapshot {
        guard snapshot.status == .awaitingSave else { return snapshot }
        guard case let .awaitingSave(pendingURL) = recordingCoordinator.state else {
            snapshot = buildSnapshot(settings: snapshot.settings, recordingState: recordingCoordinator.state)
            return snapshot
        }

        guard let destinationURL = savePanel.destinationURL(defaultFileName: pendingURL.lastPathComponent) else {
            let error = recordingCoordinator.saveCancelled()
            snapshot = buildSnapshot(settings: snapshot.settings, recordingState: recordingCoordinator.state)
            snapshot.errorMessage = AppErrorPresenter.message(for: error)
            return snapshot
        }

        do {
            try fileMover.moveRecording(from: pendingURL, to: destinationURL)
            try recordingCoordinator.markSaved()
            snapshot = buildSnapshot(settings: snapshot.settings, recordingState: recordingCoordinator.state)
        } catch {
            snapshot = buildSnapshot(settings: snapshot.settings, recordingState: recordingCoordinator.state)
            snapshot.errorMessage = AppErrorPresenter.message(for: error)
        }

        return snapshot
    }

    func retrySave() -> AppShellSnapshot {
        guard snapshot.status == .awaitingSave else { return snapshot }

        let error = recordingCoordinator.saveCancelled()
        snapshot = buildSnapshot(settings: snapshot.settings, recordingState: recordingCoordinator.state)
        snapshot.errorMessage = AppErrorPresenter.message(for: error)
        return snapshot
    }

    func discardRecording() -> AppShellSnapshot {
        guard snapshot.status == .awaitingSave else { return snapshot }

        do {
            try recordingCoordinator.discard()
            snapshot = buildSnapshot(settings: snapshot.settings, recordingState: recordingCoordinator.state)
        } catch {
            snapshot = buildSnapshot(settings: snapshot.settings, recordingState: recordingCoordinator.state)
                .withError(AppErrorPresenter.message(for: error))
        }

        return snapshot
    }

    private func save(settings: RecordingSettings) -> Bool {
        do {
            try settingsStore.save(AppSettings(schemaVersion: 1, recording: settings))
            return true
        } catch {
            snapshot = snapshot.withError(AppErrorPresenter.message(for: error))
            return false
        }
    }

    private func selectedMode(
        settings: RecordingSettings,
        targets: [SourceTargetOption]
    ) -> CaptureMode {
        if targets.contains(where: { $0.mode == settings.defaultMode }) {
            return settings.defaultMode
        }

        return targets.first?.mode ?? settings.defaultMode
    }

    private func selectedTarget(
        for mode: CaptureMode,
        from targets: [SourceTargetOption]
    ) -> SourceTargetOption {
        targets.first(where: { $0.mode == mode }) ??
            targets.first ??
            SourceTargetOption(
                id: "source-unavailable",
                mode: mode,
                source: mode == .display ? .display(DisplayID(rawValue: 0)) : .window(WindowID(rawValue: 0)),
                title: "No Source Selected",
                subtitle: "Choose an available display or window."
            )
    }

    private func sourceTargetOptions(
        displays: [DisplaySourceMetadata],
        windows: [WindowSourceMetadata]
    ) -> [SourceTargetOption] {
        displays.map { display in
            SourceTargetOption(
                id: "display-\(display.id.rawValue)",
                mode: .display,
                source: display.source,
                title: display.name,
                subtitle: pixelSizeSubtitle(display.pixelSize)
            )
        } + windows.map { window in
            SourceTargetOption(
                id: "window-\(window.id.rawValue)",
                mode: .window,
                source: window.source,
                title: windowTitle(window),
                subtitle: pixelSizeSubtitle(window.pixelSize)
            )
        }
    }

    private func microphoneOptions() -> [MicrophoneOption] {
        let devices = audioDeviceProvider.microphoneDevices()
        let options = devices.map { device in
            MicrophoneOption(
                id: device.id,
                deviceID: device.id,
                title: device.name,
                subtitle: device.isDefault ? "System default input device" : "Input device"
            )
        }

        guard !options.isEmpty else {
            return [
                MicrophoneOption(
                    id: "default",
                    deviceID: nil,
                    title: "System Default",
                    subtitle: "Uses the current macOS input device"
                )
            ]
        }

        return options
    }

    private func selectedMicrophoneID(
        settings: RecordingSettings,
        microphones: [MicrophoneOption]
    ) -> String {
        if let microphoneDeviceID = settings.microphoneDeviceID,
           microphones.contains(where: { $0.deviceID == microphoneDeviceID }) {
            return microphoneDeviceID
        }

        return audioDeviceProvider.defaultMicrophoneDevice()?.id ?? microphones[0].id
    }

    private func status(
        for recordingState: RecordingState,
        requiredPermissions: [PermissionKind],
        hasTarget: Bool
    ) -> AppShellStatus {
        if !requiredPermissions.isEmpty {
            return .permissionRequired
        }

        switch recordingState {
        case .recording, .stopping:
            return .recording
        case .awaitingSave:
            return .awaitingSave
        case .failed:
            return .error
        case .preparing, .idle:
            return hasTarget ? .ready : .error
        }
    }

    private func errorMessage(for recordingState: RecordingState) -> String? {
        guard case let .failed(error) = recordingState else { return nil }
        return AppErrorPresenter.message(for: error)
    }

    private func elapsedTimeText(for recordingState: RecordingState) -> String? {
        guard case .recording = recordingState else { return nil }
        return "00:00"
    }

    private func pendingSaveURL(for recordingState: RecordingState) -> URL? {
        guard case let .awaitingSave(url) = recordingState else { return nil }
        return url
    }

    private func windowTitle(_ window: WindowSourceMetadata) -> String {
        guard let appName = window.owningApplicationName,
              !appName.isEmpty,
              !window.title.isEmpty else {
            return window.title.isEmpty ? "Untitled Window" : window.title
        }

        return "\(appName) - \(window.title)"
    }

    private func pixelSizeSubtitle(_ pixelSize: CGSize) -> String {
        "\(Int(pixelSize.width)) x \(Int(pixelSize.height)), original resolution"
    }

    private static func emptySnapshot() -> AppShellSnapshot {
        AppShellSnapshot(
            status: .error,
            mode: .display,
            selectedTarget: SourceTargetOption(
                id: "source-unavailable",
                mode: .display,
                source: .display(DisplayID(rawValue: 0)),
                title: "No Source Selected",
                subtitle: "Choose an available display or window."
            ),
            availableTargets: [],
            selectedMicrophoneID: "default",
            microphones: [
                MicrophoneOption(
                    id: "default",
                    deviceID: nil,
                    title: "System Default",
                    subtitle: "Uses the current macOS input device"
                )
            ],
            settings: .defaults,
            permissionStatuses: Dictionary(uniqueKeysWithValues: PermissionKind.allCases.map { ($0, .unknown) }),
            requiredPermissions: PermissionKind.allCases,
            errorMessage: "Choose an available display or window.",
            elapsedTimeText: nil,
            pendingSaveURL: nil
        )
    }
}

@MainActor
private final class NSSavePanelRecordingSavePanel: RecordingSavePanelPresenting {
    func destinationURL(defaultFileName: String) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultFileName
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        switch URL(filePath: defaultFileName).pathExtension.lowercased() {
        case "mp4":
            panel.allowedContentTypes = [.mpeg4Movie]
        case "mov":
            panel.allowedContentTypes = [.quickTimeMovie]
        default:
            break
        }
        return panel.runModal() == .OK ? panel.url : nil
    }
}

private final class FileManagerRecordingFileMover: RecordingFileMoving {
    func moveRecording(from sourceURL: URL, to destinationURL: URL) throws {
        if FileManager.default.fileExists(atPath: destinationURL.path(percentEncoded: false)) {
            _ = try FileManager.default.replaceItemAt(
                destinationURL,
                withItemAt: sourceURL,
                backupItemName: nil,
                options: []
            )
        } else {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
        }
    }
}

private extension AppShellSnapshot {
    func withError(_ message: String) -> AppShellSnapshot {
        var next = self
        next.status = .error
        next.errorMessage = message
        next.elapsedTimeText = nil
        next.pendingSaveURL = nil
        return next
    }
}

private enum AppErrorPresenter {
    static func message(for error: any Error) -> String {
        if let error = error as? OpenRecError {
            return message(for: error)
        }

        return "OpenRec could not update recording state."
    }

    static func message(for error: OpenRecError) -> String {
        switch error {
        case .permissionDenied:
            return "OpenRec needs macOS permissions before recording."
        case .captureSourceUnavailable:
            return "The selected source is no longer available."
        case let .captureConfigurationInvalid(reason):
            return reason
        case .microphoneUnavailable:
            return "No microphone input is available."
        case .hotkeyConflict:
            return "That global shortcut is already in use."
        case let .writerInitializationFailed(reason):
            return reason
        case let .writerFailed(reason):
            return reason
        case .saveCancelled:
            return "Choose a save location or discard the recording."
        case let .unknown(reason):
            return reason
        }
    }
}

private struct DisabledRecordingEngine: RecordingEngine {
    func start(configuration: ResolvedRecordingConfiguration) throws -> RecordingSession {
        throw OpenRecError.writerInitializationFailed("Recording is currently unavailable.")
    }

    func stop(session: RecordingSession) throws -> URL {
        throw OpenRecError.writerFailed("Recording is currently unavailable.")
    }
}

private final class AppCaptureSourceValidator: CaptureSourceValidating, @unchecked Sendable {
    private var displays: [DisplaySourceMetadata]
    private var windows: [WindowSourceMetadata]

    init(
        displays: [DisplaySourceMetadata] = [],
        windows: [WindowSourceMetadata] = []
    ) {
        self.displays = displays
        self.windows = windows
    }

    func update(
        displays: [DisplaySourceMetadata],
        windows: [WindowSourceMetadata]
    ) {
        self.displays = displays
        self.windows = windows
    }

    func metadata(for source: CaptureSource) throws -> CaptureSourceMetadata {
        switch source {
        case .display:
            guard let display = displays.first(where: { $0.source == source }) else {
                throw OpenRecError.captureSourceUnavailable(source)
            }
            return display.captureMetadata
        case .window:
            guard let window = windows.first(where: { $0.source == source }) else {
                throw OpenRecError.captureSourceUnavailable(source)
            }
            return window.captureMetadata
        }
    }
}
