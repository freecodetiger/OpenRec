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

@MainActor
@Test func windowSelectionOverlayHoverChangesHighlightedWindow() {
    var overlay = WindowSelectionOverlayModel(targets: AppShellSnapshot.ready.availableTargets)

    overlay.hover(targetID: "window-42")

    #expect(overlay.highlightedTargetID == "window-42")
}

@MainActor
@Test func windowSelectionOverlayPresentationUsesOutlineWithoutCardContent() {
    let presentation = WindowSelectionTargetPresentation(isHighlighted: false)
    let highlightedPresentation = WindowSelectionTargetPresentation(isHighlighted: true)

    #expect(presentation.showsCardContent == false)
    #expect(presentation.fillOpacity == 0)
    #expect(presentation.strokeOpacity == 0)
    #expect(highlightedPresentation.strokeOpacity > presentation.strokeOpacity)
    #expect(highlightedPresentation.lineWidth > presentation.lineWidth)
}

@MainActor
@Test func windowSelectionOverlayPointerLocationHighlightsWindowFrame() {
    let first = SourceTargetOption(
        id: "window-1",
        mode: .window,
        source: .window(WindowID(rawValue: 1)),
        title: "Safari - Notes",
        subtitle: "Window recording target",
        screenFrame: CGRect(x: 100, y: 100, width: 300, height: 200)
    )
    let second = SourceTargetOption(
        id: "window-2",
        mode: .window,
        source: .window(WindowID(rawValue: 2)),
        title: "Xcode - OpenRec",
        subtitle: "Window recording target",
        screenFrame: CGRect(x: 500, y: 100, width: 300, height: 200)
    )
    var overlay = WindowSelectionOverlayModel(targets: [first, second])

    overlay.movePointer(
        to: CGPoint(x: 650, y: 300),
        in: CGSize(width: 1000, height: 600),
        overlayScreenFrame: CGRect(x: 0, y: 0, width: 1000, height: 600)
    )

    #expect(overlay.highlightedTargetID == "window-2")
}

@MainActor
@Test func windowSelectionOverlayPointerLocationPrefersFrontmostWindowAtPoint() {
    let frontWindow = SourceTargetOption(
        id: "window-front",
        mode: .window,
        source: .window(WindowID(rawValue: 1)),
        title: "Front Window",
        subtitle: "Window recording target",
        screenFrame: CGRect(x: 220, y: 180, width: 420, height: 280)
    )
    let fullscreenWindowBehind = SourceTargetOption(
        id: "window-fullscreen",
        mode: .window,
        source: .window(WindowID(rawValue: 2)),
        title: "Fullscreen Window",
        subtitle: "Window recording target",
        screenFrame: CGRect(x: 0, y: 0, width: 1000, height: 700)
    )
    var overlay = WindowSelectionOverlayModel(targets: [frontWindow, fullscreenWindowBehind])

    overlay.movePointer(
        to: CGPoint(x: 300, y: 240),
        in: CGSize(width: 1000, height: 700),
        overlayScreenFrame: CGRect(x: 0, y: 0, width: 1000, height: 700)
    )

    #expect(overlay.highlightedTargetID == "window-front")
}

@MainActor
@Test func windowSelectionOverlayPointerLocationClearsHighlightOutsideWindows() {
    let target = SourceTargetOption(
        id: "window-1",
        mode: .window,
        source: .window(WindowID(rawValue: 1)),
        title: "Safari - Notes",
        subtitle: "Window recording target",
        screenFrame: CGRect(x: 100, y: 100, width: 300, height: 200)
    )
    var overlay = WindowSelectionOverlayModel(targets: [target])

    overlay.movePointer(
        to: CGPoint(x: 50, y: 50),
        in: CGSize(width: 1000, height: 600),
        overlayScreenFrame: CGRect(x: 0, y: 0, width: 1000, height: 600)
    )

    #expect(overlay.highlightedTargetID == nil)
}

