# OpenRec Manual QA Checklist

Use this checklist for release-candidate testing on real macOS hardware. Record the macOS version, Mac model, display setup, OpenRec build or commit SHA, and whether the app was launched from an unsigned ZIP.

## Environment

- [ ] macOS 14 or later tested.
- [ ] Apple Silicon Mac tested if available.
- [ ] Intel Mac tested if available.
- [ ] Single-display setup tested.
- [ ] Multi-display setup tested.
- [ ] Built-in microphone tested if available.
- [ ] External or virtual microphone tested if available.
- [ ] Offline test run completed with network disabled.

## Permissions

- [ ] First launch explains Screen Recording permission and links to System Settings.
- [ ] First launch explains Microphone permission and links to System Settings.
- [ ] First launch explains Accessibility or Input Monitoring permission if required by hotkeys or window selection.
- [ ] Permission status can be rechecked after changing System Settings.
- [ ] Starting a recording is blocked with a recoverable error when Screen Recording permission is missing.
- [ ] Microphone denial is handled before recording starts or by requiring a valid microphone selection.
- [ ] Unsigned build launch path and Gatekeeper warning are documented in release notes or README.

## Display Recording

- [ ] With one display, the display can be selected by default and is visible in the menu UI.
- [ ] With multiple displays, the user must select the intended display before recording.
- [ ] Recording uses the selected display, not another connected display.
- [ ] Recording preserves the display's original source resolution.
- [ ] Cursor inclusion follows the current setting.
- [ ] Target loss or display change before start produces a recoverable reselect flow.

## Window Recording

- [ ] Window selection mode opens from the window recording path.
- [ ] Eligible windows highlight on hover.
- [ ] Clicking a highlighted window selects that window.
- [ ] Esc cancels window selection without starting a recording.
- [ ] Recording captures the selected window, not the full display.
- [ ] Recording preserves the selected window's original source resolution.
- [ ] Closed or unavailable selected windows trigger a recoverable reselect flow.

## Microphone

- [ ] System default microphone can be used.
- [ ] A selected non-default microphone can be used.
- [ ] Recorded microphone audio is present and synchronized with video.
- [ ] Missing previously selected microphone falls back to the system default when possible.
- [ ] No available microphone produces a clear recoverable error if microphone recording is required.

## Containers, Codecs, and Frame Rates

Test at least one display recording and one window recording across the supported matrix.

| Format | Codec | 25 fps | 30 fps | 60 fps |
| --- | --- | --- | --- | --- |
| MP4 | H.264 | [ ] | [ ] | [ ] |
| MP4 | HEVC/H.265 | [ ] | [ ] | [ ] |
| MOV | H.264 | [ ] | [ ] | [ ] |
| MOV | HEVC/H.265 | [ ] | [ ] | [ ] |

- [ ] Compact quality preset creates a playable file.
- [ ] Standard quality preset creates a playable file.
- [ ] High quality preset creates a playable file.
- [ ] Unsupported codec/container combinations fail before recording starts with a clear error.
- [ ] Output files are playable in QuickTime Player or Finder preview.

## Save, Retry, and Discard

- [ ] Stopping a recording finalizes a temporary output file before showing the save panel.
- [ ] Saving to a writable destination moves the recording to the selected path.
- [ ] Cancelling the save panel offers retry save or discard.
- [ ] Retry save after cancellation succeeds.
- [ ] Discard removes the temporary recording.
- [ ] Save failure due to permissions or unavailable destination is recoverable.
- [ ] App returns to the ready state after save or discard.

## Offline Behavior

- [ ] App launches with network disabled.
- [ ] Recording works with network disabled.
- [ ] Preferences load and save with network disabled.
- [ ] No upload, sharing, telemetry, crash reporting, or update prompt appears.
- [ ] No release-blocking network access is observed during MVP flows.

## Release Artifact

- [ ] GitHub Actions runs `swift test` on macOS.
- [ ] Release tag workflow uploads a ZIP artifact.
- [ ] ZIP artifact contains expected project files or app bundle for the current release stage.
- [ ] README build, privacy, Gatekeeper, and license notes match the shipped artifact.
