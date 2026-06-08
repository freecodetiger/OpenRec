# Window Recording Control Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Screen Studio-style window recording workflow with visual window selection, an in-window preset control bar, JSON-persisted settings changes, and start-on-confirm behavior.

**Architecture:** Keep recording engine and core settings unchanged. Add app-shell workflow state, an AppKit/SwiftUI selected-window control bar presenter, and menu integration that triggers the workflow instead of silently switching the source.

**Tech Stack:** Swift 6, SwiftUI, AppKit, ScreenCaptureKit through existing OpenRecCore APIs, Swift Testing.

---

## File Structure

- Modify `Sources/OpenRecApp/AppShellModels.swift`: add `WindowRecordingWorkflowState` and pure layout/configuration helpers if needed by tests.
- Modify `Sources/OpenRecApp/AppShellViewModel.swift`: add window workflow methods and workflow state.
- Modify `Sources/OpenRecApp/MockAppCoreAdapter.swift`: expose call tracking needed by new workflow tests.
- Modify `Sources/OpenRecApp/WindowSelectionOverlay.swift`: keep existing selection overlay and add or delegate to selected-window bar presenter.
- Create `Sources/OpenRecApp/WindowRecordingControlBar.swift`: SwiftUI control bar view, layout model, and AppKit presenter.
- Modify `Sources/OpenRecApp/MenuBarPopoverView.swift`: mode switch calls the window workflow trigger and asks host to close the popover.
- Modify `Sources/OpenRecApp/AppKitStatusItemController.swift`: expose a `closePopover()` API and pass it into the popover view.
- Modify `Sources/OpenRecApp/OpenRecApplication.swift`: wire overlay/control bar presenters and close callbacks.
- Modify `Tests/OpenRecAppTests/AppShellViewModelTests.swift`: workflow state and start-order tests.
- Modify `Tests/OpenRecAppTests/SourceSelectionInteractionTests.swift`: overlay/control bar layout and interaction tests.
- Modify `docs/qa/manual-qa-checklist.md`: add manual QA for window control bar workflow.

## Task 1: App Shell Workflow State

**Files:**
- Modify: `Sources/OpenRecApp/AppShellModels.swift`
- Modify: `Sources/OpenRecApp/AppShellViewModel.swift`
- Modify: `Sources/OpenRecApp/MockAppCoreAdapter.swift`
- Test: `Tests/OpenRecAppTests/AppShellViewModelTests.swift`

- [ ] **Step 1: Write failing tests for workflow transitions**

Add tests that express these behaviors:

