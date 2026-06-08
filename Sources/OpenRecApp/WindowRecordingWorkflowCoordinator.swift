import AppKit
import Foundation

@MainActor
final class WindowRecordingWorkflowCoordinator: ObservableObject {
    var closeMenu: () -> Void = {}

    private let viewModel: AppShellViewModel
    private let selectionPresenter: WindowSelectionOverlayPresenter
    private let controlBarPresenter: WindowRecordingControlBarPresenter

    init(
        viewModel: AppShellViewModel,
        selectionPresenter: WindowSelectionOverlayPresenter = WindowSelectionOverlayPresenter(),
        controlBarPresenter: WindowRecordingControlBarPresenter = WindowRecordingControlBarPresenter()
    ) {
        self.viewModel = viewModel
        self.selectionPresenter = selectionPresenter
        self.controlBarPresenter = controlBarPresenter
    }

    func begin() {
        closeMenu()
        guard viewModel.snapshot.availableTargets.contains(where: { $0.mode == .window }) else {
            showNoWindowsAlert()
            return
        }
        guard viewModel.requestWindowRecordingWorkflow() else { return }

        selectionPresenter.present(
            targets: viewModel.snapshot.availableTargets,
            onSelect: { [weak self] targetID in
                self?.selectWindow(targetID: targetID)
            },
            onCancel: { [weak self] in
                self?.viewModel.cancelWindowRecordingWorkflow()
            }
        )
    }

    func dismissActivePanels() {
        selectionPresenter.dismiss()
        controlBarPresenter.dismiss()
    }

    private func selectWindow(targetID: String) {
        viewModel.selectWindowForRecording(targetID: targetID)
        guard case let .configuringWindow(_, _, selectedTargetID) = viewModel.windowRecordingWorkflow,
              let target = viewModel.snapshot.availableTargets.first(where: { $0.id == selectedTargetID }) else {
            return
        }

        controlBarPresenter.present(
            target: target,
            snapshot: viewModel.snapshot,
            onSettingsChange: { [weak self] settings in
                self?.viewModel.updateWindowControlBarSettings(settings)
            },
            onStart: { [weak self] in
                self?.viewModel.startConfiguredWindowRecording()
            },
            onCancel: { [weak self] in
                self?.viewModel.cancelWindowRecordingWorkflow()
            }
        )
    }

    private func showNoWindowsAlert() {
        let alert = NSAlert()
        alert.messageText = "No Recordable Windows"
        alert.informativeText = "Open a window and try Window Recording again."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
