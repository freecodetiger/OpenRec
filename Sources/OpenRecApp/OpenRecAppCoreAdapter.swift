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

private let currentlyRequiredPermissions: [PermissionKind] = [.screenRecording, .microphone]

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
    private let systemSettingsOpener: any SystemSettingsOpening
    private let permissionRequester: any PermissionRequesting
    private let appRelauncher: any AppRelaunching
    private let screenFrameConverter: WindowScreenFrameConverter

    private(set) var snapshot: AppShellSnapshot
    var onHotkeyTriggered: (@MainActor @Sendable () -> Void)?

    private var displays: [DisplaySourceMetadata]
    private var windows: [WindowSourceMetadata]
    private var appLanguage: AppLanguage
    private var hotkeyRegistrationErrorMessage: String?

    private var strings: OpenRecLocalization {
        OpenRecLocalization(appLanguage)
    }

    init(
        settingsStore: SettingsStore,
        captureSourceProvider: any CaptureSourceProvider,
        audioDeviceProvider: any AudioDeviceProvider,
        permissionChecker: PermissionChecker,
        hotkeyManager: HotkeyManager,
        recordingEngine: (any RecordingEngine)? = nil,
        recordingCoordinator: RecordingCoordinator? = nil,
        savePanel: any RecordingSavePanelPresenting = NSSavePanelRecordingSavePanel(),
        fileMover: any RecordingFileMoving = FileManagerRecordingFileMover(),
        systemSettingsOpener: any SystemSettingsOpening = NSWorkspaceSystemSettingsOpener(),
        permissionRequester: any PermissionRequesting = SystemPermissionRequester(),
        appRelauncher: any AppRelaunching = NSWorkspaceAppRelauncher(),
        screenFrameConverter: WindowScreenFrameConverter = WindowScreenFrameConverter()
    ) {
        self.settingsStore = settingsStore
        self.captureSourceProvider = captureSourceProvider
        self.audioDeviceProvider = audioDeviceProvider
        self.permissionChecker = permissionChecker
        self.hotkeyManager = hotkeyManager
        self.displays = []
        self.windows = []
        self.appLanguage = .english
        self.snapshot = Self.emptySnapshot()
        let sourceValidator = AppCaptureSourceValidator()
        self.sourceValidator = sourceValidator
        self.savePanel = savePanel
        self.fileMover = fileMover
        self.systemSettingsOpener = systemSettingsOpener
        self.permissionRequester = permissionRequester
        self.appRelauncher = appRelauncher
        self.screenFrameConverter = screenFrameConverter
        self.hotkeyRegistrationErrorMessage = nil
        self.recordingCoordinator = recordingCoordinator ?? RecordingCoordinator(
            permissionValidator: DefaultRecordingPermissionValidator(permissionChecker: permissionChecker),
            configurationResolver: DefaultRecordingConfigurationResolver(
                sourceValidator: sourceValidator
            ),
            engine: recordingEngine ?? ScreenCaptureRecordingEngine(),
            finalizer: FileTemporaryRecordingFinalizer()
        )
        self.hotkeyManager.onHotkeyTriggered = { [weak self] _ in
            Task { @MainActor in
                self?.onHotkeyTriggered?()
            }
        }
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
            let appSettings = try settingsStore.load()
            appLanguage = appSettings.appLanguage
            let settings = normalizedSettings(appSettings.recording)
            let permissionStatuses = permissionChecker.statuses()
            let requiredPermissions = requiredPermissions(from: permissionStatuses)

            if !requiredPermissions.isEmpty {
                snapshot = permissionSnapshot(
                    settings: settings,
                    permissionStatuses: permissionStatuses,
                    requiredPermissions: requiredPermissions
                ).withHotkeyRegistrationError(hotkeyRegistrationErrorMessage)
                return snapshot
            }

            displays = try await captureSourceProvider.displays()
            windows = try await captureSourceProvider.windows()
            sourceValidator.update(displays: displays, windows: windows)
            snapshot = buildSnapshot(
                settings: settings,
                recordingState: recordingCoordinator.state
            ).withHotkeyRegistrationError(hotkeyRegistrationErrorMessage)
        } catch {
            snapshot = snapshot.withError(AppErrorPresenter.message(for: error, strings: strings))
        }
        return snapshot
    }

    func registerSavedHotkey() -> AppShellSnapshot {
        guard hotkeyManager.savedHotkey != nil else {
            return snapshot
        }

        do {
            try hotkeyManager.registerSavedHotkey()
            hotkeyRegistrationErrorMessage = nil
            snapshot.settings.globalHotkey = hotkeyManager.savedHotkey
        } catch {
            hotkeyManager.clearSavedHotkey()
            hotkeyRegistrationErrorMessage = strings.hotkeyRegistrationFailure
            var settings = snapshot.settings
            settings.globalHotkey = nil
            snapshot.settings = settings
            _ = save(settings: settings)
            snapshot = snapshot.withHotkeyRegistrationError(hotkeyRegistrationErrorMessage)
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
                .withError(AppErrorPresenter.message(for: error, strings: strings))
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
                .withError(AppErrorPresenter.message(for: error, strings: strings))
        }

        return snapshot
    }

    func selectMode(_ mode: CaptureMode) -> AppShellSnapshot {
        guard mode == .display else {
            snapshot.mode = mode
            if let target = snapshot.availableTargets.first(where: { $0.mode == mode }) {
                snapshot.selectedTarget = target
            }
            return snapshot
        }

        var settings = snapshot.settings
        settings.defaultMode = .display
        return updateSettings(settings)
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
        return updateSettings(settings)
    }

    func updateSettings(_ settings: RecordingSettings) -> AppShellSnapshot {
        let settings = normalizedSettings(settings)
        guard save(settings: settings) else {
            return snapshot
        }

        snapshot = buildSnapshot(settings: settings, recordingState: recordingCoordinator.state)
        return snapshot
    }

    func updateAppLanguage(_ language: AppLanguage) -> AppShellSnapshot {
        guard language != appLanguage else { return snapshot }
        appLanguage = language

        do {
            try settingsStore.save(AppSettings(schemaVersion: 1, appLanguage: appLanguage, recording: snapshot.settings))
            snapshot.appLanguage = appLanguage
        } catch {
            snapshot = snapshot.withError(AppErrorPresenter.message(for: error, strings: strings))
        }

        return snapshot
    }

    func openPermissionSettings(for kind: PermissionKind) -> AppShellSnapshot {
        systemSettingsOpener.openPermissionSettings(for: kind)
        return snapshot
    }

    func requestPermission(for kind: PermissionKind) async -> AppShellSnapshot {
        await permissionRequester.requestPermission(for: kind)
        systemSettingsOpener.openPermissionSettings(for: kind)
        return await refresh()
    }

    func reopenApplication() {
        appRelauncher.reopenApplication()
    }

    func refreshPermissions() -> AppShellSnapshot {
        snapshot = buildSnapshot(settings: snapshot.settings, recordingState: recordingCoordinator.state)
            .withHotkeyRegistrationError(hotkeyRegistrationErrorMessage)
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
        let requiredPermissions = requiredPermissions(from: permissionStatuses)
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
            pendingSaveURL: pendingSaveURL(for: recordingState),
            appLanguage: appLanguage
        )
    }

    func saveRecording() -> AppShellSnapshot {
        guard snapshot.status == .awaitingSave else { return snapshot }
        guard case let .awaitingSave(pendingURL) = recordingCoordinator.state else {
            snapshot = buildSnapshot(settings: snapshot.settings, recordingState: recordingCoordinator.state)
            return snapshot
        }

        guard let destinationURL = savePanel.destinationURL(defaultFileName: pendingURL.lastPathComponent) else {
            do {
                try recordingCoordinator.discard()
                snapshot = buildSnapshot(settings: snapshot.settings, recordingState: recordingCoordinator.state)
            } catch {
                snapshot = buildSnapshot(settings: snapshot.settings, recordingState: recordingCoordinator.state)
                    .withError(AppErrorPresenter.message(for: error, strings: strings))
            }
            return snapshot
        }

        do {
            try fileMover.moveRecording(from: pendingURL, to: destinationURL)
            try recordingCoordinator.markSaved()
            snapshot = buildSnapshot(settings: snapshot.settings, recordingState: recordingCoordinator.state)
        } catch {
            snapshot = buildSnapshot(settings: snapshot.settings, recordingState: recordingCoordinator.state)
            snapshot.errorMessage = AppErrorPresenter.message(for: error, strings: strings)
        }

        return snapshot
    }

    func retrySave() -> AppShellSnapshot {
        guard snapshot.status == .awaitingSave else { return snapshot }

        let error = recordingCoordinator.saveCancelled()
        snapshot = buildSnapshot(settings: snapshot.settings, recordingState: recordingCoordinator.state)
        snapshot.errorMessage = AppErrorPresenter.message(for: error, strings: strings)
        return snapshot
    }

    func discardRecording() -> AppShellSnapshot {
        guard snapshot.status == .awaitingSave else { return snapshot }

        do {
            try recordingCoordinator.discard()
            snapshot = buildSnapshot(settings: snapshot.settings, recordingState: recordingCoordinator.state)
        } catch {
            snapshot = buildSnapshot(settings: snapshot.settings, recordingState: recordingCoordinator.state)
                .withError(AppErrorPresenter.message(for: error, strings: strings))
        }

        return snapshot
    }

    private func save(settings: RecordingSettings) -> Bool {
        do {
            try settingsStore.save(AppSettings(schemaVersion: 1, appLanguage: appLanguage, recording: normalizedSettings(settings)))
            return true
        } catch {
            snapshot = snapshot.withError(AppErrorPresenter.message(for: error, strings: strings))
            return false
        }
    }

    private func normalizedSettings(_ settings: RecordingSettings) -> RecordingSettings {
        var normalized = settings
        normalized.defaultMode = .display
        return normalized
    }

    private func selectedMode(
        settings: RecordingSettings,
        targets: [SourceTargetOption]
    ) -> CaptureMode {
        if targets.contains(where: { $0.mode == .display }) {
            return .display
        }

        return targets.first?.mode ?? .display
    }

    private func requiredPermissions(
        from statuses: [PermissionKind: PermissionStatus]
    ) -> [PermissionKind] {
        currentlyRequiredPermissions.filter {
            statuses[$0] != .granted
        }
    }

    private func permissionSnapshot(
        settings: RecordingSettings,
        permissionStatuses: [PermissionKind: PermissionStatus],
        requiredPermissions: [PermissionKind]
    ) -> AppShellSnapshot {
        let targets = sourceTargetOptions(displays: displays, windows: windows)
        let microphones = microphoneOptions()
        return AppShellSnapshot(
            status: .permissionRequired,
            mode: .display,
            selectedTarget: selectedTarget(
                for: .display,
                from: targets
            ),
            availableTargets: targets,
            selectedMicrophoneID: selectedMicrophoneID(
                settings: settings,
                microphones: microphones
            ),
            microphones: microphones,
            settings: settings,
            permissionStatuses: permissionStatuses,
            requiredPermissions: requiredPermissions,
            errorMessage: nil,
            elapsedTimeText: nil,
            pendingSaveURL: nil,
            appLanguage: appLanguage
        )
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
                title: strings.noSourceSelected,
                subtitle: strings.chooseAvailableSource
            )
    }

    private func sourceTargetOptions(
        displays: [DisplaySourceMetadata],
        windows: [WindowSourceMetadata]
    ) -> [SourceTargetOption] {
        return displays.map { display in
            SourceTargetOption(
                id: "display-\(display.id.rawValue)",
                mode: .display,
                source: display.source,
                title: display.name,
                subtitle: pixelSizeSubtitle(display.pixelSize)
            )
        } + windows.filter(Self.isRecordableWindow).map { window in
            SourceTargetOption(
                id: "window-\(window.id.rawValue)",
                mode: .window,
                source: window.source,
                title: windowTitle(window),
                subtitle: pixelSizeSubtitle(window.pixelSize),
                screenFrame: screenFrameConverter.appKitFrame(fromScreenCaptureKitFrame: window.screenFrame)
            )
        }
    }

    private static func isRecordableWindow(_ window: WindowSourceMetadata) -> Bool {
        guard window.isAvailable,
              let screenFrame = window.screenFrame,
              screenFrame.width >= 160,
              screenFrame.height >= 80,
              !window.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let applicationName = window.owningApplicationName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !applicationName.isEmpty else {
            return false
        }

        let lowercasedTitle = window.title.lowercased()
        let lowercasedApplicationName = applicationName.lowercased()
        let excludedApplications = [
            "dock",
            "程序坞",
            "windowmanager",
            "控制中心",
            "control center",
            "textinputmenuagent",
            "openrec"
        ]
        let excludedTitles = [
            "wallpaper",
            "desktop",
            "dock",
            "menubar",
            "statusindicator",
            "gesture blocking overlay",
            "app icon window",
            "item-0"
        ]

        return !excludedApplications.contains(lowercasedApplicationName) &&
            !excludedTitles.contains { lowercasedTitle.contains($0) }
    }

    private func microphoneOptions() -> [MicrophoneOption] {
        let devices = audioDeviceProvider.microphoneDevices()
        let options = devices.map { device in
            MicrophoneOption(
                id: device.id,
                deviceID: device.id,
                title: device.name,
                subtitle: device.isDefault ? strings.systemDefaultInputDevice : strings.inputDevice
            )
        }

        guard !options.isEmpty else {
            return [
                MicrophoneOption(
                    id: "default",
                    deviceID: nil,
                    title: strings.systemDefault,
                    subtitle: strings.usesCurrentMacOSInputDevice
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
        return AppErrorPresenter.message(for: error, strings: strings)
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
            return window.title.isEmpty ? strings.untitledWindow : window.title
        }

        return "\(appName) - \(window.title)"
    }

    private func pixelSizeSubtitle(_ pixelSize: CGSize) -> String {
        "\(Int(pixelSize.width)) x \(Int(pixelSize.height)), \(strings.originalResolution)"
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
            requiredPermissions: currentlyRequiredPermissions,
            errorMessage: "Choose an available display or window.",
            elapsedTimeText: nil,
            pendingSaveURL: nil,
            appLanguage: .english
        )
    }
}

