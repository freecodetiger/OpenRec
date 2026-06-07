import AppKit
import SwiftUI

@main
struct OpenRecApplication: App {
    @StateObject private var viewModel: AppShellViewModel

    init() {
        let adapter: AppShellAdapter
        do {
            adapter = try OpenRecAppCoreAdapter()
        } catch {
            var snapshot = AppShellSnapshot.error
            snapshot.errorMessage = "OpenRec could not load local settings."
            adapter = MockAppCoreAdapter(initialSnapshot: snapshot)
        }
        _viewModel = StateObject(wrappedValue: AppShellViewModel(adapter: adapter))
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

        WindowGroup("Preferences", id: "preferences") {
            PreferencesView(snapshot: viewModel.snapshot)
        }
        .defaultSize(width: 560, height: 520)

        WindowGroup("Onboarding", id: "onboarding") {
            OnboardingView(snapshot: viewModel.snapshot)
        }
        .defaultSize(width: 560, height: 460)

        WindowGroup("Source Selection", id: "source-selection") {
            SourceSelectionView(snapshot: viewModel.snapshot)
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
