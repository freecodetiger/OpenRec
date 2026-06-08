import AppKit
import SwiftUI

@main
struct OpenRecApplication: App {
    @StateObject private var viewModel: AppShellViewModel
    @StateObject private var statusItemController: AppKitStatusItemController
    @StateObject private var windowRecordingWorkflowCoordinator: WindowRecordingWorkflowCoordinator

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
        let statusController = AppKitStatusItemController(viewModel: model)
        workflowCoordinator.closeMenu = { [weak statusController] in
            statusController?.closePopover()
            NSApp.keyWindow?.close()
        }
        statusController.onRequestWindowRecordingWorkflow = { [weak workflowCoordinator] in
            workflowCoordinator?.begin()
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
                onCloseMenu: windowRecordingWorkflowCoordinator.closeMenu
            )
                .task {
                    await viewModel.refresh()
                }
        } label: {
            Label("OpenRec", systemImage: viewModel.menuBarSymbolName)
        }
        .menuBarExtraStyle(.window)
        .onChange(of: viewModel.snapshot.status) { _, _ in
            statusItemController.refreshSymbol()
            if viewModel.snapshot.status != .ready {
                windowRecordingWorkflowCoordinator.dismissActivePanels()
            }
        }

        WindowGroup("Preferences", id: "preferences") {
            PreferencesView(
                snapshot: viewModel.snapshot,
                onSettingsChange: viewModel.updateSettings,
                onOpenPermissionSettings: viewModel.openPermissionSettings,
                onRequestPermission: viewModel.requestPermission,
                onRefreshPermissions: viewModel.refreshPermissions
            )
        }
        .defaultSize(width: 560, height: 520)

        WindowGroup("Onboarding", id: "onboarding") {
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
                onRetrySave: viewModel.retrySave,
                onDiscard: viewModel.discardRecording
            )
        }
        .defaultSize(width: 520, height: 320)
    }
}
