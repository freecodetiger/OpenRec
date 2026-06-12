import AppKit
import SwiftUI

@main
struct OpenRecApplication: App {
    @Environment(\.openWindow) private var openWindow
    @StateObject private var viewModel: AppShellViewModel
    @StateObject private var statusItemController: AppKitStatusItemController
    @StateObject private var windowRecordingWorkflowCoordinator: WindowRecordingWorkflowCoordinator
    @State private var onboardingPresentationGate = OnboardingWindowPresentationGate()
    private let onboardingWindowPresenter = UserWindowPresenter()

    init() {
        let adapter: AppShellAdapter
        do {
            adapter = try OpenRecAppCoreAdapter()
        } catch {
            var snapshot = AppShellSnapshot.error
            snapshot.errorMessage = "OpenRec could not load local settings."
            adapter = MockAppCoreAdapter(initialSnapshot: snapshot)
        }
        let model = AppShellViewModel(adapter: adapter)
        model.startHotkeyMonitoring()
        let workflowCoordinator = WindowRecordingWorkflowCoordinator(viewModel: model)
        model.onRecordingStoppedBeforeSave = { [weak workflowCoordinator] in
            workflowCoordinator?.dismissActivePanels()
        }
        let statusController = AppKitStatusItemController(viewModel: model)
        workflowCoordinator.closeMenu = { [weak statusController] in
            statusController?.closePopover()
            NSApp.keyWindow?.close()
        }
        statusController.onRequestWindowRecordingWorkflow = { [weak workflowCoordinator] in
            workflowCoordinator?.begin()
        }
        statusController.onRequestApplicationRecordingWorkflow = { [weak workflowCoordinator] in
            workflowCoordinator?.beginApplication()
        }
        DispatchQueue.main.async {
            statusController.installIfNeeded()
            Task {
                await AppLaunchRefresher(
                    viewModel: model,
                    statusSymbolRefresher: statusController
                ).refreshAfterLaunch()
            }
        }
        _viewModel = StateObject(wrappedValue: model)
        _statusItemController = StateObject(wrappedValue: statusController)
        _windowRecordingWorkflowCoordinator = StateObject(wrappedValue: workflowCoordinator)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView(
                viewModel: viewModel,
                onRequestWindowRecordingWorkflow: windowRecordingWorkflowCoordinator.begin,
                onRequestApplicationRecordingWorkflow: windowRecordingWorkflowCoordinator.beginApplication,
                onCloseMenu: windowRecordingWorkflowCoordinator.closeMenu
            )
                .task {
                    await viewModel.refresh()
                }
        } label: {
            Label("OpenRec", systemImage: viewModel.menuBarSymbolName)
        }
        .menuBarExtraStyle(.window)
        .onChange(of: viewModel.snapshot.status, initial: true) { oldStatus, newStatus in
            statusItemController.refreshSymbol()
            switch (oldStatus, newStatus) {
            case (_, .recording):
                windowRecordingWorkflowCoordinator.recordingDidStart()
            case (.recording, _), (_, .permissionRequired), (_, .error):
                windowRecordingWorkflowCoordinator.dismissActivePanels()
            default:
                break
            }
            onboardingPresentationGate.presentIfNeeded(
                for: viewModel.snapshot,
                presenter: onboardingWindowPresenter
            ) {
                openWindow(id: "onboarding")
            }
        }
        .onChange(of: viewModel.displaySelectionPresentationRequestCount) { oldCount, newCount in
            guard newCount > oldCount else { return }
            statusItemController.closePopover()
            openWindow(id: "source-selection")
        }
        .onChange(of: viewModel.windowSelectionPresentationRequestCount) { oldCount, newCount in
            guard newCount > oldCount else { return }
            statusItemController.closePopover()
            windowRecordingWorkflowCoordinator.presentWindowSelectionForCurrentWorkflow()
        }

        Window("Preferences", id: "preferences") {
            PreferencesView(
                snapshot: viewModel.snapshot,
                onSettingsChange: viewModel.updateSettings,
                onLanguageChange: viewModel.updateAppLanguage,
                onOpenPermissionSettings: viewModel.openPermissionSettings,
                onRequestPermission: viewModel.requestPermission,
                onRefreshPermissions: viewModel.refreshPermissions,
                onRefreshAudioLevel: viewModel.refreshAudioLevel
            )
        }
        .defaultSize(width: 760, height: 560)

        Window("Onboarding", id: "onboarding") {
            OnboardingView(
                snapshot: viewModel.snapshot,
                onOpenPermissionSettings: viewModel.openPermissionSettings,
                onRequestPermission: viewModel.requestPermission,
                onRefreshPermissions: viewModel.refreshPermissions
            )
        }
        .defaultSize(width: 560, height: 460)

        WindowGroup("Source Selection", id: "source-selection") {
            SourceSelectionView(viewModel: viewModel)
        }
        .defaultSize(width: 520, height: 380)

        WindowGroup("Save Recording", id: "save-flow") {
            SaveFlowView(
                snapshot: viewModel.snapshot,
                onSave: viewModel.saveRecording,
                onDiscard: viewModel.discardRecording
            )
        }
        .defaultSize(width: 520, height: 320)
    }
}
