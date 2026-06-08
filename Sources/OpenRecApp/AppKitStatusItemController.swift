import AppKit
import SwiftUI

@MainActor
final class AppKitStatusItemController: NSObject, ObservableObject {
    private let viewModel: AppShellViewModel
    private let statusItem: NSStatusItem
    private let popover: NSPopover

    init(viewModel: AppShellViewModel) {
        self.viewModel = viewModel
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        super.init()

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 340, height: 520)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPopoverView(viewModel: viewModel)
                .task {
                    await viewModel.refresh()
                }
        )

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: viewModel.menuBarSymbolName, accessibilityDescription: "OpenRec")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    func refreshSymbol() {
        statusItem.button?.image = NSImage(
            systemSymbolName: viewModel.menuBarSymbolName,
            accessibilityDescription: "OpenRec"
        )
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
