import AppKit
import SwiftUI
import OpenRecCore

struct WindowSelectionOverlayModel: Equatable {
    private(set) var targets: [SourceTargetOption]
    private(set) var highlightedTargetID: String?

    init(targets: [SourceTargetOption]) {
        self.targets = targets.filter { $0.mode == .window }
    }

    mutating func hover(targetID: String?) {
        guard let targetID,
              targets.contains(where: { $0.id == targetID }) else {
            highlightedTargetID = nil
            return
        }

        highlightedTargetID = targetID
    }

    mutating func click(targetID: String) -> String? {
        guard targets.contains(where: { $0.id == targetID }) else {
            return nil
        }

        highlightedTargetID = targetID
        return targetID
    }

    mutating func clickHighlightedTarget() -> String? {
        guard let highlightedTargetID else { return nil }
        return click(targetID: highlightedTargetID)
    }

    mutating func movePointer(
        to location: CGPoint,
        in viewSize: CGSize,
        overlayScreenFrame: CGRect
    ) {
        highlightedTargetID = targetID(
            at: location,
            in: viewSize,
            overlayScreenFrame: overlayScreenFrame
        )
    }

    mutating func cancel() -> String? {
        highlightedTargetID = nil
        return nil
    }

    func frame(
        for target: SourceTargetOption,
        index: Int,
        in viewSize: CGSize,
        overlayScreenFrame: CGRect
    ) -> CGRect {
        if let screenFrame = target.screenFrame, !screenFrame.isEmpty {
            return localFrame(for: screenFrame, in: viewSize, overlayScreenFrame: overlayScreenFrame)
        }

        return fallbackFrame(for: index, count: targets.count, in: viewSize)
    }

    private func targetID(
        at location: CGPoint,
        in viewSize: CGSize,
        overlayScreenFrame: CGRect
    ) -> String? {
        for (index, target) in targets.enumerated().reversed() {
            let frame = frame(
                for: target,
                index: index,
                in: viewSize,
                overlayScreenFrame: overlayScreenFrame
            )
            if frame.contains(location) {
                return target.id
            }
        }

        return nil
    }

    private func localFrame(
        for screenFrame: CGRect,
        in viewSize: CGSize,
        overlayScreenFrame: CGRect
    ) -> CGRect {
        guard !overlayScreenFrame.isEmpty else { return screenFrame }

        let scaleX = viewSize.width / overlayScreenFrame.width
        let scaleY = viewSize.height / overlayScreenFrame.height
        return CGRect(
            x: (screenFrame.minX - overlayScreenFrame.minX) * scaleX,
            y: (screenFrame.minY - overlayScreenFrame.minY) * scaleY,
            width: screenFrame.width * scaleX,
            height: screenFrame.height * scaleY
        )
    }

    private func fallbackFrame(for index: Int, count: Int, in size: CGSize) -> CGRect {
        let columns = max(1, min(3, count))
        let rows = max(1, Int(ceil(Double(count) / Double(columns))))
        let margin: CGFloat = 72
        let spacing: CGFloat = 24
        let availableWidth = max(320, size.width - margin * 2 - spacing * CGFloat(columns - 1))
        let availableHeight = max(220, size.height - margin * 2 - spacing * CGFloat(rows - 1))
        let width = min(420, availableWidth / CGFloat(columns))
        let height = min(240, max(160, availableHeight / CGFloat(rows)))
        let gridWidth = width * CGFloat(columns) + spacing * CGFloat(columns - 1)
        let gridHeight = height * CGFloat(rows) + spacing * CGFloat(rows - 1)
        let startX = (size.width - gridWidth) / 2
        let startY = (size.height - gridHeight) / 2
        let column = index % columns
        let row = index / columns

        return CGRect(
            x: startX + CGFloat(column) * (width + spacing),
            y: startY + CGFloat(row) * (height + spacing),
            width: width,
            height: height
        )
    }
}

@MainActor
final class WindowSelectionOverlayPresenter {
    private var window: NSWindow?

