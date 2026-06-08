import Testing
@testable import OpenRecApp
import OpenRecCore
import Foundation

@Test func mockScenariosCoverRequiredMenuStates() {
    let scenarios = AppShellSnapshot.mockScenarios

    #expect(scenarios.map(\.status).contains(.ready))
    #expect(scenarios.map(\.status).contains(.recording))
    #expect(scenarios.map(\.status).contains(.permissionRequired))
    #expect(scenarios.map(\.status).contains(.error))
}

@Test func menuPresentationForReadyPrioritizesFullScreenRecording() {
    let presentation = MenuBarPresentationModel.make(
        snapshot: .ready,
        isRecording: false,
        canStartRecording: true
    )

    #expect(presentation.primaryActionTitle == "Start Full Screen Recording")
    #expect(presentation.showsSourceActions == true)
    #expect(presentation.showsMicrophone == true)
    #expect(presentation.showsSettingsSummary == true)
    #expect(presentation.showsPreferences == true)
}

@Test func menuPresentationForRecordingHidesConfigurationAndOnlyAllowsStop() {
    let presentation = MenuBarPresentationModel.make(
        snapshot: .recording,
        isRecording: true,
        canStartRecording: false
    )

    #expect(presentation.primaryActionTitle == "Stop Recording")
    #expect(presentation.showsSourceActions == false)
    #expect(presentation.showsMicrophone == false)
    #expect(presentation.showsSettingsSummary == false)
    #expect(presentation.showsPreferences == false)
    #expect(presentation.isPrimaryActionEnabled == true)
}

@Test func menuPresentationForPermissionRequiredFocusesPermissionActions() {
    let presentation = MenuBarPresentationModel.make(
        snapshot: .permissionRequired,
        isRecording: false,
        canStartRecording: false
    )

    #expect(presentation.showsPermissionActions == true)
    #expect(presentation.showsSourceActions == false)
    #expect(presentation.showsMicrophone == false)
    #expect(presentation.isPrimaryActionEnabled == false)
}

@Test func menuPresentationForAwaitingSaveUsesSaveRecoveryActions() {
    let presentation = MenuBarPresentationModel.make(
        snapshot: .awaitingSave,
        isRecording: false,
        canStartRecording: false
    )

    #expect(presentation.primaryActionTitle == "Save Again")
    #expect(presentation.showsSaveActions == true)
    #expect(presentation.showsSourceActions == false)
    #expect(presentation.showsPreferences == false)
}

@MainActor
@Test func primaryActionReflectsRecordingStatus() {
    let adapter = MockAppCoreAdapter(initialSnapshot: .recording)
    let viewModel = AppShellViewModel(adapter: adapter)

    #expect(viewModel.primaryActionTitle == "Stop Recording")

    viewModel.stopRecording()

    #expect(viewModel.snapshot.status == .ready)
    #expect(viewModel.primaryActionTitle == "Start Recording")
}

@MainActor
@Test func viewModelRegistersSavedHotkeyOnStartup() {
    let hotkey = Hotkey(keyCode: 49, modifiers: [.command, .shift])
    var snapshot = AppShellSnapshot.ready
    snapshot.settings.globalHotkey = hotkey
    let registry = InMemoryHotkeyRegistry()
    let adapter = MockAppCoreAdapter(
        initialSnapshot: snapshot,
        hotkeyManager: HotkeyManager(registry: registry, savedHotkey: hotkey)
    )
    let viewModel = AppShellViewModel(adapter: adapter)

    viewModel.startHotkeyMonitoring()

    #expect(registry.contains(hotkey))
    #expect(viewModel.snapshot.status == .ready)
    #expect(viewModel.snapshot.errorMessage == nil)
}

@MainActor
@Test func viewModelHotkeyTriggerStartsAndStopsRecording() async {
    let hotkey = Hotkey(keyCode: 49, modifiers: [.command, .shift])
    let registry = InMemoryHotkeyRegistry()
    let adapter = MockAppCoreAdapter(
        initialSnapshot: .ready,
        hotkeyManager: HotkeyManager(registry: registry, savedHotkey: hotkey)
    )
    let viewModel = AppShellViewModel(adapter: adapter)

    viewModel.startHotkeyMonitoring()
    registry.trigger(hotkey)
    await Task.yield()

    #expect(viewModel.snapshot.status == .recording)
    #expect(adapter.startRecordingCallCount == 1)

    registry.trigger(hotkey)
    await Task.yield()

    #expect(viewModel.snapshot.status == .ready)
    #expect(adapter.stopRecordingCallCount == 1)
}

@MainActor
@Test func viewModelUpdatesElapsedTimeWhileRecording() {
    var now = Date(timeIntervalSinceReferenceDate: 1_000)
    let adapter = MockAppCoreAdapter(initialSnapshot: .ready)
    let viewModel = AppShellViewModel(adapter: adapter, now: { now })

    viewModel.startRecording()
    now = Date(timeIntervalSinceReferenceDate: 1_065)
    viewModel.refreshElapsedTime()

    #expect(viewModel.snapshot.elapsedTimeText == "01:05")
}

@MainActor
@Test func viewModelPromptsForSaveAfterStoppingRecording() {
    let adapter = MockAppCoreAdapter(initialSnapshot: .recording)
    var awaitingSaveSnapshot = AppShellSnapshot.awaitingSave
    awaitingSaveSnapshot.pendingSaveURL = URL(filePath: "/tmp/openrec-finished.mp4")
    adapter.stopRecordingSnapshot = awaitingSaveSnapshot
    let viewModel = AppShellViewModel(adapter: adapter)

    viewModel.stopRecording()

    #expect(adapter.stopRecordingCallCount == 1)
    #expect(adapter.saveRecordingCallCount == 1)
    #expect(viewModel.snapshot.status == .ready)
}

@MainActor
@Test func viewModelHotkeyTriggerIsNoOpOutsideReadyAndRecordingStates() async {
    let hotkey = Hotkey(keyCode: 49, modifiers: [.command, .shift])
    let registry = InMemoryHotkeyRegistry()
    let adapter = MockAppCoreAdapter(
        initialSnapshot: .awaitingSave,
        hotkeyManager: HotkeyManager(registry: registry, savedHotkey: hotkey)
    )
    let viewModel = AppShellViewModel(adapter: adapter)

    viewModel.startHotkeyMonitoring()
    registry.trigger(hotkey)
    await Task.yield()

    #expect(viewModel.snapshot.status == .awaitingSave)
    #expect(adapter.startRecordingCallCount == 0)
    #expect(adapter.stopRecordingCallCount == 0)
}

@MainActor
@Test func viewModelShowsHotkeyRegistrationFailureWithoutCrashingOrSavingFailedHotkey() {
    let hotkey = Hotkey(keyCode: 49, modifiers: [.command, .shift])
    let registry = InMemoryHotkeyRegistry(
        registrationFailure: .registrationFailed("system rejected hotkey")
    )
    let manager = HotkeyManager(registry: registry, savedHotkey: hotkey)
    let hotkeyAdapter = MockAppCoreAdapter(initialSnapshot: .ready, hotkeyManager: manager)
    let viewModel = AppShellViewModel(adapter: hotkeyAdapter)

    viewModel.startHotkeyMonitoring()

    #expect(viewModel.snapshot.status == .error)
    #expect(viewModel.snapshot.errorMessage == "OpenRec could not register the global shortcut.")
    #expect(viewModel.snapshot.settings.globalHotkey == nil)
    #expect(manager.savedHotkey == nil)
    #expect(registry.contains(hotkey) == false)
}

@MainActor
@Test func startRecordingRequiresPermissionsBeforeRecording() {
    let adapter = MockAppCoreAdapter(initialSnapshot: .permissionRequired)
    let viewModel = AppShellViewModel(adapter: adapter)

    viewModel.startRecording()

    #expect(viewModel.snapshot.status == .permissionRequired)
    #expect(viewModel.canStartRecording == false)
}