@MainActor
private final class NSSavePanelRecordingSavePanel: RecordingSavePanelPresenting {
    private let windowPresenter = UserWindowPresenter()

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
        windowPresenter.activateApplication()
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

    func withHotkeyRegistrationError(_ message: String?) -> AppShellSnapshot {
        guard let message else {
            return self
        }

        var next = self
        next.status = .error
        next.errorMessage = message
        next.settings.globalHotkey = nil
        next.elapsedTimeText = nil
        next.pendingSaveURL = nil
        return next
    }
}

private enum AppErrorPresenter {
    static func message(for error: any Error, strings: OpenRecLocalization) -> String {
        if let error = error as? OpenRecError {
            return message(for: error, strings: strings)
        }

        return strings.recordingStateUpdateFailure
    }

    static func message(for error: OpenRecError, strings: OpenRecLocalization) -> String {
        switch error {
        case .permissionDenied:
            return strings.statusDetail(.permissionRequired)
        case .captureSourceUnavailable:
            return strings.sourceUnavailable
        case let .captureConfigurationInvalid(reason):
            return reason
        case .microphoneUnavailable:
            return strings.microphoneUnavailable
        case .hotkeyConflict:
            return strings.hotkeyConflict
        case let .writerInitializationFailed(reason):
            return reason
        case let .writerFailed(reason):
            return reason
        case .saveCancelled:
            return strings.chooseSaveLocationOrDiscard
        case let .unknown(reason):
            return reason
        }
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