@MainActor
@Test func windowSelectionOverlayClickAtPointerLocationSelectsHighlightedWindow() {
    let target = SourceTargetOption(
        id: "window-1",
        mode: .window,
        source: .window(WindowID(rawValue: 1)),
        title: "Safari - Notes",
        subtitle: "Window recording target",
        screenFrame: CGRect(x: 100, y: 100, width: 300, height: 200)
    )
    var overlay = WindowSelectionOverlayModel(targets: [target])

    overlay.movePointer(
        to: CGPoint(x: 150, y: 300),
        in: CGSize(width: 1000, height: 600),
        overlayScreenFrame: CGRect(x: 0, y: 0, width: 1000, height: 600)
    )

    #expect(overlay.clickHighlightedTarget() == "window-1")
}

@MainActor
@Test func windowSelectionOverlayClickAppliesSelection() {
    let adapter = MockAppCoreAdapter(initialSnapshot: .ready)
    let viewModel = AppShellViewModel(adapter: adapter)
    var draft = SourceSelectionDraft(snapshot: viewModel.snapshot)
    draft.selectMode(.window)
    var overlay = WindowSelectionOverlayModel(targets: draft.visibleTargets)

    let selectedTargetID = overlay.click(targetID: "window-42")
    if let selectedTargetID {
        draft.selectTarget(id: selectedTargetID)
        viewModel.applySourceSelection(draft)
    }

    #expect(adapter.selectModes == [.window])
    #expect(adapter.selectTargetIDs == ["window-42"])
    #expect(viewModel.snapshot.mode == .window)
    #expect(viewModel.snapshot.selectedTarget.id == "window-42")
}

@MainActor
@Test func windowSelectionOverlayEscCancelIsNoOp() {
    let adapter = MockAppCoreAdapter(initialSnapshot: .ready)
    let viewModel = AppShellViewModel(adapter: adapter)
    var draft = SourceSelectionDraft(snapshot: viewModel.snapshot)
    draft.selectMode(.window)
    var overlay = WindowSelectionOverlayModel(targets: draft.visibleTargets)

    overlay.hover(targetID: "window-42")
    let selectedTargetID = overlay.cancel()
    if let selectedTargetID {
        draft.selectTarget(id: selectedTargetID)
        viewModel.applySourceSelection(draft)
    }

    #expect(selectedTargetID == nil)
    #expect(adapter.selectModes.isEmpty)
    #expect(adapter.selectTargetIDs.isEmpty)
    #expect(viewModel.snapshot.mode == .display)
    #expect(viewModel.snapshot.selectedTarget.id == "display-1")
}

@MainActor
@Test func windowSelectionOverlayIgnoresDisplayTargets() {
    var overlay = WindowSelectionOverlayModel(targets: AppShellSnapshot.ready.availableTargets)

    overlay.hover(targetID: "display-1")
    let selectedTargetID = overlay.click(targetID: "display-1")

    #expect(overlay.targets.map(\.id) == ["window-42"])
    #expect(overlay.highlightedTargetID == nil)
    #expect(selectedTargetID == nil)
}

@MainActor
@Test func windowSelectionOverlayUsesScreenFrameWhenAvailable() {
    let target = SourceTargetOption(
        id: "window-99",
        mode: .window,
        source: .window(WindowID(rawValue: 99)),
        title: "Editor - Draft",
        subtitle: "Window recording target",
        screenFrame: CGRect(x: 100, y: 200, width: 600, height: 400)
    )
    let overlay = WindowSelectionOverlayModel(targets: [target])

    let frame = overlay.frame(
        for: target,
        index: 0,
        in: CGSize(width: 1440, height: 900),
        overlayScreenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900)
    )

    #expect(frame == CGRect(x: 100, y: 300, width: 600, height: 400))
}