@MainActor
@Test func viewModelOpensPermissionSettingsThroughAdapter() {
    let adapter = MockAppCoreAdapter(initialSnapshot: .permissionRequired)
    let viewModel = AppShellViewModel(adapter: adapter)

    viewModel.openPermissionSettings(for: .screenRecording)

    #expect(adapter.openedPermissionSettings == [.screenRecording])
}

@MainActor
@Test func viewModelRechecksPermissionsThroughAdapter() async throws {
    var grantedSnapshot = AppShellSnapshot.permissionRequired
    grantedSnapshot.status = .ready
    grantedSnapshot.permissionStatuses = Dictionary(uniqueKeysWithValues: PermissionKind.allCases.map { ($0, .granted) })
    grantedSnapshot.requiredPermissions = []
    let adapter = MockAppCoreAdapter(initialSnapshot: .permissionRequired)
    adapter.permissionRefreshSnapshot = grantedSnapshot
    let viewModel = AppShellViewModel(adapter: adapter)

    viewModel.refreshPermissions()
    try await Task.sleep(for: .milliseconds(50))

    #expect(adapter.refreshCallCount == 1)
    #expect(viewModel.snapshot.status == .ready)
    #expect(viewModel.snapshot.requiredPermissions.isEmpty)
}

@MainActor
@Test func viewModelRequestsPermissionThroughAdapter() async throws {
    var grantedSnapshot = AppShellSnapshot.permissionRequired
    grantedSnapshot.status = .ready
    grantedSnapshot.permissionStatuses = Dictionary(uniqueKeysWithValues: PermissionKind.allCases.map { ($0, .granted) })
    grantedSnapshot.requiredPermissions = []
    let adapter = MockAppCoreAdapter(initialSnapshot: .permissionRequired)
    adapter.permissionRefreshSnapshot = grantedSnapshot
    let viewModel = AppShellViewModel(adapter: adapter)

    viewModel.requestPermission(for: .microphone)
    try await Task.sleep(for: .milliseconds(50))

    #expect(adapter.requestedPermissions == [.microphone])
    #expect(viewModel.snapshot.status == .ready)
    #expect(viewModel.snapshot.requiredPermissions.isEmpty)
}

@MainActor
@Test func viewModelReopensApplicationThroughAdapter() {
    let adapter = MockAppCoreAdapter(initialSnapshot: .permissionRequired)
    let viewModel = AppShellViewModel(adapter: adapter)

    viewModel.reopenApplication()

    #expect(adapter.reopenApplicationCallCount == 1)
}

@MainActor
@Test func requestingWindowWorkflowStoresPreviousSelectionAndEntersSelectingState() {
    let adapter = MockAppCoreAdapter(initialSnapshot: .ready)
    let viewModel = AppShellViewModel(adapter: adapter)

    let entered = viewModel.requestWindowRecordingWorkflow()

    #expect(entered == true)
    #expect(viewModel.windowRecordingWorkflow == .selectingWindow(previousMode: .display, previousTargetID: "display-1"))
    #expect(adapter.selectModes.isEmpty)
    #expect(adapter.selectTargetIDs.isEmpty)
}

@MainActor
@Test func selectingWindowTargetAppliesWindowModeAndShowsControlBarState() {
    let adapter = MockAppCoreAdapter(initialSnapshot: .ready)
    let viewModel = AppShellViewModel(adapter: adapter)

    _ = viewModel.requestWindowRecordingWorkflow()
    viewModel.selectWindowForRecording(targetID: "window-42")

    #expect(adapter.selectModes == [.window])
    #expect(adapter.selectTargetIDs == ["window-42"])
    #expect(viewModel.snapshot.mode == .window)
    #expect(viewModel.windowRecordingWorkflow == .configuringWindow(previousMode: .display, previousTargetID: "display-1", selectedTargetID: "window-42"))
}

@MainActor
@Test func cancelingWindowWorkflowRestoresPreviousSelection() {
    let adapter = MockAppCoreAdapter(initialSnapshot: .ready)
    let viewModel = AppShellViewModel(adapter: adapter)

    _ = viewModel.requestWindowRecordingWorkflow()
    viewModel.selectWindowForRecording(targetID: "window-42")
    viewModel.cancelWindowRecordingWorkflow()

    #expect(viewModel.windowRecordingWorkflow == .idle)
    #expect(viewModel.snapshot.mode == .display)
    #expect(viewModel.snapshot.selectedTarget.id == "display-1")
}

@MainActor
@Test func startingConfiguredWindowRecordingClearsWorkflowAndStartsRecording() {
    let adapter = MockAppCoreAdapter(initialSnapshot: .ready)
    let viewModel = AppShellViewModel(adapter: adapter)

    _ = viewModel.requestWindowRecordingWorkflow()
    viewModel.selectWindowForRecording(targetID: "window-42")
    viewModel.startConfiguredWindowRecording()

    #expect(viewModel.windowRecordingWorkflow == .idle)
    #expect(adapter.startRecordingCallCount == 1)
    #expect(viewModel.snapshot.status == .recording)
}

@MainActor
@Test func windowControlBarSettingsPersistThroughAdapter() {
    let adapter = MockAppCoreAdapter(initialSnapshot: .ready)
    let viewModel = AppShellViewModel(adapter: adapter)

    var settings = viewModel.snapshot.settings
    settings.videoCodec = .hevc
    settings.frameRate = .fps60
    viewModel.updateWindowControlBarSettings(settings)

    #expect(adapter.updatedSettings.map(\.videoCodec) == [.hevc])
    #expect(adapter.updatedSettings.map(\.frameRate) == [.fps60])
    #expect(viewModel.snapshot.settings.videoCodec == .hevc)
}

@MainActor
@Test func windowControlBarSettingsKeepConfiguredWindowTarget() {
    var snapshot = AppShellSnapshot.ready
    let secondWindow = SourceTargetOption(
        id: "window-99",
        mode: .window,
        source: .window(WindowID(rawValue: 99)),
        title: "Notes - Planning",
        subtitle: "Window recording target"
    )
    snapshot.availableTargets.append(secondWindow)
    let adapter = MockAppCoreAdapter(initialSnapshot: snapshot)
    let viewModel = AppShellViewModel(adapter: adapter)

    _ = viewModel.requestWindowRecordingWorkflow()
    viewModel.selectWindowForRecording(targetID: "window-99")
    var settings = viewModel.snapshot.settings
    settings.videoCodec = .hevc
    viewModel.updateWindowControlBarSettings(settings)

    #expect(adapter.updatedSettings.map(\.videoCodec) == [.hevc])
    #expect(adapter.selectTargetIDs == ["window-99", "window-99"])
    #expect(viewModel.snapshot.selectedTarget.id == "window-99")
}

@MainActor
@Test func applicationTargetsGroupWindowsByOwningApplicationName() {
    var snapshot = AppShellSnapshot.ready
    snapshot.availableTargets.append(contentsOf: [
        SourceTargetOption(
            id: "window-99",
            mode: .window,
            source: .window(WindowID(rawValue: 99)),
            title: "Safari - Release Notes",
            subtitle: "Window recording target"
        ),
        SourceTargetOption(
            id: "window-100",
            mode: .window,
            source: .window(WindowID(rawValue: 100)),
            title: "Xcode - OpenRec",
            subtitle: "Window recording target"
        )
    ])
    let viewModel = AppShellViewModel(adapter: MockAppCoreAdapter(initialSnapshot: snapshot))

    let applications = viewModel.applicationTargets

    #expect(applications.map(\.title) == ["Safari", "Xcode"])
    #expect(applications.first { $0.id == "Safari" }?.windows.map(\.id) == ["window-42", "window-99"])
}

@MainActor
@Test func applicationRecordingWorkflowSelectsApplicationBeforeSpecificWindow() {
    var snapshot = AppShellSnapshot.ready
    snapshot.availableTargets.append(SourceTargetOption(
        id: "window-99",
        mode: .window,
        source: .window(WindowID(rawValue: 99)),
        title: "Xcode - OpenRec",
        subtitle: "Window recording target"
    ))
    let adapter = MockAppCoreAdapter(initialSnapshot: snapshot)
    let viewModel = AppShellViewModel(adapter: adapter)

    let entered = viewModel.requestApplicationRecordingWorkflow()
    viewModel.selectApplicationForRecording(applicationName: "Xcode")
    viewModel.selectWindowForRecording(targetID: "window-99")

    #expect(entered == true)
    #expect(adapter.selectModes == [.window])
    #expect(adapter.selectTargetIDs == ["window-99"])
    #expect(viewModel.windowRecordingWorkflow == .configuringWindow(previousMode: .display, previousTargetID: "display-1", selectedTargetID: "window-99"))
    #expect(viewModel.snapshot.selectedTarget.id == "window-99")
}

