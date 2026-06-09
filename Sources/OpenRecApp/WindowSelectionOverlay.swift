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

struct WindowSelectionTargetPresentation: Equatable {
    var showsCardContent = false
    var fillOpacity: Double
    var strokeOpacity: Double
    var lineWidth: CGFloat
    var cornerRadius: CGFloat

    init(isHighlighted: Bool) {
        fillOpacity = isHighlighted ? 0.08 : 0
        strokeOpacity = isHighlighted ? 1 : 0
        lineWidth = isHighlighted ? 4 : 1
        cornerRadius = 10
    }
}

struct WindowSelectionOverlayLayout: Equatable {
    static func panelFrames(for screenFrames: [CGRect], fallbackFrame: CGRect = .zero) -> [CGRect] {
        let frames = screenFrames.filter { !$0.isEmpty }
        if !frames.isEmpty {
            return frames
        }

        return fallbackFrame.isEmpty ? [] : [fallbackFrame]
    }
}

struct WindowScreenFrameConverter: Equatable {
    struct DisplayFrame: Equatable {
        var appKitFrame: CGRect
        var coreGraphicsFrame: CGRect
    }

    var displays: [DisplayFrame]

    init(displays: [DisplayFrame]) {
        self.displays = displays
    }

    @MainActor
    init(screens: [NSScreen] = NSScreen.screens) {
        displays = screens.compactMap { screen in
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return nil
            }

            return DisplayFrame(
                appKitFrame: screen.frame,
                coreGraphicsFrame: CGDisplayBounds(displayID)
            )
        }
    }

    func appKitFrame(fromScreenCaptureKitFrame frame: CGRect?) -> CGRect? {
        guard let frame, !frame.isEmpty else { return frame }
        guard let display = display(containing: frame) else { return frame }

        return CGRect(
            x: display.appKitFrame.minX + (frame.minX - display.coreGraphicsFrame.minX),
            y: display.appKitFrame.maxY - (frame.maxY - display.coreGraphicsFrame.minY),
            width: frame.width,
            height: frame.height
        )
    }

    private func display(containing frame: CGRect) -> DisplayFrame? {
        let midpoint = CGPoint(x: frame.midX, y: frame.midY)
        return displays.first { $0.coreGraphicsFrame.contains(midpoint) } ??
            displays.first { !$0.coreGraphicsFrame.intersection(frame).isNull }
    }
}

@MainActor
final class WindowSelectionOverlayPresenter {
    private var windows: [NSWindow] = []

    func present(
        targets: [SourceTargetOption],
        onSelect: @escaping @MainActor (String) -> Void,
        onCancel: @escaping @MainActor () -> Void
    ) {
        dismiss()

        let panelFrames = WindowSelectionOverlayLayout.panelFrames(
            for: NSScreen.screens.map(\.frame),
            fallbackFrame: NSScreen.main?.frame ?? .zero
        )

        windows = panelFrames.map { overlayScreenFrame in
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
            overlayWindow.orderFrontRegardless()
            return overlayWindow
        }

        windows.first?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        windows.forEach { $0.close() }
        windows = []
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
        let presentation = WindowSelectionTargetPresentation(isHighlighted: isHighlighted)

        return RoundedRectangle(cornerRadius: presentation.cornerRadius)
            .fill(Color.accentColor.opacity(presentation.fillOpacity))
            .overlay {
                RoundedRectangle(cornerRadius: presentation.cornerRadius)
                    .stroke(Color.accentColor.opacity(presentation.strokeOpacity), lineWidth: presentation.lineWidth)
            }
            .frame(width: frame.width, height: frame.height, alignment: .topLeading)
            .shadow(color: Color.accentColor.opacity(isHighlighted ? 0.24 : 0), radius: isHighlighted ? 16 : 0)
            .position(x: frame.midX, y: frame.midY)
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.12), value: isHighlighted)
    }

}
