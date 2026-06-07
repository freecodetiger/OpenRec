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
@Test func startRecordingRequiresPermissionsBeforeRecording() {
    let adapter = MockAppCoreAdapter(initialSnapshot: .permissionRequired)
    let viewModel = AppShellViewModel(adapter: adapter)

    viewModel.startRecording()

    #expect(viewModel.snapshot.status == .permissionRequired)
    #expect(viewModel.canStartRecording == false)
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
    #expect(snapshot.mode == .window)
    #expect(snapshot.selectedTarget.source == .window(WindowID(rawValue: 99)))
    #expect(snapshot.selectedTarget.title == "TextEdit - Notes")
    #expect(snapshot.selectedTarget.subtitle == "1280 x 720, original resolution")
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
@Test func productionAdapterSaveRecordingCancelKeepsAwaitingSaveAndPendingURL() async {
    let pendingURL = URL(filePath: "/tmp/openrec-finalized.mov")
    let savePanel = StubRecordingSavePanel(destinationURL: nil)
    let fileMover = SpyRecordingFileMover()
    let adapter = awaitingSaveAdapter(
        pendingURL: pendingURL,
        savePanel: savePanel,
        fileMover: fileMover
    )

    _ = await adapter.refresh()
    let snapshot = adapter.saveRecording()

    #expect(savePanel.defaultFileNames == ["openrec-finalized.mov"])
    #expect(fileMover.moves.isEmpty)
    #expect(snapshot.status == .awaitingSave)
    #expect(snapshot.pendingSaveURL == pendingURL)
    #expect(snapshot.errorMessage == "Choose a save location or discard the recording.")
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
@Test func productionAdapterStartReturnsClearDisabledRecordingError() async {
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
        hotkeyManager: HotkeyManager(registry: InMemoryHotkeyRegistry())
    )

    _ = await adapter.refresh()
    let snapshot = adapter.startRecording()

    #expect(snapshot.status == .error)
    #expect(snapshot.errorMessage == "Recording is currently unavailable.")
}

@MainActor
@Test func productionAdapterPersistsMenuSelectionsThroughSettingsStore() async throws {
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
    #expect(settings.defaultMode == .window)
    #expect(settings.microphoneDeviceID == "mic-2")
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

private struct NoOpRecordingEngine: RecordingEngine {
    func start(configuration: ResolvedRecordingConfiguration) throws -> RecordingSession {
        RecordingSession(
            id: UUID(),
            source: configuration.source,
            temporaryFileURL: URL(filePath: "/tmp/openrec-recording.tmp")
        )
    }

    func stop(session: RecordingSession) throws -> URL {
        URL(filePath: "/tmp/openrec-finalized.mp4")
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
