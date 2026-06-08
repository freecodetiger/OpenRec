import AppKit
import Foundation

@MainActor
final class WindowRecordingWorkflowCoordinator: ObservableObject {
    var closeMenu: () -> Void = {}

    private let viewModel: AppShellViewModel
    private let selectionPresenter: WindowSelectionOverlayPresenter
    private let controlBarPresenter: WindowRecordingControlBarPresenter
    private let applicationSelectionPresenter: ApplicationSelectionPanelPresenter

    init(
        viewModel: AppShellViewModel,
        selectionPresenter: WindowSelectionOverlayPresenter = WindowSelectionOverlayPresenter(),
        controlBarPresenter: WindowRecordingControlBarPresenter = WindowRecordingControlBarPresenter(),
        applicationSelectionPresenter: ApplicationSelectionPanelPresenter = ApplicationSelectionPanelPresenter()
    ) {
        self.viewModel = viewModel
        self.selectionPresenter = selectionPresenter
        self.controlBarPresenter = controlBarPresenter
        self.applicationSelectionPresenter = applicationSelectionPresenter
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

    func beginApplication() {
        closeMenu()
        let applications = viewModel.applicationTargets
        guard !applications.isEmpty else {
            showAlert(
                messageText: "No Recordable Applications",
                informativeText: "Open an application window and try Application Recording again."
            )
            return
        }
        guard viewModel.requestApplicationRecordingWorkflow() else { return }

        applicationSelectionPresenter.present(
            applications: applications,
            onSelectApplication: { [weak self] applicationID in
                self?.selectApplication(applicationID: applicationID)
            },
            onCancel: { [weak self] in
                self?.viewModel.cancelWindowRecordingWorkflow()
            }
        )
    }

    func dismissActivePanels() {
        selectionPresenter.dismiss()
        controlBarPresenter.dismiss()
        applicationSelectionPresenter.dismiss()
    }

    private func selectApplication(applicationID: String) {
        viewModel.selectApplicationForRecording(applicationName: applicationID)
        guard case let .selectingApplicationWindow(_, _, applicationName) = viewModel.windowRecordingWorkflow,
              let application = viewModel.applicationTargets.first(where: { $0.id == applicationName }) else {
            return
        }

        selectionPresenter.present(
            targets: application.windows,
            onSelect: { [weak self] targetID in
                self?.selectWindow(targetID: targetID)
            },
            onCancel: { [weak self] in
                self?.viewModel.cancelWindowRecordingWorkflow()
            }
        )
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
        showAlert(
            messageText: "No Recordable Windows",
            informativeText: "Open a window and try Window Recording again."
        )
    }

    private func showAlert(messageText: String, informativeText: String) {
        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = informativeText
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
