import AppKit
import SwiftUI

@MainActor
final class AppKitStatusItemController: NSObject, ObservableObject {
    private let viewModel: AppShellViewModel
    private var statusItem: NSStatusItem?
    private let popover: NSPopover
    var onRequestWindowRecordingWorkflow: (() -> Void)?

    init(viewModel: AppShellViewModel) {
        self.viewModel = viewModel
        self.popover = NSPopover()
        super.init()

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 340, height: 520)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPopoverView(
                viewModel: viewModel,
                onRequestWindowRecordingWorkflow: { [weak self] in
                    self?.onRequestWindowRecordingWorkflow?()
                },
                onCloseMenu: { [weak self] in
                    self?.closePopover()
                }
            )
                .task {
                    await viewModel.refresh()
                }
        )
    }

    func installIfNeeded() {
        guard statusItem == nil else { return }

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: viewModel.menuBarSymbolName, accessibilityDescription: "OpenRec")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        self.statusItem = statusItem
    }

    func refreshSymbol() {
        statusItem?.button?.image = NSImage(
            systemSymbolName: viewModel.menuBarSymbolName,
            accessibilityDescription: "OpenRec"
        )
    }

    func closePopover() {
        popover.performClose(nil)
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            refreshSymbol()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