```swift
@MainActor
@Test func requestingWindowWorkflowStoresPreviousSelectionAndEntersSelectingState() {
    let adapter = MockAppCoreAdapter(initialSnapshot: .ready)
    let viewModel = AppShellViewModel(adapter: adapter)

    let entered = viewModel.requestWindowRecordingWorkflow()

    #expect(entered == true)
    #expect(viewModel.windowRecordingWorkflow == .selectingWindow(previousMode: .display, previousTargetID: "display-1"))
    #expect(adapter.selectModes.isEmpty)
    #expect(adapter.selectTargetIDs.isEmpty)
}

@MainActor
@Test func selectingWindowTargetAppliesWindowModeAndShowsControlBarState() {
    let adapter = MockAppCoreAdapter(initialSnapshot: .ready)
    let viewModel = AppShellViewModel(adapter: adapter)

    _ = viewModel.requestWindowRecordingWorkflow()
    viewModel.selectWindowForRecording(targetID: "window-42")

    #expect(adapter.selectModes == [.window])
    #expect(adapter.selectTargetIDs == ["window-42"])
    #expect(viewModel.snapshot.mode == .window)
    #expect(viewModel.windowRecordingWorkflow == .configuringWindow(previousMode: .display, previousTargetID: "display-1", selectedTargetID: "window-42"))
}

@MainActor
@Test func cancelingWindowWorkflowRestoresPreviousSelection() {
    let adapter = MockAppCoreAdapter(initialSnapshot: .ready)
    let viewModel = AppShellViewModel(adapter: adapter)

    _ = viewModel.requestWindowRecordingWorkflow()
    viewModel.selectWindowForRecording(targetID: "window-42")
    viewModel.cancelWindowRecordingWorkflow()

    #expect(viewModel.windowRecordingWorkflow == .idle)
    #expect(viewModel.snapshot.mode == .display)
    #expect(viewModel.snapshot.selectedTarget.id == "display-1")
}

@MainActor
@Test func startingConfiguredWindowRecordingClearsWorkflowAndStartsRecording() {
    let adapter = MockAppCoreAdapter(initialSnapshot: .ready)
    let viewModel = AppShellViewModel(adapter: adapter)

    _ = viewModel.requestWindowRecordingWorkflow()
    viewModel.selectWindowForRecording(targetID: "window-42")
    viewModel.startConfiguredWindowRecording()

    #expect(viewModel.windowRecordingWorkflow == .idle)
    #expect(adapter.startRecordingCallCount == 1)
    #expect(viewModel.snapshot.status == .recording)
}

@MainActor
@Test func windowControlBarSettingsPersistThroughAdapter() {
    let adapter = MockAppCoreAdapter(initialSnapshot: .ready)
    let viewModel = AppShellViewModel(adapter: adapter)

    var settings = viewModel.snapshot.settings
    settings.videoCodec = .hevc
    settings.frameRate = .fps60
    viewModel.updateWindowControlBarSettings(settings)

    #expect(adapter.updatedSettings.map(\.videoCodec) == [.hevc])
    #expect(adapter.updatedSettings.map(\.frameRate) == [.fps60])
    #expect(viewModel.snapshot.settings.videoCodec == .hevc)
}
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
swift test --filter AppShellViewModelTests
```

Expected: compile/test failure because `WindowRecordingWorkflowState`, `windowRecordingWorkflow`, and workflow methods do not exist.

- [ ] **Step 3: Implement minimal workflow state**

Add this state in `AppShellModels.swift`:

```swift
enum WindowRecordingWorkflowState: Equatable, Sendable {
    case idle
    case selectingWindow(previousMode: CaptureMode, previousTargetID: String)
    case configuringWindow(previousMode: CaptureMode, previousTargetID: String, selectedTargetID: String)
}
```

Add `@Published private(set) var windowRecordingWorkflow: WindowRecordingWorkflowState = .idle` to `AppShellViewModel`.

Add methods:

```swift
func requestWindowRecordingWorkflow() -> Bool
func selectWindowForRecording(targetID: String)
func cancelWindowRecordingWorkflow()
func startConfiguredWindowRecording()
func updateWindowControlBarSettings(_ settings: RecordingSettings)
```

Implementation rules:

- Only enter workflow when `snapshot.status == .ready`.
- Do not call adapter selection when entering `selectingWindow`.
- Selecting a target must verify the target exists and has `.window` mode.
- Selecting a target calls `adapter.selectMode(.window)` if needed, then `adapter.selectTarget(id:)`.
- Cancel restores previous target by `adapter.selectMode(previousMode)` then `adapter.selectTarget(id: previousTargetID)` when needed.
- Starting configured recording sets workflow to `.idle` before calling `startRecording()`.
- Settings updates call existing `updateSettings(_:)`.

Update `MockAppCoreAdapter` with:

```swift
private(set) var updatedSettings: [RecordingSettings] = []
```

and append in `updateSettings`.

- [ ] **Step 4: Run tests and verify GREEN**

Run:

```bash
swift test --filter AppShellViewModelTests
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/OpenRecApp/AppShellModels.swift Sources/OpenRecApp/AppShellViewModel.swift Sources/OpenRecApp/MockAppCoreAdapter.swift Tests/OpenRecAppTests/AppShellViewModelTests.swift
git commit -m "Add window recording workflow state"
```

