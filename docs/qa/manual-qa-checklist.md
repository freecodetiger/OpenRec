# OpenRec QA Checklist

Use this checklist for release-candidate testing. Record the macOS version, Mac model, CPU architecture, display setup, OpenRec commit SHA or tag, artifact source, and whether the app was launched through SwiftPM or a locally built unsigned app bundle.

## Release Candidate Record

Copy this block for each release candidate and complete it before approving the candidate.

| Field | Value |
| --- | --- |
| Tester | |
| Test date | |
| Commit SHA | |
| Tag | |
| Artifact name and path or URL | |
| Artifact type: source ZIP, SwiftPM checkout, unsigned/ad-hoc app bundle, signed/notarized app bundle | |
| Artifact SHA-256 | |
| macOS version | |
| Mac model | |
| Hardware: Apple Silicon or Intel | |
| Display setup: single-screen or multi-screen | |
| Window recording result | |
| App window recording result | |
| Microphone device and result | |
| Playback quality result: video, audio, sync, file opens in QuickTime/Finder | |
| Permission revocation result: Screen Recording and Microphone revoked then detected | |
| Save cancellation result: cancel save panel discards temporary recording and returns to Ready | |
| Gatekeeper/signing observation | |
| Overall result: pass/fail | |
| Blocking issues | |

## Automated Verification

These checks can run in CI or on a developer machine without exercising real capture permissions.

- [ ] `swift build` succeeds on macOS 14 or later.
- [ ] `swift build -c release` succeeds on macOS 14 or later.
- [ ] `swift test` succeeds on macOS 14 or later.
- [ ] `git diff --check` reports no whitespace errors.
- [ ] `scripts/test-release-artifact.sh` exports `git archive HEAD` to a temporary directory and runs the release artifact smoke command.
- [ ] `scripts/test-package-release.sh` validates unsigned app packaging, checksum output, artifact naming, and signing/notarization dry-run logging.
- [ ] `scripts/test-package-app.sh` builds the SwiftPM release executable and validates `dist/OpenRec.app` bundle metadata.
- [ ] `scripts/test-launch-dev-app.sh` validates the development app bundle wrapper and stable ad-hoc signing requirement.
- [ ] Release tag workflow uploads `dist/OpenRec-<tag>.zip`, `dist/OpenRec-<tag>-macos.zip`, and `.sha256` files as artifacts.
- [ ] Source ZIP contains `Package.swift`, `README.md`, `Sources/`, `Tests/`, `docs/`, and `scripts/`.
- [ ] macOS app ZIP contains `OpenRec.app` and has a matching SHA-256 checksum file.
- [ ] Without signing credentials, package logs clearly identify the macOS app artifact as unsigned or ad-hoc signed.
- [ ] With Developer ID and notary credentials in a dry-run, package logs include hardened runtime `codesign`, `notarytool submit --wait`, and `stapler staple` steps without printing secret values.
- [ ] Source ZIP and macOS app ZIP do not claim to contain an installer, updater, telemetry, or network service.
- [ ] README build, release-stage, privacy, Gatekeeper, and license notes match the shipped artifact.

## Manual Hardware Matrix

These checks require real macOS hardware because ScreenCaptureKit, permissions, hotkeys, window overlays, and microphone routing are system-mediated.

- [ ] macOS 14 or later tested.
- [ ] Apple Silicon Mac tested if available.
- [ ] Intel Mac tested if available.
- [ ] Single-display setup tested.
- [ ] Multi-display setup tested.
- [ ] Built-in microphone tested if available.
- [ ] External or virtual microphone tested if available.
- [ ] Offline test run completed with network disabled.

## Launch and Permissions

- [ ] App launches through the current supported path: `swift run OpenRecApp`, the development app wrapper, or the packaged release app artifact under test.
- [ ] First launch explains Screen Recording permission and links to System Settings.
- [ ] First launch explains Microphone permission and links to System Settings.
- [ ] First launch explains Accessibility or Input Monitoring permission if required by the final hotkey or window-selection implementation.
- [ ] Permission status can be refreshed after granting, denying, or revoking in System Settings.
- [ ] Starting a recording is blocked with a recoverable error when Screen Recording permission is missing.
- [ ] Microphone denial is handled before recording starts or by requiring a valid microphone selection.
- [ ] Unsigned/ad-hoc or signed/notarized app bundle launch path and Gatekeeper warning match README wording.