@MainActor
@Test func applicationRecordingWorkflowRejectsWindowFromDifferentApplication() {
    var snapshot = AppShellSnapshot.ready
    snapshot.availableTargets.append(SourceTargetOption(
        id: "window-99",
        mode: .window,
        source: .window(WindowID(rawValue: 99)),
        title: "Xcode - OpenRec",
        subtitle: "Window recording target"
    ))
    let adapter = MockAppCoreAdapter(initialSnapshot: snapshot)
    let viewModel = AppShellViewModel(adapter: adapter)

    _ = viewModel.requestApplicationRecordingWorkflow()
    viewModel.selectApplicationForRecording(applicationName: "Xcode")
    viewModel.selectWindowForRecording(targetID: "window-42")

    #expect(adapter.selectModes.isEmpty)
    #expect(adapter.selectTargetIDs.isEmpty)
    #expect(viewModel.windowRecordingWorkflow == .selectingApplicationWindow(previousMode: .display, previousTargetID: "display-1", applicationName: "Xcode"))
    #expect(viewModel.snapshot.selectedTarget.id == "display-1")
}

@MainActor
@Test func viewModelExposesSaveFlowActionsOnlyWhileAwaitingSave() {
    let adapter = MockAppCoreAdapter(initialSnapshot: .awaitingSave)
    let viewModel = AppShellViewModel(adapter: adapter)

    #expect(viewModel.canSaveRecording == true)
    #expect(viewModel.canRetrySave == true)
    #expect(viewModel.canDiscardRecording == true)
    #expect(viewModel.canStartRecording == false)

    viewModel.retrySave()
    #expect(adapter.retrySaveCallCount == 1)

    let saveAdapter = MockAppCoreAdapter(initialSnapshot: .awaitingSave)
    let saveViewModel = AppShellViewModel(adapter: saveAdapter)
    saveViewModel.saveRecording()
    #expect(saveAdapter.saveRecordingCallCount == 1)
    #expect(saveViewModel.snapshot.status == .ready)

    let discardAdapter = MockAppCoreAdapter(initialSnapshot: .awaitingSave)
    let discardViewModel = AppShellViewModel(adapter: discardAdapter)
    discardViewModel.discardRecording()
    #expect(discardAdapter.discardRecordingCallCount == 1)
    #expect(discardViewModel.snapshot.status == .ready)
}

@MainActor
@Test func saveFlowActionsIgnoreNonAwaitingSaveSnapshots() {
    let adapter = MockAppCoreAdapter(initialSnapshot: .ready)
    let viewModel = AppShellViewModel(adapter: adapter)

    viewModel.retrySave()
    viewModel.saveRecording()
    viewModel.discardRecording()

    #expect(adapter.retrySaveCallCount == 0)
    #expect(adapter.saveRecordingCallCount == 0)
    #expect(adapter.discardRecordingCallCount == 0)
    #expect(viewModel.canSaveRecording == false)
    #expect(viewModel.canRetrySave == false)
    #expect(viewModel.canDiscardRecording == false)
}

@Test func sourceSummaryUsesCoreCaptureSource() {
    let snapshot = AppShellSnapshot.ready

    #expect(snapshot.selectedTarget.source == .display(DisplayID(rawValue: 1)))
    #expect(snapshot.selectedTarget.summary == "Built-in Display")
}

@Test func userVisibleMockDataDoesNotExposeDevelopmentLanguage() {
    let forbiddenTerms = ["Mock", "boundary", "will host", "will present"]
    let snapshots = AppShellSnapshot.mockScenarios

    let visibleStrings = snapshots.flatMap { snapshot in
        var strings = [
            snapshot.status.title,
            snapshot.status.detail,
            snapshot.selectedTarget.title,
            snapshot.selectedTarget.subtitle,
            snapshot.selectedMicrophone.title,
            snapshot.selectedMicrophone.subtitle
        ]
        strings.append(contentsOf: snapshot.availableTargets.flatMap { [$0.title, $0.subtitle] })
        strings.append(contentsOf: snapshot.microphones.flatMap { [$0.title, $0.subtitle] })
        strings.append(contentsOf: snapshot.errorMessage.map { [$0] } ?? [])
        return strings
    }

    for string in visibleStrings {
        for term in forbiddenTerms {
            #expect(!string.localizedCaseInsensitiveContains(term))
        }
    }
}

@Test func permissionDisplayItemsUsePermissionStatusSnapshot() {
    var snapshot = AppShellSnapshot.ready
    snapshot.permissionStatuses[.microphone] = .notDetermined
    snapshot.requiredPermissions = []

    let microphoneItem = PermissionDisplayItem.items(for: snapshot).first {
        $0.kind == .microphone
    }

    #expect(microphoneItem?.isGranted == false)
}

@MainActor
@Test func productionAdapterBuildsSnapshotFromCoreSettingsSourcesAudioAndPermissions() async throws {
    let settingsDirectory = temporarySettingsDirectory()
    let settingsStore = SettingsStore(settingsDirectory: settingsDirectory)
    try settingsStore.save(AppSettings(
        schemaVersion: 1,
        recording: RecordingSettings(
            defaultMode: .window,
            outputFormat: .mov,
            videoCodec: .hevc,
            qualityPreset: .high,
            frameRate: .fps60,
            includeCursor: false,
            microphoneDeviceID: "mic-2",
            audioPreset: .high,
            globalHotkey: nil
        )
    ))

    let adapter = OpenRecAppCoreAdapter(
        settingsStore: settingsStore,
        captureSourceProvider: InMemoryCaptureSourceProvider(
            displays: [
                DisplaySourceMetadata(
                    id: DisplayID(rawValue: 10),
                    name: "Main Display",
                    pixelSize: CGSize(width: 3024, height: 1964),
                    isAvailable: true
                )
            ],
            windows: [
                WindowSourceMetadata(
                    id: WindowID(rawValue: 99),
                    title: "Notes",
                    owningApplicationName: "TextEdit",
                    pixelSize: CGSize(width: 1280, height: 720),
                    screenFrame: CGRect(x: 80, y: 120, width: 640, height: 360),
                    isAvailable: true
                )
            ]
        ),
        audioDeviceProvider: InMemoryAudioDeviceProvider(devices: [
            MicrophoneDevice(id: "mic-1", name: "Built-in Microphone", isDefault: true),
            MicrophoneDevice(id: "mic-2", name: "Studio Microphone", isDefault: false)
        ]),
        permissionChecker: PermissionChecker(provider: InMemoryPermissionStatusProvider(
            statuses: Dictionary(uniqueKeysWithValues: PermissionKind.allCases.map { ($0, .granted) })
        )),
        hotkeyManager: HotkeyManager(registry: InMemoryHotkeyRegistry())
    )

    let snapshot = await adapter.refresh()

    #expect(snapshot.status == .ready)
    #expect(snapshot.mode == .display)
    #expect(snapshot.selectedTarget.source == .display(DisplayID(rawValue: 10)))
    #expect(snapshot.selectedTarget.title == "Main Display")
    #expect(snapshot.selectedTarget.subtitle == "3024 x 1964, original resolution")
    #expect(snapshot.selectedTarget.screenFrame == nil)
    #expect(snapshot.availableTargets.map(\.source) == [
        .display(DisplayID(rawValue: 10)),
        .window(WindowID(rawValue: 99))
    ])
    #expect(snapshot.selectedMicrophoneID == "mic-2")
    #expect(snapshot.selectedMicrophone.title == "Studio Microphone")
    #expect(snapshot.settings.outputFormat == .mov)
    #expect(snapshot.settings.videoCodec == .hevc)
    #expect(snapshot.requiredPermissions.isEmpty)
}