    func present(
        targets: [SourceTargetOption],
        onSelect: @escaping @MainActor (String) -> Void,
        onCancel: @escaping @MainActor () -> Void
    ) {
        dismiss()

        let overlayScreenFrame = WindowSelectionOverlayWindow.overlayFrame()
        let overlayWindow = WindowSelectionOverlayWindow(
            overlayFrame: overlayScreenFrame,
            onCancel: { [weak self] in
                self?.dismiss()
                onCancel()
            }
        )
        overlayWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        overlayWindow.contentView = NSHostingView(
            rootView: WindowSelectionOverlayView(
                targets: targets,
                overlayScreenFrame: overlayScreenFrame,
                onSelect: { [weak self] targetID in
                    self?.dismiss()
                    onSelect(targetID)
                },
                onCancel: { [weak self] in
                    self?.dismiss()
                    onCancel()
                }
            )
        )
        overlayWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = overlayWindow
    }

    func dismiss() {
        window?.close()
        window = nil
    }
}

private final class WindowSelectionOverlayWindow: NSPanel {
    private let onCancel: @MainActor () -> Void

    init(
        overlayFrame: CGRect,
        onCancel: @escaping @MainActor () -> Void
    ) {
        self.onCancel = onCancel
        super.init(
            contentRect: overlayFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        hidesOnDeactivate = false
        ignoresMouseEvents = false
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

    static func overlayFrame() -> CGRect {
        NSScreen.screens
            .map(\.frame)
            .reduce(NSScreen.main?.frame ?? .zero) { $0.union($1) }
    }
}

struct WindowSelectionOverlayView: View {
    @State private var model: WindowSelectionOverlayModel

    private let overlayScreenFrame: CGRect
    private let onSelect: @MainActor (String) -> Void
    private let onCancel: @MainActor () -> Void

    init(
        targets: [SourceTargetOption],
        overlayScreenFrame: CGRect,
        onSelect: @escaping @MainActor (String) -> Void,
        onCancel: @escaping @MainActor () -> Void
    ) {
        _model = State(initialValue: WindowSelectionOverlayModel(targets: targets))
        self.overlayScreenFrame = overlayScreenFrame
        self.onSelect = onSelect
        self.onCancel = onCancel
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture {
                    cancel()
                }

            GeometryReader { proxy in
                ZStack {
                    ForEach(Array(model.targets.enumerated()), id: \.element.id) { index, target in
                        let frame = model.frame(
                            for: target,
                            index: index,
                            in: proxy.size,
                            overlayScreenFrame: overlayScreenFrame
                        )
                        windowTarget(target, frame: frame)
                    }

                    trackingLayer(in: proxy)
                }
            }
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.escape) {
            cancel()
            return .handled
        }
    }

    func cancel() {
        _ = model.cancel()
        onCancel()
    }

    private func trackingLayer(in proxy: GeometryProxy) -> some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        model.movePointer(
                            to: value.location,
                            in: proxy.size,
                            overlayScreenFrame: overlayScreenFrame
                        )
                    }
                    .onEnded { value in
                        model.movePointer(
                            to: value.location,
                            in: proxy.size,
                            overlayScreenFrame: overlayScreenFrame
                        )
                        if let targetID = model.clickHighlightedTarget() {
                            onSelect(targetID)
                        } else {
                            cancel()
                        }
                    }
            )
            .onContinuousHover { phase in
                switch phase {
                case let .active(location):
                    model.movePointer(
                        to: location,
                        in: proxy.size,
                        overlayScreenFrame: overlayScreenFrame
                    )
                case .ended:
                    model.hover(targetID: nil)
                }
            }
    }

    private func windowTarget(_ target: SourceTargetOption, frame: CGRect) -> some View {
        let isHighlighted = model.highlightedTargetID == target.id

        return Button {
            if let targetID = model.click(targetID: target.id) {
                onSelect(targetID)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 18, weight: .semibold))
                    Text(target.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                }

                Text(target.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(14)
            .frame(width: frame.width, height: frame.height, alignment: .topLeading)
            .background(.regularMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHighlighted ? Color.accentColor : Color.white.opacity(0.7), lineWidth: isHighlighted ? 4 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(isHighlighted ? 0.28 : 0.16), radius: isHighlighted ? 20 : 10, y: 8)
            .scaleEffect(isHighlighted ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .position(x: frame.midX, y: frame.midY)
        .animation(.easeOut(duration: 0.12), value: isHighlighted)
    }

}
