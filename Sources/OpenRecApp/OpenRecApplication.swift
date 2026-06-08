import AppKit
import SwiftUI

@main
struct OpenRecApplication: App {
    @StateObject private var viewModel: AppShellViewModel
    @StateObject private var statusItemController: AppKitStatusItemController

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
        _viewModel = StateObject(wrappedValue: model)
        _statusItemController = StateObject(wrappedValue: AppKitStatusItemController(viewModel: model))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView(viewModel: viewModel)
                .task {
                    await viewModel.refresh()
                }
        } label: {
            Label("OpenRec", systemImage: viewModel.menuBarSymbolName)
        }
        .menuBarExtraStyle(.window)
        .onChange(of: viewModel.snapshot.status) { _, _ in
            statusItemController.refreshSymbol()
        }

        WindowGroup("Preferences", id: "preferences") {
            PreferencesView(
                snapshot: viewModel.snapshot,
                onSettingsChange: viewModel.updateSettings,
                onOpenPermissionSettings: viewModel.openPermissionSettings,
                onRefreshPermissions: viewModel.refreshPermissions
            )
        }
        .defaultSize(width: 560, height: 520)

        WindowGroup("Onboarding", id: "onboarding") {
            OnboardingView(
                snapshot: viewModel.snapshot,
                onOpenPermissionSettings: viewModel.openPermissionSettings,
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