@MainActor
@Test func productionAdapterRegistersSavedHotkeyFromSettingsOnStartup() throws {
    let hotkey = Hotkey(keyCode: 49, modifiers: [.command, .shift])
    let settingsStore = SettingsStore(settingsDirectory: temporarySettingsDirectory())
    try settingsStore.save(AppSettings(
        schemaVersion: 1,
        recording: RecordingSettings(
            defaultMode: .display,
            outputFormat: .mp4,
            videoCodec: .h264,
            qualityPreset: .standard,
            frameRate: .fps30,
            includeCursor: true,
            microphoneDeviceID: nil,
            audioPreset: .standard,
            globalHotkey: hotkey
        )
    ))
    let registry = InMemoryHotkeyRegistry()
    let adapter = OpenRecAppCoreAdapter(
        settingsStore: settingsStore,
        captureSourceProvider: InMemoryCaptureSourceProvider(displays: [], windows: []),
        audioDeviceProvider: InMemoryAudioDeviceProvider(devices: []),
        permissionChecker: PermissionChecker(provider: InMemoryPermissionStatusProvider(statuses: [:])),
        hotkeyManager: HotkeyManager(registry: registry, savedHotkey: hotkey)
    )

    let snapshot = adapter.registerSavedHotkey()

    #expect(registry.contains(hotkey))
    #expect(snapshot.settings.globalHotkey == hotkey)
    #expect(snapshot.errorMessage == "Choose an available display or window.")
}

@MainActor
@Test func productionAdapterRegistrationFailureClearsPersistedHotkeyAndShowsError() throws {
    let hotkey = Hotkey(keyCode: 49, modifiers: [.command, .shift])
    let settingsStore = SettingsStore(settingsDirectory: temporarySettingsDirectory())
    try settingsStore.save(AppSettings(
        schemaVersion: 1,
        recording: RecordingSettings(
            defaultMode: .display,
            outputFormat: .mp4,
            videoCodec: .h264,
            qualityPreset: .standard,
            frameRate: .fps30,
            includeCursor: true,
            microphoneDeviceID: nil,
            audioPreset: .standard,
            globalHotkey: hotkey
        )
    ))
    let registry = InMemoryHotkeyRegistry(
        registrationFailure: .registrationFailed("system rejected hotkey")
    )
    let adapter = OpenRecAppCoreAdapter(
        settingsStore: settingsStore,
        captureSourceProvider: InMemoryCaptureSourceProvider(displays: [], windows: []),
        audioDeviceProvider: InMemoryAudioDeviceProvider(devices: []),
        permissionChecker: PermissionChecker(provider: InMemoryPermissionStatusProvider(statuses: [:])),
        hotkeyManager: HotkeyManager(registry: registry, savedHotkey: hotkey)
    )

    let snapshot = adapter.registerSavedHotkey()
    let persistedSettings = try settingsStore.load().recording

    #expect(snapshot.status == .error)
    #expect(snapshot.errorMessage == "OpenRec could not register the global shortcut.")
    #expect(snapshot.settings.globalHotkey == nil)
    #expect(persistedSettings.globalHotkey == nil)
    #expect(registry.contains(hotkey) == false)
}

@MainActor
@Test func productionAdapterKeepsHotkeyRegistrationFailureVisibleAfterRefresh() async throws {
    let hotkey = Hotkey(keyCode: 49, modifiers: [.command, .shift])
    let settingsStore = SettingsStore(settingsDirectory: temporarySettingsDirectory())
    try settingsStore.save(AppSettings(
        schemaVersion: 1,
        recording: RecordingSettings(
            defaultMode: .display,
            outputFormat: .mp4,
            videoCodec: .h264,
            qualityPreset: .standard,
            frameRate: .fps30,
            includeCursor: true,
            microphoneDeviceID: nil,
            audioPreset: .standard,
            globalHotkey: hotkey
        )
    ))
    let adapter = OpenRecAppCoreAdapter(
        settingsStore: settingsStore,
        captureSourceProvider: InMemoryCaptureSourceProvider(
            displays: [
                DisplaySourceMetadata(
                    id: DisplayID(rawValue: 1),
                    name: "Main Display",
                    pixelSize: CGSize(width: 1920, height: 1080),
                    isAvailable: true
                )
            ],
            windows: []
        ),
        audioDeviceProvider: InMemoryAudioDeviceProvider(devices: [
            MicrophoneDevice(id: "mic-1", name: "Built-in Microphone", isDefault: true)
        ]),
        permissionChecker: PermissionChecker(provider: InMemoryPermissionStatusProvider(
            statuses: Dictionary(uniqueKeysWithValues: PermissionKind.allCases.map { ($0, .granted) })
        )),
        hotkeyManager: HotkeyManager(
            registry: InMemoryHotkeyRegistry(
                registrationFailure: .registrationFailed("system rejected hotkey")
            ),
            savedHotkey: hotkey
        )
    )

    _ = adapter.registerSavedHotkey()
    let refreshedSnapshot = await adapter.refresh()

    #expect(refreshedSnapshot.status == .error)
    #expect(refreshedSnapshot.errorMessage == "OpenRec could not register the global shortcut.")
    #expect(refreshedSnapshot.settings.globalHotkey == nil)
}

@MainActor
@Test func productionAdapterMapsCoreAwaitingSaveToAppSaveFlowSnapshot() async {
    let pendingURL = URL(filePath: "/tmp/openrec-finalized.mp4")
    let adapter = awaitingSaveAdapter(pendingURL: pendingURL)

    let snapshot = await adapter.refresh()

    #expect(snapshot.status == .awaitingSave)
    #expect(snapshot.pendingSaveURL == pendingURL)
    #expect(snapshot.errorMessage == nil)
}

@MainActor
@Test func productionAdapterSaveRetryAndDiscardRespectAwaitingSaveBoundary() async {
    let pendingURL = URL(filePath: "/tmp/openrec-finalized.mp4")
    let finalizer = NoOpTemporaryRecordingFinalizer()
    let adapter = awaitingSaveAdapter(
        pendingURL: pendingURL,
        finalizer: finalizer,
        savePanel: StubRecordingSavePanel(destinationURL: URL(filePath: "/tmp/openrec-saved.mp4"))
    )

    _ = await adapter.refresh()
    let retrySnapshot = adapter.retrySave()
    let savedSnapshot = adapter.saveRecording()

    #expect(retrySnapshot.status == .awaitingSave)
    #expect(retrySnapshot.errorMessage == "Choose a save location or discard the recording.")
    #expect(savedSnapshot.status == .ready)
    #expect(savedSnapshot.pendingSaveURL == nil)

    let discardAdapter = awaitingSaveAdapter(pendingURL: pendingURL, finalizer: finalizer)

    _ = await discardAdapter.refresh()
    let discardedSnapshot = discardAdapter.discardRecording()

    #expect(discardedSnapshot.status == .ready)
    #expect(discardedSnapshot.pendingSaveURL == nil)
    #expect(finalizer.discardedURLs == [pendingURL])
}

@MainActor
@Test func productionAdapterSaveRecordingMovesPendingFileBeforeMarkSaved() async {
    let pendingURL = URL(filePath: "/tmp/openrec-finalized.mp4")
    let destinationURL = URL(filePath: "/Users/test/Desktop/openrec-finalized.mp4")
    let savePanel = StubRecordingSavePanel(destinationURL: destinationURL)
    let fileMover = SpyRecordingFileMover()
    let adapter = awaitingSaveAdapter(
        pendingURL: pendingURL,
        savePanel: savePanel,
        fileMover: fileMover
    )

    _ = await adapter.refresh()
    let snapshot = adapter.saveRecording()

    #expect(savePanel.defaultFileNames == ["openrec-finalized.mp4"])
    #expect(fileMover.moves == [
        RecordedFileMove(sourceURL: pendingURL, destinationURL: destinationURL)
    ])
    #expect(snapshot.status == .ready)
    #expect(snapshot.pendingSaveURL == nil)
    #expect(snapshot.errorMessage == nil)
}