## Task 2: Control Bar Layout and Presenter

**Files:**
- Create: `Sources/OpenRecApp/WindowRecordingControlBar.swift`
- Test: `Tests/OpenRecAppTests/SourceSelectionInteractionTests.swift`

- [ ] **Step 1: Write failing layout tests**

Add tests:

```swift
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
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
swift test --filter SourceSelectionInteractionTests
```

Expected: compile failure because `WindowRecordingControlBarLayout` does not exist.

- [ ] **Step 3: Implement layout model, view, and presenter**

Create `WindowRecordingControlBar.swift` with:

- `WindowRecordingControlBarLayout`: pure struct with `panelFrame()`.
- `WindowRecordingControlBarView`: compact SwiftUI view with preset pickers for format, codec, frame rate, quality, microphone, plus `Start` and `Cancel`.
- `WindowRecordingControlBarPresenter`: owns one `NSPanel`, presents at the layout frame, and dismisses on cancel/start.

Use `RecordingSettings`, `OutputFormat`, `VideoCodec`, `FrameRatePreset`, `QualityPreset`, and `MicrophoneOption` from existing models. Add local label helpers only if the existing label extensions are not visible in this file.

Presenter API:

```swift
@MainActor
final class WindowRecordingControlBarPresenter {
    func present(
        target: SourceTargetOption,
        snapshot: AppShellSnapshot,
        onSettingsChange: @escaping @MainActor (RecordingSettings) -> Void,
        onStart: @escaping @MainActor () -> Void,
        onCancel: @escaping @MainActor () -> Void
    )

    func dismiss()
}
```

The presenter must dismiss before calling `onStart` so the panel cannot be captured.

- [ ] **Step 4: Run tests and verify GREEN**

Run:

```bash
swift test --filter SourceSelectionInteractionTests
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/OpenRecApp/WindowRecordingControlBar.swift Tests/OpenRecAppTests/SourceSelectionInteractionTests.swift
git commit -m "Add window recording control bar presenter"
```

## Task 3: Menu and Overlay Integration

**Files:**
- Modify: `Sources/OpenRecApp/MenuBarPopoverView.swift`
- Modify: `Sources/OpenRecApp/AppKitStatusItemController.swift`
- Modify: `Sources/OpenRecApp/OpenRecApplication.swift`
- Modify: `Sources/OpenRecApp/WindowSelectionOverlay.swift`
- Test: `Tests/OpenRecAppTests/SourceSelectionInteractionTests.swift`

- [ ] **Step 1: Write failing integration-oriented tests where possible**

Add pure tests for the menu decision helper:

```swift
@MainActor
@Test func menuModeSelectionForWindowRequestsVisualWorkflow() {
    var requestedWindowWorkflow = false
    var selectedModes: [CaptureMode] = []

    MenuModeSelectionHandler.handle(
        selectedMode: .window,
        currentMode: .display,
        selectMode: { selectedModes.append($0) },
        requestWindowWorkflow: { requestedWindowWorkflow = true },
        closeMenu: {}
    )

    #expect(requestedWindowWorkflow == true)
    #expect(selectedModes.isEmpty)
}

@MainActor
@Test func menuModeSelectionForDisplayUsesDirectModeSelection() {
    var requestedWindowWorkflow = false
    var selectedModes: [CaptureMode] = []

    MenuModeSelectionHandler.handle(
        selectedMode: .display,
        currentMode: .window,
        selectMode: { selectedModes.append($0) },
        requestWindowWorkflow: { requestedWindowWorkflow = true },
        closeMenu: {}
    )

    #expect(requestedWindowWorkflow == false)
    #expect(selectedModes == [.display])
}
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
swift test --filter SourceSelectionInteractionTests
```

Expected: compile failure because `MenuModeSelectionHandler` does not exist.

- [ ] **Step 3: Implement menu handler and close API**

