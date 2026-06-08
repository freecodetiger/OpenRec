# Window Recording Control Bar Design

## Goal

Make window recording feel like a direct visual workflow: choosing `Window Recording` from the menu enters window selection, clicking a window shows a compact control bar inside that window at the bottom, and pressing `Start` hides the bar before recording begins.

## Confirmed Product Decisions

- Switching the menu mode to `Window Recording` automatically starts visual selection.
- The menu popover closes when the visual selection workflow begins.
- The selected window gets an in-window bottom bar that overlays the target window content.
- The bar exposes only presets: output format, codec, frame rate, quality, microphone, `Start`, and `Cancel`.
- Supported codec choices include H.264 and HEVC/H.265.
- Frame rate remains preset-only: 25, 30, and 60 fps.
- Resolution remains original only. No resolution picker is shown.
- Settings changes in the bar persist to the existing JSON settings store.
- Pressing `Start` hides the bar before recording starts.
- Recording still stops from the menu bar icon/popover or global hotkey.

## User Flow

1. User opens OpenRec from the menu bar.
2. User switches mode to `Window Recording`.
3. OpenRec closes the menu UI and presents the full-screen visual window selection overlay.
4. User hovers available windows and clicks one.
5. OpenRec selects the clicked window as the recording target and shows a compact parameter bar inside the selected window at the bottom.
6. User chooses from preset controls.
7. Each parameter change updates `RecordingSettings` through the existing app shell and persists JSON through `OpenRecAppCoreAdapter.updateSettings`.
8. User presses `Start`.
9. OpenRec dismisses the control bar first, then calls the existing recording start path.
10. User stops recording through the menu bar or hotkey.
11. Existing save prompt behavior remains unchanged.

`Cancel` dismisses the workflow and returns OpenRec to the previous non-recording ready state without starting capture. If the mode was changed only to enter the flow, cancellation restores the previous mode and target.

## Architecture

The feature should extend the current app shell instead of introducing a separate recording controller.

- `AppShellViewModel` owns workflow intent and state transitions.
- `WindowSelectionOverlayPresenter` continues to own the full-screen selection overlay.
- A new `WindowRecordingControlBarPresenter` owns an AppKit panel positioned inside the selected target frame.
- A new `WindowRecordingControlBarView` owns the SwiftUI controls.
- `MenuBarPopoverView` triggers the visual workflow when the user selects `Window Recording`.
- `AppKitStatusItemController` exposes a close API so the fallback popover can be dismissed before overlay presentation.

This keeps ScreenCaptureKit and recording output code unchanged. The new work is app/UI orchestration around the existing selected target, settings, and recording start APIs.

## State Model

Add a lightweight app-level workflow state for UI orchestration:

- `idle`: no visual workflow is active.
- `selectingWindow(previousMode, previousTargetID)`: full-screen overlay is active.
- `configuringWindow(previousMode, previousTargetID, selectedTargetID)`: selected-window control bar is active.

This state lives in `AppShellViewModel`, not in `OpenRecCore`, because it is UI workflow state rather than capture state.

Expected transitions:

- `ready + requestWindowRecordingWorkflow` -> `selectingWindow`.
- `selectingWindow + select target` -> select `.window` mode and target through the adapter, then `configuringWindow`.
- `selectingWindow + cancel` -> restore previous mode/target if needed, then `idle`.
- `configuringWindow + update setting` -> update settings and stay `configuringWindow`.
- `configuringWindow + start` -> `idle`, dismiss bar, then start recording.
- `configuringWindow + cancel` -> restore previous mode/target if needed, then `idle`.
- Any recording/error/permission-required state dismisses active workflow UI.

## Control Bar Behavior

The bar is an `NSPanel` with SwiftUI content. It should:

- Be non-activating enough to feel like an overlay, while still accepting clicks and picker focus.
- Stay above normal windows but below system permission prompts.
- Use the target `screenFrame` to position itself inside the selected window.
- Clamp to the selected window and current screen visible frame.
- Fall back to a centered compact panel if the target has no usable frame.
- Use compact native controls, not arbitrary text fields.
- Hide before recording starts so OpenRec's own bar is not captured.

For very small selected windows, the layout should shrink into two rows and keep `Start` and `Cancel` visible. It must not overflow off-screen or cover the menu bar.

## Parameter Presets

The bar must use the existing enums:

- `OutputFormat.allCases`: MP4, MOV.
- `VideoCodec.allCases`: H.264, HEVC/H.265.
- `FrameRatePreset.allCases`: 25, 30, 60.
- `QualityPreset.allCases`: Compact, Standard, High.
- `snapshot.microphones`: available microphone devices.

It must not expose bitrate, arbitrary dimensions, custom frame rates, custom codec options, or save path controls. Save path selection remains the post-stop save flow.

## Error Handling

- No available windows: show a concise non-recording error state and keep the app ready to retry after refresh.
- Missing screen recording or microphone permission: do not enter recording; existing permission UI remains the source of truth.
- Selected window disappears before `Start`: dismiss the bar, refresh sources, and show a clear error message.
- Selected window frame is missing: use a fallback compact bar position and still allow recording if the target source is valid.
- Selected window is near a screen edge: clamp the bar within the visible screen and selected frame.
- User presses Escape in selection: cancel and restore previous state.
- User presses Escape while the bar is focused: cancel and restore previous state.

## Testing Strategy

Use TDD for behavior that can run in unit tests:

- `AppShellViewModel` workflow transitions, previous selection restoration, settings persistence calls, and start dismissal ordering.
- Window selection model behavior for valid/invalid targets and cancellation.
- Control bar layout model for normal, small, missing-frame, and edge-of-screen windows.
- Menu mode binding delegates window workflow rather than only selecting `.window`.
- Mock adapter records settings updates, selected targets, and start calls.

Manual QA covers AppKit panel layering and real macOS behavior:

- Switch to `Window Recording` from the menu and verify popover closes.
- Select a visible app window and verify the bar appears inside it at the bottom.
- Change presets, quit/relaunch, and verify JSON settings persist.
- Start recording and verify the bar disappears before capture begins.
- Stop recording and verify the existing save prompt appears.

## Multi-Agent Boundaries

Parallel work must avoid shared-file contention:

- Agent A: app shell workflow state and ViewModel tests.
- Agent B: control bar layout model, SwiftUI view, AppKit presenter, and tests for pure layout logic.
- Agent C: menu/status integration, settings binding, and manual QA docs.
- Main integrator: wire presenters into `OpenRecApplication`, resolve overlap in `MenuBarPopoverView` and `AppShellViewModel`, run full verification, and push.

Agents may read any file, but each implementation task gets a disjoint write set. The main integrator owns final edits in files that naturally cross boundaries.
