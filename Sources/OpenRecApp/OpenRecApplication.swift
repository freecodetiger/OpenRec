import AppKit
import SwiftUI

@main
struct OpenRecApplication: App {
    @StateObject private var viewModel: AppShellViewModel

    init() {
        _viewModel = StateObject(wrappedValue: AppShellViewModel(adapter: MockAppCoreAdapter()))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView(viewModel: viewModel)
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
            SaveFlowView(snapshot: viewModel.snapshot)
        }
        .defaultSize(width: 520, height: 320)
    }
}
