import AppKit
import SwiftUI
import OpenRecCore

struct WindowSelectionOverlayModel: Equatable {
    private(set) var targets: [SourceTargetOption]
    private(set) var highlightedTargetID: String?
    private(set) var selectedTargetID: String?

    init(targets: [SourceTargetOption]) {
        let windowTargets = targets.filter { $0.mode == .window }
        let displayTargets = targets.filter { $0.mode == .display }
        self.targets = windowTargets + displayTargets
    }

    mutating func hover(targetID: String?) {
        guard selectedTargetID == nil else { return }
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

    mutating func lockSelection(targetID: String) -> String? {
        guard targets.contains(where: { $0.id == targetID }) else {
            return nil
        }

        selectedTargetID = targetID
        highlightedTargetID = targetID
        return targetID
    }

    mutating func movePointer(
        to location: CGPoint,
        in viewSize: CGSize,
        overlayScreenFrame: CGRect
    ) {
        guard selectedTargetID == nil else { return }
        highlightedTargetID = targetID(
            at: location,
            in: viewSize,
            overlayScreenFrame: overlayScreenFrame
        )
    }

    mutating func cancel() -> String? {
        highlightedTargetID = nil
        selectedTargetID = nil
        return nil
    }

    func frame(
        for target: SourceTargetOption,
        index: Int,
        in viewSize: CGSize,
        overlayScreenFrame: CGRect
    ) -> CGRect? {
        if let screenFrame = target.screenFrame, !screenFrame.isEmpty {
            return localFrame(for: screenFrame, in: viewSize, overlayScreenFrame: overlayScreenFrame)
        }

        if target.mode == .display {
            return localFrame(for: overlayScreenFrame, in: viewSize, overlayScreenFrame: overlayScreenFrame)
        }

        return nil
    }

    private func targetID(
        at location: CGPoint,
        in viewSize: CGSize,
        overlayScreenFrame: CGRect
    ) -> String? {
        for (index, target) in targets.enumerated() where target.mode == .window {
            let frame = frame(
                for: target,
                index: index,
                in: viewSize,
                overlayScreenFrame: overlayScreenFrame
            )
            if let frame, frame.contains(location) {
                return target.id
            }
        }

        for (index, target) in targets.enumerated() where target.mode == .display {
            let frame = frame(
                for: target,
                index: index,
                in: viewSize,
                overlayScreenFrame: overlayScreenFrame
            )
            if let frame, frame.contains(location) {
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
            y: (overlayScreenFrame.maxY - screenFrame.maxY) * scaleY,
            width: screenFrame.width * scaleX,
            height: screenFrame.height * scaleY
        )
    }

}

struct WindowSelectionTargetPresentation: Equatable {
    var showsCardContent = false
    var fillOpacity: Double
    var strokeOpacity: Double
    var lineWidth: CGFloat
    var cornerRadius: CGFloat

    init(isHighlighted: Bool, isLocked: Bool = false) {
        fillOpacity = isLocked ? 0 : (isHighlighted ? 0.08 : 0)
        strokeOpacity = isLocked ? 0.72 : (isHighlighted ? 1 : 0)
        lineWidth = isLocked ? 2 : (isHighlighted ? 4 : 1)
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
        var displayID: DisplayID?
        var appKitFrame: CGRect
        var coreGraphicsFrame: CGRect

        init(
            displayID: DisplayID? = nil,
            appKitFrame: CGRect,
            coreGraphicsFrame: CGRect
        ) {
            self.displayID = displayID
            self.appKitFrame = appKitFrame
            self.coreGraphicsFrame = coreGraphicsFrame
        }
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
                displayID: DisplayID(rawValue: displayID),
                appKitFrame: screen.frame,
                coreGraphicsFrame: CGDisplayBounds(displayID)
            )
        }
    }