@MainActor
@Test func viewModelStopsProductionRecordingAndPromptsForSave() async {
    let destinationURL = URL(filePath: "/Users/test/Desktop/openrec-finalized.mp4")
    let savePanel = StubRecordingSavePanel(destinationURL: destinationURL)
    let fileMover = SpyRecordingFileMover()
    let adapter = recordingAdapter(savePanel: savePanel, fileMover: fileMover)
    let viewModel = AppShellViewModel(adapter: adapter)

    await viewModel.refresh()
    viewModel.stopRecording()

    #expect(savePanel.defaultFileNames == ["openrec-finalized.mp4"])
    #expect(fileMover.moves == [
        RecordedFileMove(
            sourceURL: URL(filePath: "/tmp/openrec-finalized.mp4"),
            destinationURL: destinationURL
        )
    ])
    #expect(viewModel.snapshot.status == .ready)
    #expect(viewModel.snapshot.pendingSaveURL == nil)
}

@MainActor
@Test func productionAdapterSaveRecordingCancelDiscardsTemporaryRecordingAndReturnsReady() async {
    let pendingURL = URL(filePath: "/tmp/openrec-finalized.mov")
    let finalizer = NoOpTemporaryRecordingFinalizer()
    let savePanel = StubRecordingSavePanel(destinationURL: nil)
    let fileMover = SpyRecordingFileMover()
    let adapter = awaitingSaveAdapter(
        pendingURL: pendingURL,
        finalizer: finalizer,
        savePanel: savePanel,
        fileMover: fileMover
    )

    _ = await adapter.refresh()
    let snapshot = adapter.saveRecording()

    #expect(savePanel.defaultFileNames == ["openrec-finalized.mov"])
    #expect(fileMover.moves.isEmpty)
    #expect(finalizer.discardedURLs == [pendingURL])
    #expect(snapshot.status == .ready)
    #expect(snapshot.pendingSaveURL == nil)
    #expect(snapshot.errorMessage == nil)
}

@MainActor
@Test func productionAdapterSaveRecordingMoveFailureDoesNotMarkSavedAndShowsError() async {
    let pendingURL = URL(filePath: "/tmp/openrec-finalized.mp4")
    let destinationURL = URL(filePath: "/Users/test/Desktop/openrec-finalized.mp4")
    let savePanel = StubRecordingSavePanel(destinationURL: destinationURL)
    let fileMover = SpyRecordingFileMover(error: TestSaveMoveError())
    let adapter = awaitingSaveAdapter(
        pendingURL: pendingURL,
        savePanel: savePanel,
        fileMover: fileMover
    )

    _ = await adapter.refresh()
    let snapshot = adapter.saveRecording()

    #expect(fileMover.moves == [
        RecordedFileMove(sourceURL: pendingURL, destinationURL: destinationURL)
    ])
    #expect(snapshot.status == .awaitingSave)
    #expect(snapshot.pendingSaveURL == pendingURL)
    #expect(snapshot.errorMessage?.isEmpty == false)
}

@MainActor
@Test func productionAdapterSaveRecordingIsNoOpOutsideAwaitingSave() async {
    let savePanel = StubRecordingSavePanel(destinationURL: URL(filePath: "/Users/test/Desktop/openrec-finalized.mp4"))
    let fileMover = SpyRecordingFileMover()
    let adapter = OpenRecAppCoreAdapter(
        settingsStore: SettingsStore(settingsDirectory: temporarySettingsDirectory()),
        captureSourceProvider: InMemoryCaptureSourceProvider(
            displays: [
                DisplaySourceMetadata(
                    id: DisplayID(rawValue: 1),
                    name: "Main Display",
                    pixelSize: CGSize(width: 1920, height: 1080),
                    isAvailable: true
                )
            ],
            windows: []
        ),
        audioDeviceProvider: InMemoryAudioDeviceProvider(devices: [
            MicrophoneDevice(id: "mic-1", name: "Built-in Microphone", isDefault: true)
        ]),
        permissionChecker: PermissionChecker(provider: InMemoryPermissionStatusProvider(
            statuses: Dictionary(uniqueKeysWithValues: PermissionKind.allCases.map { ($0, .granted) })
        )),
        hotkeyManager: HotkeyManager(registry: InMemoryHotkeyRegistry()),
        savePanel: savePanel,
        fileMover: fileMover
    )

    _ = await adapter.refresh()
    let snapshot = adapter.saveRecording()

    #expect(savePanel.defaultFileNames.isEmpty)
    #expect(fileMover.moves.isEmpty)
    #expect(snapshot.status == .ready)
    #expect(snapshot.pendingSaveURL == nil)
}

@MainActor
private func recordingAdapter(
    savePanel: StubRecordingSavePanel = StubRecordingSavePanel(
        destinationURL: URL(filePath: "/Users/test/Desktop/openrec-finalized.mp4")
    ),
    fileMover: SpyRecordingFileMover = SpyRecordingFileMover()
) -> OpenRecAppCoreAdapter {
    let session = RecordingSession(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000321")!,
        source: .display(DisplayID(rawValue: 1)),
        temporaryFileURL: URL(filePath: "/tmp/openrec-recording.tmp")
    )
    return OpenRecAppCoreAdapter(
        settingsStore: SettingsStore(settingsDirectory: temporarySettingsDirectory()),
        captureSourceProvider: InMemoryCaptureSourceProvider(
            displays: [
                DisplaySourceMetadata(
                    id: DisplayID(rawValue: 1),
                    name: "Main Display",
                    pixelSize: CGSize(width: 1920, height: 1080),
                    isAvailable: true
                )
            ],
            windows: []
        ),
        audioDeviceProvider: InMemoryAudioDeviceProvider(devices: [
            MicrophoneDevice(id: "mic-1", name: "Built-in Microphone", isDefault: true)
        ]),
        permissionChecker: PermissionChecker(provider: InMemoryPermissionStatusProvider(
            statuses: Dictionary(uniqueKeysWithValues: PermissionKind.allCases.map { ($0, .granted) })
        )),
        hotkeyManager: HotkeyManager(registry: InMemoryHotkeyRegistry()),
        recordingCoordinator: RecordingCoordinator(
            permissionValidator: NoOpRecordingPermissionValidator(),
            configurationResolver: NoOpRecordingConfigurationResolver(),
            engine: NoOpRecordingEngine(),
            finalizer: NoOpTemporaryRecordingFinalizer(),
            initialState: .recording(session)
        ),
        savePanel: savePanel,
        fileMover: fileMover
    )
}

@MainActor
private func awaitingSaveAdapter(
    pendingURL: URL,
    finalizer: NoOpTemporaryRecordingFinalizer = NoOpTemporaryRecordingFinalizer(),
    savePanel: StubRecordingSavePanel = StubRecordingSavePanel(
        destinationURL: URL(filePath: "/Users/test/Desktop/openrec-finalized.mp4")
    ),
    fileMover: SpyRecordingFileMover = SpyRecordingFileMover()
) -> OpenRecAppCoreAdapter {
    OpenRecAppCoreAdapter(
        settingsStore: SettingsStore(settingsDirectory: temporarySettingsDirectory()),
        captureSourceProvider: InMemoryCaptureSourceProvider(
            displays: [
                DisplaySourceMetadata(
                    id: DisplayID(rawValue: 1),
                    name: "Main Display",
                    pixelSize: CGSize(width: 1920, height: 1080),
                    isAvailable: true
                )
            ],
            windows: []
        ),
        audioDeviceProvider: InMemoryAudioDeviceProvider(devices: [
            MicrophoneDevice(id: "mic-1", name: "Built-in Microphone", isDefault: true)
        ]),
        permissionChecker: PermissionChecker(provider: InMemoryPermissionStatusProvider(
            statuses: Dictionary(uniqueKeysWithValues: PermissionKind.allCases.map { ($0, .granted) })
        )),
        hotkeyManager: HotkeyManager(registry: InMemoryHotkeyRegistry()),
        recordingCoordinator: RecordingCoordinator(
            permissionValidator: NoOpRecordingPermissionValidator(),
            configurationResolver: NoOpRecordingConfigurationResolver(),
            engine: NoOpRecordingEngine(),
            finalizer: finalizer,
            initialState: .awaitingSave(pendingURL)
        ),
        savePanel: savePanel,
        fileMover: fileMover
    )
}