@MainActor
@Test func windowSelectionOverlayDoesNotCreateFakeSelectionFrameWhenScreenFrameIsMissing() {
    let target = AppShellSnapshot.windowTarget
    let overlay = WindowSelectionOverlayModel(targets: [target])

    let frame = overlay.frame(
        for: target,
        index: 0,
        in: CGSize(width: 1200, height: 800),
        overlayScreenFrame: CGRect(x: 0, y: 0, width: 1200, height: 800)
    )

    #expect(frame == nil)
}

@MainActor
@Test func windowSelectionOverlayUsesOnePanelFramePerScreenInsteadOfUnionFrame() {
    let leftScreen = CGRect(x: -1440, y: 0, width: 1440, height: 900)
    let mainScreen = CGRect(x: 0, y: 0, width: 1728, height: 1117)

    let frames = WindowSelectionOverlayLayout.panelFrames(for: [leftScreen, mainScreen])

    #expect(frames == [leftScreen, mainScreen])
    #expect(frames != [leftScreen.union(mainScreen)])
}

@MainActor
@Test func windowSelectionOverlayMapsWindowIntoContainingScreenPanel() {
    let mainScreen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
    let target = SourceTargetOption(
        id: "window-main",
        mode: .window,
        source: .window(WindowID(rawValue: 100)),
        title: "Main Display Window",
        subtitle: "Window recording target",
        screenFrame: CGRect(x: 120, y: 140, width: 800, height: 500)
    )
    let overlay = WindowSelectionOverlayModel(targets: [target])

    let frame = overlay.frame(
        for: target,
        index: 0,
        in: mainScreen.size,
        overlayScreenFrame: mainScreen
    )

    #expect(frame == CGRect(x: 120, y: 477, width: 800, height: 500))
}

@MainActor
@Test func screenCaptureKitWindowFrameConvertsToAppKitScreenFrameForExternalDisplay() {
    let converter = WindowScreenFrameConverter(displays: [
        WindowScreenFrameConverter.DisplayFrame(
            appKitFrame: CGRect(x: 0, y: 0, width: 1280, height: 832),
            coreGraphicsFrame: CGRect(x: 0, y: 0, width: 1280, height: 832)
        ),
        WindowScreenFrameConverter.DisplayFrame(
            appKitFrame: CGRect(x: -515, y: 832, width: 2560, height: 1440),
            coreGraphicsFrame: CGRect(x: -515, y: -1440, width: 2560, height: 1440)
        )
    ])

    let convertedFrame = converter.appKitFrame(
        fromScreenCaptureKitFrame: CGRect(x: 1536, y: -1440, width: 38, height: 24)
    )

    #expect(convertedFrame == CGRect(x: 1536, y: 2248, width: 38, height: 24))
}

@MainActor
@Test func windowControlBarLayoutFitsInsideNormalWindowFrame() {
    let layout = WindowRecordingControlBarLayout(
        targetFrame: CGRect(x: 100, y: 100, width: 900, height: 600),
        visibleScreenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900)
    )

    let frame = layout.panelFrame()

    #expect(frame.minX >= 100)
    #expect(frame.maxX <= 1000)
    #expect(frame.minY >= 100)
    #expect(frame.maxY <= 700)
    #expect(frame.width <= 760)
}

@MainActor
@Test func windowControlBarLayoutClampsNearScreenEdge() {
    let layout = WindowRecordingControlBarLayout(
        targetFrame: CGRect(x: 10, y: 10, width: 420, height: 180),
        visibleScreenFrame: CGRect(x: 0, y: 0, width: 500, height: 260)
    )

    let frame = layout.panelFrame()

    #expect(frame.minX >= 0)
    #expect(frame.minY >= 0)
    #expect(frame.maxX <= 500)
    #expect(frame.maxY <= 260)
}

@MainActor
@Test func windowControlBarLayoutFallsBackWhenTargetFrameMissing() {
    let layout = WindowRecordingControlBarLayout(
        targetFrame: nil,
        visibleScreenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900)
    )

    let frame = layout.panelFrame()

    #expect(frame.width > 0)
    #expect(frame.height > 0)
    #expect(frame.midX == 720)
}
