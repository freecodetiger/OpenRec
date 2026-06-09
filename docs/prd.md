# OpenRec PRD

## Overview

OpenRec is an open-source macOS screen recorder designed as a lightweight replacement for QuickTime screen recording. The product should be offline, privacy-preserving, menu-bar-first, and simple enough for daily use while still exposing a small set of practical recording presets.

OpenRec is not a video editor, cloud sharing product, collaboration tool, or telemetry-backed commercial recorder.

## Goals

- Provide a minimal, reliable screen recording workflow on macOS 14+.
- Support display recording and window recording in the first release.
- Record microphone audio together with the screen.
- Let users choose common output and quality presets before recording.
- Keep the app fully offline with local-only settings and recording files.
- Ship as an open-source macOS app through GitHub Releases.

## Non-Goals

- System audio recording.
- Pause and resume.
- Countdown before recording.
- Recording history.
- Retry save after cancelling the save panel.
- Built-in preview or editing.
- Recording upload, sharing links, comments, or team workflows.
- Telemetry, analytics, crash reporting, or any network access.
- Automatic updates.
- Code signing, notarization, Mac App Store distribution, or Homebrew Cask for the first release.
- Mouse click effects, ripples, or cursor highlighting.

## Target Platform

- macOS 14 or later.
- Apple Silicon and Intel Mac support should be kept if the toolchain and frameworks allow it.

## License

OpenRec will use the MIT License.

## MVP Scope

The first release includes:

- Menu bar app.
- First-launch permission onboarding.
- Display recording with explicit display selection.
- Window recording with click-to-select window interaction.
- App window recording: choose an application first, then record one visible window from that application.
- Microphone recording.
- Menu bar start and stop controls.
- Menu bar quick selection for recording mode, target, and microphone.
- Preferences window for full settings.
- Output formats: MP4 and MOV.
- Video codecs: H.264 and HEVC/H.265.
- Frame-rate presets: 25, 30, and 60 fps.
- Quality presets: compact, standard, and high quality.
- Original source resolution only. Users do not choose 720p, 1080p, custom size, or scaling in MVP.
- Save panel after recording finishes.
- GitHub Actions build/test and simple release packaging.
- GitHub Releases distribution as source ZIP and unsigned or ad-hoc signed macOS app ZIP for the current MVP stage.

## Recording Modes

### Display Recording

Users choose a recording mode named "Display Recording". OpenRec must then select a concrete display:

- If there is one display, it can be selected by default and shown in the menu.
- If there are multiple displays, the user must choose the target display before recording.
- The recording uses the selected display's original resolution.

### Window Recording

Users choose a recording mode named "Window Recording", then enter a selection mode:

- A transparent overlay lets the user hover and select eligible windows.
- Hovering highlights the candidate window.
- Clicking selects the window.
- Esc cancels selection.
- If the selected window later becomes unavailable, OpenRec prompts the user to select a new target.

### App Window Recording

Users choose a recording path named "App Window Recording". OpenRec must not present this as recording an entire application:

- The user first chooses an application that has visible recordable windows.
- OpenRec then lets the user choose one visible window from that application.
- The actual recording target is the selected window.
- Closing or changing the selected window follows the same recovery behavior as Window Recording.

### Future Region Recording

Custom region recording is planned after MVP. It should use the selected region's original pixel size and should not require changing the MVP settings model.

## Recording Settings

Settings are selected before recording. Recording-time changes are not supported in MVP because format, codec, frame rate, and quality influence the capture and writer pipeline.

Users can configure:

- Output format: MP4 or MOV.
- Video codec: H.264 or HEVC/H.265.
- Frame rate: 25, 30, or 60 fps.
- Quality preset: compact, standard, or high.
- Cursor inclusion: show the system cursor.
- Microphone device.
- Start/stop global hotkey.

Defaults:

- Output format: MP4.
- Video codec: H.264.
- Frame rate: 30 fps.
- Quality preset: standard.
- Resolution: original source resolution.
- Cursor: shown.
- Microphone: system default input device.

## Recording Flow

1. User opens the menu bar popover.
2. User chooses Display Recording, Window Recording, or App Window Recording.
3. User selects a concrete display or window. In App Window Recording, the user chooses an application first, then chooses one of that application's visible windows.
4. User confirms or adjusts recording settings before starting.
5. OpenRec validates permissions, target availability, and settings.
6. User starts recording from the menu bar or global hotkey.
7. OpenRec records screen video and microphone audio.
8. User stops recording from the menu bar or global hotkey.
9. OpenRec finalizes the temporary output file.
10. OpenRec shows a save panel.
11. User saves the file or cancels the save panel.
12. If the user cancels the save panel, OpenRec discards the temporary recording and returns to ready.

## Permissions

The first launch shows an onboarding flow before the app enters normal menu bar mode.

Required or potentially required permissions:

- Screen Recording: capture displays and windows.
- Microphone: record microphone input.
- Accessibility and/or Input Monitoring: support global hotkeys and click-to-select window behavior if required by the final implementation.

The app should explain why each permission is needed, show current permission status, provide a button to open System Settings, and allow users to re-check permissions.

## UI Requirements

### Menu Bar Popover

The menu bar popover includes:

- Current state: ready, recording, permission required, or error.
- Recording mode.
- Selected display or selected window.
- Microphone quick selector.
- Start or stop recording action.
- Preferences action.
- Quit action.

### Preferences

Preferences include:

- Recording: default mode and cursor behavior.
- Video: output format, codec, frame rate, and quality preset.
- Audio: microphone device and audio quality preset.
- Shortcuts: saved global start/stop hotkey status; custom shortcut capture UI is deferred.
- Permissions: status and System Settings links.

## Privacy

OpenRec is fully offline in MVP:

- No network requests.
- No telemetry.
- No crash reporting.
- No update checks.
- No upload or sharing.
- Settings are stored locally as JSON.
- Temporary recordings are stored locally and cleaned up after save, explicit discard, or save-panel cancellation.

## Release Plan

Distribution:

- GitHub Releases.
- Source ZIP artifact required.
- macOS app ZIP artifact required for manual distribution review.
- DMG, Developer ID signing, notarization, and Mac App Store distribution are not required for the current MVP release pipeline.

The README must explain that unsigned builds may require users to manually allow the app in macOS Gatekeeper.

## Roadmap

- v0.1: MVP with display/window recording, microphone audio, MP4/MOV, H.264/HEVC, presets, save panel.
- v0.2: Custom region recording.
- v0.3: System audio recording.
- v0.4: Signing, notarization, and Homebrew Cask.
- v0.5: Optional post-recording export or transcoding presets.
- Future: save retry after cancellation, if product requirements change.