@MainActor
@Test func productionAdapterInitialSnapshotDoesNotExposeMockTargets() {
    let adapter = OpenRecAppCoreAdapter(
        settingsStore: SettingsStore(settingsDirectory: temporarySettingsDirectory()),
        captureSourceProvider: InMemoryCaptureSourceProvider(displays: [], windows: []),
        audioDeviceProvider: InMemoryAudioDeviceProvider(devices: []),
        permissionChecker: PermissionChecker(provider: InMemoryPermissionStatusProvider(statuses: [:])),
        hotkeyManager: HotkeyManager(registry: InMemoryHotkeyRegistry())
    )

    #expect(adapter.snapshot.availableTargets.isEmpty)
    #expect(adapter.snapshot.selectedTarget.title == "No Source Selected")
}

@MainActor
@Test func productionAdapterReflectsPermissionSnapshotInMenuStatus() async {
    let adapter = OpenRecAppCoreAdapter(
        settingsStore: SettingsStore(settingsDirectory: temporarySettingsDirectory()),
        captureSourceProvider: InMemoryCaptureSourceProvider(
            displays: [
                DisplaySourceMetadata(
                    id: DisplayID(rawValue: 1),
                    name: "Main Display",
                    pixelSize: CGSize(width: 1920, height: 1080),
                    isAvailable: true
                )
            ],
            windows: []
        ),
        audioDeviceProvider: InMemoryAudioDeviceProvider(devices: [
            MicrophoneDevice(id: "mic-1", name: "Built-in Microphone", isDefault: true)
        ]),
        permissionChecker: PermissionChecker(provider: InMemoryPermissionStatusProvider(
            statuses: [
                .screenRecording: .denied,
                .microphone: .granted,
                .accessibility: .granted,
                .inputMonitoring: .granted
            ]
        )),
        hotkeyManager: HotkeyManager(registry: InMemoryHotkeyRegistry())
    )

    let snapshot = await adapter.refresh()

    #expect(snapshot.status == .permissionRequired)
    #expect(snapshot.requiredPermissions == [.screenRecording])
    #expect(snapshot.permissionStatuses[.screenRecording] == .denied)
}

@MainActor
@Test func productionAdapterSkipsSourceDiscoveryWhenRequiredPermissionsAreMissing() async {
    let adapter = OpenRecAppCoreAdapter(
        settingsStore: SettingsStore(settingsDirectory: temporarySettingsDirectory()),
        captureSourceProvider: FailingCaptureSourceProvider(),
        audioDeviceProvider: InMemoryAudioDeviceProvider(devices: []),
        permissionChecker: PermissionChecker(provider: InMemoryPermissionStatusProvider(
            statuses: [
                .screenRecording: .denied,
                .microphone: .granted,
                .accessibility: .granted,
                .inputMonitoring: .granted
            ]
        )),
        hotkeyManager: HotkeyManager(registry: InMemoryHotkeyRegistry())
    )

    let snapshot = await adapter.refresh()

    #expect(snapshot.status == .permissionRequired)
    #expect(snapshot.requiredPermissions == [.screenRecording])
    #expect(snapshot.errorMessage == nil)
}

@MainActor
@Test func productionAdapterDoesNotBlockCurrentRecordingForOptionalSystemPermissions() async {
    let adapter = OpenRecAppCoreAdapter(
        settingsStore: SettingsStore(settingsDirectory: temporarySettingsDirectory()),
        captureSourceProvider: InMemoryCaptureSourceProvider(
            displays: [
                DisplaySourceMetadata(
                    id: DisplayID(rawValue: 1),
                    name: "Main Display",
                    pixelSize: CGSize(width: 1920, height: 1080),
                    isAvailable: true
                )
            ],
            windows: []
        ),
        audioDeviceProvider: InMemoryAudioDeviceProvider(devices: [
            MicrophoneDevice(id: "mic-1", name: "Built-in Microphone", isDefault: true)
        ]),
        permissionChecker: PermissionChecker(provider: InMemoryPermissionStatusProvider(
            statuses: [
                .screenRecording: .granted,
                .microphone: .granted,
                .accessibility: .denied,
                .inputMonitoring: .denied
            ]
        )),
        hotkeyManager: HotkeyManager(registry: InMemoryHotkeyRegistry())
    )

    let snapshot = await adapter.refresh()

    #expect(snapshot.status == .ready)
    #expect(snapshot.requiredPermissions.isEmpty)
    #expect(snapshot.permissionStatuses[.accessibility] == .denied)
    #expect(snapshot.permissionStatuses[.inputMonitoring] == .denied)
}

@MainActor
@Test func productionAdapterOpensSystemSettingsForPermissionKind() {
    let opener = SpySystemSettingsOpener()
    let adapter = OpenRecAppCoreAdapter(
        settingsStore: SettingsStore(settingsDirectory: temporarySettingsDirectory()),
        captureSourceProvider: InMemoryCaptureSourceProvider(displays: [], windows: []),
        audioDeviceProvider: InMemoryAudioDeviceProvider(devices: []),
        permissionChecker: PermissionChecker(provider: InMemoryPermissionStatusProvider(statuses: [:])),
        hotkeyManager: HotkeyManager(registry: InMemoryHotkeyRegistry()),
        systemSettingsOpener: opener
    )

    _ = adapter.openPermissionSettings(for: .microphone)

    #expect(opener.openedPermissionKinds == [.microphone])
}

@MainActor
@Test func productionAdapterRechecksPermissionsWithoutReloadingSettingsStore() async throws {
    let provider = MutablePermissionStatusProvider(statuses: [
        .screenRecording: .denied,
        .microphone: .granted,
        .accessibility: .granted,
        .inputMonitoring: .granted
    ])
    let settingsDirectory = temporarySettingsDirectory()
    let settingsStore = SettingsStore(settingsDirectory: settingsDirectory)
    let adapter = OpenRecAppCoreAdapter(
        settingsStore: settingsStore,
        captureSourceProvider: InMemoryCaptureSourceProvider(
            displays: [
                DisplaySourceMetadata(
                    id: DisplayID(rawValue: 1),
                    name: "Main Display",
                    pixelSize: CGSize(width: 1920, height: 1080),
                    isAvailable: true
                )
            ],
            windows: []
        ),
        audioDeviceProvider: InMemoryAudioDeviceProvider(devices: [
            MicrophoneDevice(id: "mic-1", name: "Built-in Microphone", isDefault: true)
        ]),
        permissionChecker: PermissionChecker(provider: provider),
        hotkeyManager: HotkeyManager(registry: InMemoryHotkeyRegistry())
    )

    _ = await adapter.refresh()
    provider.statuses[.screenRecording] = .granted
    let snapshot = await adapter.refresh()

    #expect(snapshot.status == .ready)
    #expect(snapshot.requiredPermissions.isEmpty)
    #expect(snapshot.permissionStatuses[.screenRecording] == .granted)
    #expect(try settingsStore.load().recording == .defaults)
}

@MainActor
@Test func productionAdapterRequestPermissionRefreshesSnapshotAndOpensSettings() async throws {
    let provider = MutablePermissionStatusProvider(statuses: [
        .screenRecording: .granted,
        .microphone: .denied,
        .accessibility: .granted,
        .inputMonitoring: .granted
    ])
    let requester = SpyPermissionRequester { kind in
        if kind == .microphone {
            provider.statuses[.microphone] = .granted
        }
    }
    let opener = SpySystemSettingsOpener()
    let adapter = OpenRecAppCoreAdapter(
        settingsStore: SettingsStore(settingsDirectory: temporarySettingsDirectory()),
        captureSourceProvider: InMemoryCaptureSourceProvider(
            displays: [
                DisplaySourceMetadata(
                    id: DisplayID(rawValue: 1),
                    name: "Main Display",
                    pixelSize: CGSize(width: 1920, height: 1080),
                    isAvailable: true
                )
            ],
            windows: []
        ),
        audioDeviceProvider: InMemoryAudioDeviceProvider(devices: [
            MicrophoneDevice(id: "mic-1", name: "Built-in Microphone", isDefault: true)
        ]),
        permissionChecker: PermissionChecker(provider: provider),
        hotkeyManager: HotkeyManager(registry: InMemoryHotkeyRegistry()),
        systemSettingsOpener: opener,
        permissionRequester: requester
    )

    _ = await adapter.refresh()
    let snapshot = await adapter.requestPermission(for: .microphone)

    #expect(requester.requestedPermissionKinds == [.microphone])
    #expect(opener.openedPermissionKinds == [.microphone])
    #expect(snapshot.status == .ready)
    #expect(snapshot.requiredPermissions.isEmpty)
    #expect(snapshot.permissionStatuses[.microphone] == .granted)
}