## Display Recording

- [ ] With one display, the display can be selected by default and is visible in the menu UI.
- [ ] With multiple displays, the user must select the intended display before recording.
- [ ] Recording uses the selected display, not another connected display.
- [ ] Recording preserves the display's original source resolution.
- [ ] Cursor inclusion follows the current setting.
- [ ] Target loss or display change before start produces a recoverable reselect flow.

## Window Selection Overlay

- [ ] Window selection mode opens from the window recording path.
- [ ] Eligible windows highlight on hover without obscuring the selected window.
- [ ] Overlay labels, outlines, and click targets stay aligned on Retina and non-Retina displays.
- [ ] Multi-display overlay behavior is understandable and does not select windows from the wrong display.
- [ ] Clicking a highlighted window selects that window.
- [ ] Esc cancels window selection without starting a recording.
- [ ] Closed or unavailable selected windows trigger a recoverable reselect flow.

## Window Recording Visual Workflow

- [ ] Open OpenRec from the menu bar and verify the source actions show Full Screen, Window, and App Window as peer options.
- [ ] Click Window.
- [ ] Verify the menu popover closes and the full-screen window selection overlay appears.
- [ ] Hover several windows and verify highlight follows the real window bounds.
- [ ] Click a window and verify the control bar appears inside the selected window at the bottom.
- [ ] Change format, codec, frame rate, quality, and microphone presets.
- [ ] Quit and relaunch OpenRec, then verify the changed settings persisted.
- [ ] Press Start and verify the control bar disappears before recording starts.
- [ ] Stop recording from the menu bar and verify the save location prompt appears.
- [ ] Cancel the save location prompt and verify the recording is discarded and OpenRec returns to Ready.
- [ ] Cancel from selection and from the control bar, verifying the previous source is restored.

## App Window Recording Visual Workflow

- [ ] Open OpenRec from the menu bar and click App Window.
- [ ] Verify the app-window chooser opens with applications grouped by their visible windows.
- [ ] Choose an application and verify window selection shows only windows from that application.
- [ ] Choose a window and verify the same preset control bar appears inside the selected window.
- [ ] Verify the selected recording target is the chosen window, not every window owned by the application.
- [ ] Press Start and verify the bar disappears before recording starts.
- [ ] Relaunch OpenRec and verify it starts with Full Screen as the default source.

## Window Recording

- [ ] Recording captures the selected window, not the full display.
- [ ] Recording preserves the selected window's original source resolution.
- [ ] Moving the selected window during recording does not crash the app.
- [ ] Closing the selected window during or before start produces a recoverable error or clean stop.

## Microphone

- [ ] System default microphone can be used.
- [ ] A selected non-default microphone can be used.
- [ ] Recorded microphone audio is present and synchronized with video.
- [ ] Missing previously selected microphone falls back to the system default when possible.
- [ ] No available microphone produces a clear recoverable error if microphone recording is required.
- [ ] Revoking microphone permission between launches is reflected before recording starts.

## Hotkeys

- [ ] Saved global start/stop hotkey registers on launch.
- [ ] Hotkey starts recording from the ready state.
- [ ] Hotkey stops recording from the recording state.
- [ ] Hotkey does nothing unsafe while permission, source selection, save, or error flows are active.
- [ ] Registration conflicts show a recoverable error and do not save the failed hotkey.
- [ ] Clearing or changing the hotkey unregisters the previous shortcut.

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

## Save and Discard

- [ ] Stopping a recording finalizes a temporary output file before showing the save panel.
- [ ] Saving to a writable destination moves the recording to the selected path.
- [ ] Cancelling the save panel discards the temporary recording and returns OpenRec to Ready.
- [ ] Discard removes the temporary recording.
- [ ] Save failure due to permissions or unavailable destination is recoverable.
- [ ] App returns to the ready state after save, discard, or save-panel cancellation.
- [ ] Future retry-save behavior is not presented as a current user-visible option.

## Offline Behavior

- [ ] App launches with network disabled.
- [ ] Recording works with network disabled.
- [ ] Preferences load and save with network disabled.
- [ ] No upload, sharing, telemetry, crash reporting, or update prompt appears.
- [ ] No release-blocking network access is observed during MVP flows.
