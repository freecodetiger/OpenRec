import Foundation
import OpenRecCore
import Testing
@testable import OpenRecApp

@MainActor
@Test func sourceSelectionDraftShowsOnlyTargetsForTheCurrentMode() {
    var draft = SourceSelectionDraft(snapshot: .ready)

    #expect(draft.visibleTargets.map(\.id) == ["display-1", "display-2"])

    draft.selectMode(.window)

    #expect(draft.mode == .window)
    #expect(draft.visibleTargets.map(\.id) == ["window-42"])
    #expect(draft.selectedTargetID == "window-42")
}

@MainActor
@Test func sourceSelectionDraftCancelDoesNotChangeViewModelSelection() {
    let adapter = MockAppCoreAdapter(initialSnapshot: .ready)
    let viewModel = AppShellViewModel(adapter: adapter)
    var draft = SourceSelectionDraft(snapshot: viewModel.snapshot)

    draft.selectMode(.window)
    draft.selectTarget(id: "window-42")

    #expect(adapter.selectModes.isEmpty)
    #expect(adapter.selectTargetIDs.isEmpty)
    #expect(viewModel.snapshot.mode == .display)
    #expect(viewModel.snapshot.selectedTarget.id == "display-1")
}

@MainActor
@Test func applyingDisplayDraftUpdatesTargetThroughViewModel() {
    let adapter = MockAppCoreAdapter(initialSnapshot: .ready)
    let viewModel = AppShellViewModel(adapter: adapter)
    var draft = SourceSelectionDraft(snapshot: viewModel.snapshot)

    draft.selectTarget(id: "display-2")
    viewModel.applySourceSelection(draft)

    #expect(adapter.selectModes.isEmpty)
    #expect(adapter.selectTargetIDs == ["display-2"])
    #expect(viewModel.snapshot.mode == .display)
    #expect(viewModel.snapshot.selectedTarget.id == "display-2")
}

@MainActor
@Test func applyingWindowDraftUpdatesModeAndTargetThroughViewModel() {
    let adapter = MockAppCoreAdapter(initialSnapshot: .ready)
    let viewModel = AppShellViewModel(adapter: adapter)
    var draft = SourceSelectionDraft(snapshot: viewModel.snapshot)

    draft.selectMode(.window)
    draft.selectTarget(id: "window-42")
    viewModel.applySourceSelection(draft)

    #expect(adapter.selectModes == [.window])
    #expect(adapter.selectTargetIDs == ["window-42"])
    #expect(viewModel.snapshot.mode == .window)
    #expect(viewModel.snapshot.selectedTarget.id == "window-42")
    #expect(viewModel.snapshot.selectedTarget.title == "Safari - Product Brief")
}