@Test func systemSettingsPermissionURLsTargetExpectedPrivacyPanes() {
    #expect(SystemSettingsPermissionPane.url(for: .screenRecording).absoluteString.contains("Privacy_ScreenCapture"))
    #expect(SystemSettingsPermissionPane.url(for: .microphone).absoluteString.contains("Privacy_Microphone"))
    #expect(SystemSettingsPermissionPane.url(for: .accessibility).absoluteString.contains("Privacy_Accessibility"))
    #expect(SystemSettingsPermissionPane.url(for: .inputMonitoring).absoluteString.contains("Privacy_ListenEvent"))

    for kind in PermissionKind.allCases {
        #expect(SystemSettingsPermissionPane.url(for: kind).scheme == "x-apple.systempreferences")
        #expect(!SystemSettingsPermissionPane.url(for: kind).absoluteString.hasPrefix("http"))
    }
}

@MainActor
@Test func productionAdapterStartsRecordingWithInjectedDefaultEngine() async {
    let engine = NoOpRecordingEngine()
    let adapter = OpenRecAppCoreAdapter(
        settingsStore: SettingsStore(settingsDirectory: temporarySettingsDirectory()),
        captureSourceProvider: InMemoryCaptureSourceProvider(
            displays: [
                DisplaySourceMetadata(
                    id: DisplayID(rawValue: 1),
                    name: "Main Display",
                    pixelSize: CGSize(width: 1920, height: 1080),
                    isAvailable: true
                )
            ],
            windows: []
        ),
        audioDeviceProvider: InMemoryAudioDeviceProvider(devices: [
            MicrophoneDevice(id: "mic-1", name: "Built-in Microphone", isDefault: true)
        ]),
        permissionChecker: PermissionChecker(provider: InMemoryPermissionStatusProvider(
            statuses: Dictionary(uniqueKeysWithValues: PermissionKind.allCases.map { ($0, .granted) })
        )),
        hotkeyManager: HotkeyManager(registry: InMemoryHotkeyRegistry()),
        recordingEngine: engine
    )

    _ = await adapter.refresh()
    let snapshot = adapter.startRecording()

    #expect(snapshot.status == .recording)
    #expect(snapshot.errorMessage == nil)
    #expect(engine.startedConfigurations.map(\.source) == [.display(DisplayID(rawValue: 1))])
}

@MainActor
@Test func productionAdapterDoesNotPersistWindowSelectionAsDefaultMode() async throws {
    let settingsDirectory = temporarySettingsDirectory()
    let settingsStore = SettingsStore(settingsDirectory: settingsDirectory)
    let adapter = OpenRecAppCoreAdapter(
        settingsStore: settingsStore,
        captureSourceProvider: InMemoryCaptureSourceProvider(
            displays: [
                DisplaySourceMetadata(
                    id: DisplayID(rawValue: 1),
                    name: "Main Display",
                    pixelSize: CGSize(width: 1920, height: 1080),
                    isAvailable: true
                )
            ],
            windows: [
                WindowSourceMetadata(
                    id: WindowID(rawValue: 7),
                    title: "Document",
                    owningApplicationName: "Pages",
                    pixelSize: CGSize(width: 1200, height: 900),
                    isAvailable: true
                )
            ]
        ),
        audioDeviceProvider: InMemoryAudioDeviceProvider(devices: [
            MicrophoneDevice(id: "mic-1", name: "Built-in Microphone", isDefault: true),
            MicrophoneDevice(id: "mic-2", name: "Studio Microphone", isDefault: false)
        ]),
        permissionChecker: PermissionChecker(provider: InMemoryPermissionStatusProvider(
            statuses: Dictionary(uniqueKeysWithValues: PermissionKind.allCases.map { ($0, .granted) })
        )),
        hotkeyManager: HotkeyManager(registry: InMemoryHotkeyRegistry())
    )

    _ = await adapter.refresh()
    _ = adapter.selectMode(.window)
    _ = adapter.selectMicrophone(id: "mic-2")

    let settings = try settingsStore.load().recording
    #expect(settings.defaultMode == .display)
    #expect(settings.microphoneDeviceID == "mic-2")
}

@MainActor
@Test func viewModelPersistsVideoPreferencePresetChanges() async throws {
    let settingsDirectory = temporarySettingsDirectory()
    let settingsStore = SettingsStore(settingsDirectory: settingsDirectory)
    let adapter = editablePreferencesAdapter(settingsStore: settingsStore)
    let viewModel = AppShellViewModel(adapter: adapter)

    await viewModel.refresh()
    var settings = viewModel.snapshot.settings
    settings.outputFormat = .mov
    settings.videoCodec = .hevc
    settings.frameRate = .fps60
    settings.qualityPreset = .high

    viewModel.updateSettings(settings)

    let persistedSettings = try settingsStore.load().recording
    #expect(persistedSettings.outputFormat == .mov)
    #expect(persistedSettings.videoCodec == .hevc)
    #expect(persistedSettings.frameRate == .fps60)
    #expect(persistedSettings.qualityPreset == .high)
    #expect(viewModel.snapshot.settings.outputFormat == .mov)
    #expect(viewModel.snapshot.settings.videoCodec == .hevc)
    #expect(viewModel.snapshot.settings.frameRate == .fps60)
    #expect(viewModel.snapshot.settings.qualityPreset == .high)
}

@MainActor
@Test func viewModelAlwaysKeepsDisplayAsDefaultRecordingSource() async throws {
    let settingsDirectory = temporarySettingsDirectory()
    let settingsStore = SettingsStore(settingsDirectory: settingsDirectory)
    let adapter = editablePreferencesAdapter(settingsStore: settingsStore)
    let viewModel = AppShellViewModel(adapter: adapter)

    await viewModel.refresh()
    var settings = viewModel.snapshot.settings
    settings.defaultMode = .window
    settings.includeCursor = false

    viewModel.updateSettings(settings)

    let persistedSettings = try settingsStore.load().recording
    #expect(persistedSettings.defaultMode == .display)
    #expect(persistedSettings.includeCursor == false)
    #expect(viewModel.snapshot.mode == .display)
    #expect(viewModel.snapshot.selectedTarget.source == .display(DisplayID(rawValue: 1)))
    #expect(viewModel.snapshot.settings.defaultMode == .display)
    #expect(viewModel.snapshot.settings.includeCursor == false)
}

@MainActor
@Test func viewModelPersistsMicrophoneAndAudioPresetPreferenceChanges() async throws {
    let settingsDirectory = temporarySettingsDirectory()
    let settingsStore = SettingsStore(settingsDirectory: settingsDirectory)
    let adapter = editablePreferencesAdapter(settingsStore: settingsStore)
    let viewModel = AppShellViewModel(adapter: adapter)

    await viewModel.refresh()
    var settings = viewModel.snapshot.settings
    settings.microphoneDeviceID = "mic-2"
    settings.audioPreset = .high

    viewModel.updateSettings(settings)

    let persistedSettings = try settingsStore.load().recording
    #expect(persistedSettings.microphoneDeviceID == "mic-2")
    #expect(persistedSettings.audioPreset == .high)
    #expect(viewModel.snapshot.selectedMicrophoneID == "mic-2")
    #expect(viewModel.snapshot.selectedMicrophone.title == "Studio Microphone")
    #expect(viewModel.snapshot.settings.audioPreset == .high)
}