Add `MenuModeSelectionHandler` as a small pure helper near `MenuBarPopoverView`.

Update `MenuBarPopoverView` initializer to accept:

```swift
var onRequestWindowRecordingWorkflow: () -> Void = {}
var onCloseMenu: () -> Void = {}
```

Mode binding behavior:

- Selecting `.window` calls `onCloseMenu()`, then `onRequestWindowRecordingWorkflow()`.
- Selecting `.display` calls `viewModel.selectMode(.display)`.
- Selecting current mode is a no-op.

Update `AppKitStatusItemController`:

```swift
func closePopover() {
    popover.performClose(nil)
}
```

Wire the fallback status item popover to pass `closePopover`.

- [ ] **Step 4: Wire presenters in `OpenRecApplication`**

Create `@StateObject` presenter owners if needed, or keep presenter references in a small `@MainActor` coordinator object owned by the app.

Expected wiring:

- `MenuBarPopoverView` receives a closure that calls `viewModel.requestWindowRecordingWorkflow()`.
- If entering workflow succeeds, call `WindowSelectionOverlayPresenter.present`.
- Selection closure calls `viewModel.selectWindowForRecording(targetID:)`, then presents `WindowRecordingControlBarPresenter`.
- Control bar `onSettingsChange` calls `viewModel.updateWindowControlBarSettings`.
- Control bar `onStart` calls `viewModel.startConfiguredWindowRecording`.
- Control bar `onCancel` calls `viewModel.cancelWindowRecordingWorkflow`.

- [ ] **Step 5: Run tests and verify GREEN**

Run:

```bash
swift test --filter SourceSelectionInteractionTests
swift test --filter AppShellViewModelTests
```

Expected: tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/OpenRecApp/MenuBarPopoverView.swift Sources/OpenRecApp/AppKitStatusItemController.swift Sources/OpenRecApp/OpenRecApplication.swift Sources/OpenRecApp/WindowSelectionOverlay.swift Tests/OpenRecAppTests/SourceSelectionInteractionTests.swift
git commit -m "Wire window recording visual workflow"
```

## Task 4: Manual QA and Full Verification

**Files:**
- Modify: `docs/qa/manual-qa-checklist.md`

- [ ] **Step 1: Update manual QA checklist**

Add a checklist section:

```markdown
## Window Recording Visual Workflow

- [ ] Open OpenRec from the menu bar and switch to Window Recording.
- [ ] Verify the menu popover closes and the full-screen window selection overlay appears.
- [ ] Hover several windows and verify highlight follows the real window bounds.
- [ ] Click a window and verify the control bar appears inside the selected window at the bottom.
- [ ] Change format, codec, frame rate, quality, and microphone presets.
- [ ] Quit and relaunch OpenRec, then verify the changed settings persisted.
- [ ] Press Start and verify the control bar disappears before recording starts.
- [ ] Stop recording from the menu bar and verify the save location prompt appears.
- [ ] Cancel from selection and from the control bar, verifying the previous source is restored.
```

- [ ] **Step 2: Run full verification**

Run:

```bash
swift build
swift test
scripts/test-package-release.sh
scripts/test-launch-dev-app.sh
```

Expected: all commands pass.

- [ ] **Step 3: Launch app for user testing**

Run:

```bash
scripts/launch-dev-app.sh
```

Expected: OpenRec launches with the stable dev identity.

- [ ] **Step 4: Commit and push**

```bash
git add docs/qa/manual-qa-checklist.md
git commit -m "Document window recording visual QA"
git push origin main
```

## Parallel Agent Execution Boundaries

- Agent A owns Task 1 only.
- Agent B owns Task 2 only.
- Agent C owns Task 3 tests and pure menu handler only; the main integrator owns final `OpenRecApplication` presenter wiring if file overlap appears.
- Main integrator owns Task 4 and full verification.

If two agents need the same file, the second agent must stop at a patch summary instead of editing. The main integrator resolves shared-file edits.
