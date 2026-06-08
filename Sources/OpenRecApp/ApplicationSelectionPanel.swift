import AppKit
import SwiftUI

@MainActor
final class ApplicationSelectionPanelPresenter {
    private var panel: NSPanel?

    func present(
        applications: [ApplicationTargetOption],
        onSelectApplication: @escaping @MainActor (String) -> Void,
        onCancel: @escaping @MainActor () -> Void
    ) {
        dismiss()

        let panel = ApplicationSelectionPanel(
            contentRect: Self.panelFrame(),
            onCancel: { [weak self] in
                self?.dismiss()
                onCancel()
            }
        )
        panel.contentView = NSHostingView(
            rootView: ApplicationSelectionView(
                applications: applications,
                onSelectApplication: { [weak self] applicationID in
                    self?.dismiss()
                    onSelectApplication(applicationID)
                },
                onCancel: { [weak self] in
                    self?.dismiss()
                    onCancel()
                }
            )
        )
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = panel
    }

    func dismiss() {
        panel?.close()
        panel = nil
    }

    private static func panelFrame() -> CGRect {
        let visibleFrame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 900, height: 700)
        let size = CGSize(width: min(460, visibleFrame.width - 48), height: min(420, visibleFrame.height - 48))
        return CGRect(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}

private struct ApplicationSelectionView: View {
    var applications: [ApplicationTargetOption]
    var onSelectApplication: @MainActor (String) -> Void
    var onCancel: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "square.stack.3d.up")
                    .font(.title2)
                Text("Choose Application")
                    .font(.headline)
                Spacer()
            }

            List(applications) { application in
                Button {
                    onSelectApplication(application.id)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "app.dashed")
                            .frame(width: 24)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(application.title)
                            Text(application.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(18)
        .frame(minWidth: 360, minHeight: 320)
        .background(.regularMaterial)
    }
}

private final class ApplicationSelectionPanel: NSPanel {
    private let onCancel: @MainActor () -> Void

    init(
        contentRect: CGRect,
        onCancel: @escaping @MainActor () -> Void
    ) {
        self.onCancel = onCancel
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        title = "Choose Application"
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel()
            return
        }

        super.keyDown(with: event)
    }
}