@MainActor
@Test func viewModelSettingsSaveFailureKeepsSnapshotSettingsUnchangedAndShowsError() async {
    let settingsDirectory = temporarySettingsDirectory()
    let settingsStore = SettingsStore(settingsDirectory: settingsDirectory)
    let adapter = editablePreferencesAdapter(settingsStore: settingsStore)
    let viewModel = AppShellViewModel(adapter: adapter)

    await viewModel.refresh()
    let originalSnapshot = viewModel.snapshot
    try? FileManager.default.removeItem(at: settingsDirectory)
    try? Data().write(to: settingsDirectory)

    var settings = viewModel.snapshot.settings
    settings.outputFormat = .mov
    settings.videoCodec = .hevc
    settings.frameRate = .fps60
    settings.qualityPreset = .high
    viewModel.updateSettings(settings)

    #expect(viewModel.snapshot.settings == originalSnapshot.settings)
    #expect(viewModel.snapshot.selectedTarget == originalSnapshot.selectedTarget)
    #expect(viewModel.snapshot.selectedMicrophoneID == originalSnapshot.selectedMicrophoneID)
    #expect(viewModel.snapshot.errorMessage?.isEmpty == false)
}

@MainActor
@Test func viewModelRefreshesFromAdapterSnapshot() async {
    let adapter = OpenRecAppCoreAdapter(
        settingsStore: SettingsStore(settingsDirectory: temporarySettingsDirectory()),
        captureSourceProvider: InMemoryCaptureSourceProvider(
            displays: [
                DisplaySourceMetadata(
                    id: DisplayID(rawValue: 2),
                    name: "External Display",
                    pixelSize: CGSize(width: 2560, height: 1440),
                    isAvailable: true
                )
            ],
            windows: []
        ),
        audioDeviceProvider: InMemoryAudioDeviceProvider(devices: [
            MicrophoneDevice(id: "mic-1", name: "Built-in Microphone", isDefault: true)
        ]),
        permissionChecker: PermissionChecker(provider: InMemoryPermissionStatusProvider(
            statuses: Dictionary(uniqueKeysWithValues: PermissionKind.allCases.map { ($0, .granted) })
        )),
        hotkeyManager: HotkeyManager(registry: InMemoryHotkeyRegistry())
    )
    let viewModel = AppShellViewModel(adapter: adapter)

    await viewModel.refresh()

    #expect(viewModel.snapshot.selectedTarget.source == .display(DisplayID(rawValue: 2)))
    #expect(viewModel.snapshot.selectedTarget.title == "External Display")
}

@MainActor
private func editablePreferencesAdapter(settingsStore: SettingsStore) -> OpenRecAppCoreAdapter {
    OpenRecAppCoreAdapter(
        settingsStore: settingsStore,
        captureSourceProvider: InMemoryCaptureSourceProvider(
            displays: [
                DisplaySourceMetadata(
                    id: DisplayID(rawValue: 1),
                    name: "Main Display",
                    pixelSize: CGSize(width: 1920, height: 1080),
                    isAvailable: true
                )
            ],
            windows: [
                WindowSourceMetadata(
                    id: WindowID(rawValue: 7),
                    title: "Document",
                    owningApplicationName: "Pages",
                    pixelSize: CGSize(width: 1200, height: 900),
                    isAvailable: true
                )
            ]
        ),
        audioDeviceProvider: InMemoryAudioDeviceProvider(devices: [
            MicrophoneDevice(id: "mic-1", name: "Built-in Microphone", isDefault: true),
            MicrophoneDevice(id: "mic-2", name: "Studio Microphone", isDefault: false)
        ]),
        permissionChecker: PermissionChecker(provider: InMemoryPermissionStatusProvider(
            statuses: Dictionary(uniqueKeysWithValues: PermissionKind.allCases.map { ($0, .granted) })
        )),
        hotkeyManager: HotkeyManager(registry: InMemoryHotkeyRegistry())
    )
}

private func temporarySettingsDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appending(path: "OpenRecAppTests")
        .appending(path: UUID().uuidString)
}

private struct NoOpRecordingPermissionValidator: RecordingPermissionValidating {
    func validateRecordingPermissions() throws {}
}

private struct NoOpRecordingConfigurationResolver: RecordingConfigurationResolving {
    func resolve(
        source: CaptureSource,
        settings: RecordingSettings
    ) throws -> ResolvedRecordingConfiguration {
        ResolvedRecordingConfiguration(
            source: source,
            pixelSize: CGSize(width: 1920, height: 1080),
            outputFormat: .mp4,
            videoCodec: .h264,
            bitrate: 7_464_960,
            frameRate: 30,
            includeCursor: true,
            microphoneDeviceID: nil
        )
    }
}

private final class NoOpRecordingEngine: RecordingEngine, @unchecked Sendable {
    private(set) var startedConfigurations: [ResolvedRecordingConfiguration] = []
    private(set) var stoppedSessions: [RecordingSession] = []

    func start(configuration: ResolvedRecordingConfiguration) throws -> RecordingSession {
        startedConfigurations.append(configuration)
        return RecordingSession(
            id: UUID(),
            source: configuration.source,
            temporaryFileURL: URL(filePath: "/tmp/openrec-recording.tmp")
        )
    }

    func stop(session: RecordingSession) throws -> URL {
        stoppedSessions.append(session)
        return URL(filePath: "/tmp/openrec-finalized.mp4")
    }
}

private final class NoOpTemporaryRecordingFinalizer: TemporaryRecordingFinalizing, @unchecked Sendable {
    private(set) var discardedURLs: [URL] = []

    func discardTemporaryRecording(at url: URL) throws {
        discardedURLs.append(url)
    }
}

private struct RecordedFileMove: Equatable {
    var sourceURL: URL
    var destinationURL: URL
}

@MainActor
private final class StubRecordingSavePanel: RecordingSavePanelPresenting {
    private let destinationURL: URL?
    private(set) var defaultFileNames: [String] = []

    init(destinationURL: URL?) {
        self.destinationURL = destinationURL
    }

    func destinationURL(defaultFileName: String) -> URL? {
        defaultFileNames.append(defaultFileName)
        return destinationURL
    }
}

private final class SpyRecordingFileMover: RecordingFileMoving {
    private let error: (any Error)?
    private(set) var moves: [RecordedFileMove] = []

    init(error: (any Error)? = nil) {
        self.error = error
    }

    func moveRecording(from sourceURL: URL, to destinationURL: URL) throws {
        moves.append(RecordedFileMove(sourceURL: sourceURL, destinationURL: destinationURL))
        if let error {
            throw error
        }
    }
}

private struct TestSaveMoveError: Error {}

private struct FailingCaptureSourceProvider: CaptureSourceProvider {
    func displays() async throws -> [DisplaySourceMetadata] {
        throw OpenRecError.unknown("source discovery should not run before required permissions are granted")
    }

    func windows() async throws -> [WindowSourceMetadata] {
        throw OpenRecError.unknown("source discovery should not run before required permissions are granted")
    }
}

@MainActor
private final class SpyPermissionRequester: PermissionRequesting {
    private(set) var requestedPermissionKinds: [PermissionKind] = []
    private let onRequest: (PermissionKind) -> Void

    init(onRequest: @escaping (PermissionKind) -> Void = { _ in }) {
        self.onRequest = onRequest
    }

    func requestPermission(for kind: PermissionKind) async {
        requestedPermissionKinds.append(kind)
        onRequest(kind)
    }
}

@MainActor
private final class SpySystemSettingsOpener: SystemSettingsOpening {
    private(set) var openedPermissionKinds: [PermissionKind] = []

    func openPermissionSettings(for kind: PermissionKind) {
        openedPermissionKinds.append(kind)
    }
}

private final class MutablePermissionStatusProvider: PermissionStatusProvider, @unchecked Sendable {
    var statuses: [PermissionKind: PermissionStatus]

    init(statuses: [PermissionKind: PermissionStatus]) {
        self.statuses = statuses
    }

    func status(for kind: PermissionKind) -> PermissionStatus {
        statuses[kind] ?? .unknown
    }
}