    func appKitFrame(forDisplayID displayID: DisplayID) -> CGRect? {
        displays.first { $0.displayID == displayID }?.appKitFrame
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
    private var targets: [SourceTargetOption] = []
    private var selectHandler: (@MainActor (String) -> Void)?
    private var cancelHandler: (@MainActor () -> Void)?
    private var persistsAfterSelection = false
    private var lockedSelectionTargetID: String?

    var isLockedSelectionVisible: Bool {
        lockedSelectionTargetID != nil
    }

    func present(
        targets: [SourceTargetOption],
        persistsAfterSelection: Bool = false,
        onSelect: @escaping @MainActor (String) -> Void,
        onCancel: @escaping @MainActor () -> Void
    ) {
        dismiss()
        self.targets = targets
        selectHandler = onSelect
        cancelHandler = onCancel
        self.persistsAfterSelection = persistsAfterSelection

        let panelFrames = WindowSelectionOverlayLayout.panelFrames(
            for: NSScreen.screens.map(\.frame),
            fallbackFrame: NSScreen.main?.frame ?? .zero
        )

        windows = panelFrames.map { overlayScreenFrame in
            let overlayWindow = WindowSelectionOverlayWindow(
                overlayFrame: overlayScreenFrame,
                onCancel: { [weak self] in
                    self?.cancelSelection()
                }
            )
            overlayWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            overlayWindow.orderFrontRegardless()
            return overlayWindow
        }

        renderOverlays(selectedTargetID: nil, isInteractive: true)
        windows.first?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        windows.forEach { $0.close() }
        windows = []
        targets = []
        selectHandler = nil
        cancelHandler = nil
        persistsAfterSelection = false
        lockedSelectionTargetID = nil
    }

    private func lockSelection(targetID: String) {
        guard persistsAfterSelection else {
            let selectHandler = selectHandler
            dismiss()
            selectHandler?(targetID)
            return
        }

        windows.forEach { window in
            window.ignoresMouseEvents = true
            window.level = .floating
        }
        lockedSelectionTargetID = targetID
        renderOverlays(selectedTargetID: targetID, isInteractive: false)
        selectHandler?(targetID)
    }

    private func cancelSelection() {
        let cancelHandler = cancelHandler
        dismiss()
        cancelHandler?()
    }

    private func renderOverlays(selectedTargetID: String?, isInteractive: Bool) {
        for window in windows {
            window.contentView = NSHostingView(
                rootView: WindowSelectionOverlayView(
                    targets: targets,
                    overlayScreenFrame: window.frame,
                    selectedTargetID: selectedTargetID,
                    isInteractive: isInteractive,
                    onSelect: { [weak self] targetID in
                        self?.lockSelection(targetID: targetID)
                    },
                    onCancel: { [weak self] in
                        self?.cancelSelection()
                    }
                )
            )
        }
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
    private let selectedTargetID: String?
    private let isInteractive: Bool
    private let onSelect: @MainActor (String) -> Void
    private let onCancel: @MainActor () -> Void

    init(
        targets: [SourceTargetOption],
        overlayScreenFrame: CGRect,
        selectedTargetID: String? = nil,
        isInteractive: Bool = true,
        onSelect: @escaping @MainActor (String) -> Void,
        onCancel: @escaping @MainActor () -> Void
    ) {
        var model = WindowSelectionOverlayModel(targets: targets)
        if let selectedTargetID {
            _ = model.lockSelection(targetID: selectedTargetID)
        }
        _model = State(initialValue: model)
        self.overlayScreenFrame = overlayScreenFrame
        self.selectedTargetID = selectedTargetID
        self.isInteractive = isInteractive
        self.onSelect = onSelect
        self.onCancel = onCancel
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                dimmingLayer(in: proxy)

                ZStack {
                    ForEach(Array(model.targets.enumerated()), id: \.element.id) { index, target in
                        if let frame = model.frame(
                            for: target,
                            index: index,
                            in: proxy.size,
                            overlayScreenFrame: overlayScreenFrame
                        ), shouldRender(target: target) {
                            windowTarget(target, frame: frame)
                        }
                    }

                    if isInteractive {
                        trackingLayer(in: proxy)
                    }
                }
            }
            .ignoresSafeArea()
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

    private func dimmingLayer(in proxy: GeometryProxy) -> some View {
        let selectedFrame = selectedFrame(in: proxy)
        return WindowSelectionDimmingShape(
            cutoutFrame: isInteractive ? nil : selectedFrame,
            cornerRadius: 10
        )
        .fill(Color.black.opacity(isInteractive ? 0.28 : 0.32), style: FillStyle(eoFill: true))
    }

    private func selectedFrame(in proxy: GeometryProxy) -> CGRect? {
        guard let selectedTargetID,
              let index = model.targets.firstIndex(where: { $0.id == selectedTargetID }) else {
            return nil
        }

        return model.frame(
            for: model.targets[index],
            index: index,
            in: proxy.size,
            overlayScreenFrame: overlayScreenFrame
        )
    }

    private func shouldRender(target: SourceTargetOption) -> Bool {
        isInteractive || selectedTargetID == target.id
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
                            _ = model.lockSelection(targetID: targetID)
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
        let isHighlighted = model.highlightedTargetID == target.id || selectedTargetID == target.id
        let isLocked = selectedTargetID == target.id
        let presentation = WindowSelectionTargetPresentation(isHighlighted: isHighlighted, isLocked: isLocked)

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

private struct WindowSelectionDimmingShape: Shape {
    var cutoutFrame: CGRect?
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        if let cutoutFrame {
            path.addRoundedRect(
                in: cutoutFrame,
                cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
            )
        }
        return path
    }
}
