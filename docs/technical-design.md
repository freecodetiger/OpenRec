# OpenRec Technical Design

## Architecture

OpenRec uses a SwiftUI menu bar app plus a separate Swift Package named `OpenRecCore`.

The App target owns presentation and macOS UI integration. The Core package owns recording state, source discovery, settings, permission checks, hotkey logic, encoding configuration, and structured errors.

```text
OpenRec/
  OpenRecApp/
    App/
    UI/
    Onboarding/
    Preferences/
    SourceSelection/
  Packages/
    OpenRecCore/
      Sources/OpenRecCore/
        Recording/
        Capture/
        Audio/
        Permissions/
        Hotkeys/
        Settings/
        Export/
      Tests/OpenRecCoreTests/
  docs/
    prd.md
    technical-design.md
  .github/workflows/
```

## Frameworks

Primary Apple frameworks:

- SwiftUI: menu bar app shell, preferences, and onboarding.
- AppKit: save panel, overlays, window-level behavior, and system integration that SwiftUI does not cover cleanly.
- ScreenCaptureKit: display and window capture.
- AVFoundation: microphone capture and file writing.
- UserNotifications: local completion or error notifications if needed.

References:

- ScreenCaptureKit: https://developer.apple.com/documentation/screencapturekit
- AVAssetWriter: https://developer.apple.com/documentation/avfoundation/avassetwriter
- MenuBarExtra: https://developer.apple.com/documentation/swiftui/menubarextra

## Core Modules

### RecordingCoordinator

Coordinates recording state transitions and owns the high-level recording lifecycle.

```swift
enum RecordingState: Equatable {
    case idle
    case preparing(CaptureSource)
    case recording(RecordingSession)
    case stopping(RecordingSession)
    case awaitingSave(URL)
    case failed(OpenRecError)
}
```

Responsibilities:

- Validate permissions and settings before recording.
- Resolve the selected source and presets into a concrete configuration.
- Start and stop capture.
- Finalize temporary output.
- Return structured errors.

### CaptureSourceProvider

Discovers displays and windows and maps UI selection into a capture source.

```swift
enum CaptureSource: Codable, Equatable {
    case display(DisplayID)
    case window(WindowID)
}
```

Future region recording can extend this model:

```swift
case region(displayID: DisplayID, rect: CGRect)
```

### SettingsStore

Persists settings as JSON at:

```text
~/Library/Application Support/OpenRec/settings.json
```

Responsibilities:

- Create default settings on first launch.
- Load, validate, and save settings.
- Support future schema migration with a top-level version field.

Suggested model:

```swift
struct AppSettings: Codable, Equatable {
    var schemaVersion: Int
    var recording: RecordingSettings
}

struct RecordingSettings: Codable, Equatable {
    var defaultMode: CaptureMode
    var outputFormat: OutputFormat
    var videoCodec: VideoCodec
    var qualityPreset: QualityPreset
    var frameRate: FrameRatePreset
    var includeCursor: Bool
    var microphoneDeviceID: String?
    var audioPreset: AudioPreset
    var globalHotkey: Hotkey?
}

enum OutputFormat: String, Codable {
    case mp4
    case mov
}

enum VideoCodec: String, Codable {
    case h264
    case hevc
}

enum QualityPreset: String, Codable {
    case compact
    case standard
    case high
}

enum FrameRatePreset: Int, Codable {
    case fps25 = 25
    case fps30 = 30
    case fps60 = 60
}
```

MVP intentionally does not persist arbitrary resolution, custom frame rate, or raw bitrate values.

### ConfigurationResolver

Converts user settings and source metadata into a concrete recording configuration.

```swift
struct ResolvedRecordingConfiguration: Equatable {
    var source: CaptureSource
    var pixelSize: CGSize
    var outputFormat: OutputFormat
    var videoCodec: VideoCodec
    var bitrate: Int
    var frameRate: Int
    var includeCursor: Bool
    var microphoneDeviceID: String?
}
```

Rules:

- `pixelSize` always equals the source's original capture size.
- Bitrate is derived from source size, frame rate, quality preset, and codec.
- HEVC may use a lower bitrate than H.264 for the same quality preset.
- Unsupported combinations fail before recording starts.

### AudioDeviceProvider

Lists available input devices and resolves the selected microphone.

Rules:

- Missing selected device falls back to the system default.
- If no microphone is available and microphone recording is required, recording fails before start.

### PermissionChecker

Checks Screen Recording, Microphone, and any required Accessibility or Input Monitoring permission.

Rules:

- Permissions are checked during onboarding.
- Permissions are checked again before each recording.
- Permission failure returns `OpenRecError.permissionDenied`.

### HotkeyManager

Registers a saved global start/stop hotkey when one exists.

Rules:

- User-facing shortcut capture UI is deferred beyond the current MVP.
- Conflicting hotkeys are rejected and not saved.
- If registration fails at app launch, the app disables the hotkey and shows a preferences error.

## Recording Flow

1. App asks Core for available capture sources.
2. User selects a display or window.
3. App calls Core with selected source and current settings.
4. Core checks permissions.
5. Core validates the selected target still exists.
6. Core resolves settings into `ResolvedRecordingConfiguration`.
7. Core creates the capture stream and writer.
8. Core records to a temporary file.
9. User stops recording.
10. Core stops capture, finalizes the writer, and returns the temporary file URL.
11. App shows `NSSavePanel`.
12. App moves the file to the selected destination or asks Core to discard it when the save panel is cancelled.

## Capture and Encoding

Screen video:

- Use ScreenCaptureKit to capture the selected display or window.
- Apply original source dimensions.
- Apply selected frame-rate preset.
- Include the system cursor.

Microphone audio:

- Use the selected microphone device or system default.
- Encode audio as AAC.
- Keep audio and video timestamps aligned in the writer pipeline.

File writing:

- Use AVFoundation file writing.
- Use MP4 or MOV container based on settings.
- Use H.264 or HEVC video codec based on settings.
- Write to a temporary file first.
- Move to the final destination only after writer finalization and user save confirmation.

Recording-time setting changes are not supported in MVP.

## Source Selection

### Display Selection

- Enumerate available displays.
- Default to the only display if exactly one is present.
- Require explicit selection if multiple displays are present.
- Revalidate the display before recording starts.

### Window Selection

- Open a transparent selection overlay.
- Highlight eligible windows on hover.
- Select the clicked window.
- Esc cancels selection.
- Store the selected window ID and display name/title for UI display.
- Revalidate the window before recording starts.

The window selection UI is in the App target. Source discovery and validation are in Core.

## Error Model

```swift
enum OpenRecError: Error, Equatable {
    case permissionDenied(PermissionKind)
    case captureSourceUnavailable(CaptureSource)
    case captureConfigurationInvalid(String)
    case microphoneUnavailable(String?)
    case hotkeyConflict
    case writerInitializationFailed(String)
    case writerFailed(String)
    case saveCancelled(String)
    case unknown(String)
}
```

Handling rules:

- Permission denied: return to onboarding or permissions preferences.
- Source unavailable: ask the user to reselect display or window.
- Invalid configuration: block start and show the invalid preset combination.
- Microphone unavailable: fall back to default when possible; otherwise block start.
- Hotkey conflict: reject setting and keep the previous hotkey.
- Writer failure: stop capture and clean up the temporary file.
- Save cancelled: discard the temporary recording and return to ready.

## Preferences UI

Preferences is a normal SwiftUI window with these sections:

- Recording: default mode and cursor behavior.
- Video: format, codec, frame rate, quality preset.
- Audio: microphone device and audio preset.
- Shortcuts: global hotkey capture and validation.
- Permissions: permission status, System Settings links, and re-check button.

All video choices are bounded presets. No arbitrary bitrate, frame rate, or resolution text input is exposed in MVP.

## Persistence

Settings are stored in JSON, not UserDefaults.

Implementation requirements:

- Atomic writes: write to a temporary file then replace `settings.json`.
- Schema version in the JSON file.
- On invalid JSON, keep the corrupt file as `settings.invalid.json` and recreate defaults.
- Avoid storing any recording history.
- Avoid storing file paths to recordings.

## Privacy and Offline Behavior

OpenRec must not make network requests in MVP.

No telemetry, crash reports, update checks, uploads, or external APIs are allowed. All configuration and temporary recordings remain on the user's Mac.

## Testing

Unit tests in `OpenRecCoreTests`:

- JSON settings load/save/default creation.
- Invalid JSON recovery.
- Preset-to-configuration resolution.
- Bitrate derivation by source size, frame rate, quality, and codec.
- Recording state transitions.
- Error mapping.
- Hotkey conflict handling.
- Missing microphone fallback.
- Missing display/window target handling.

App-level tests and manual QA:

- First-launch permission onboarding.
- Single-display recording.
- Multi-display selection.
- Window selection and cancellation.
- MP4 and MOV output.
- H.264 and HEVC output.
- 25, 30, and 60 fps presets.
- Microphone switching.
- Stop and save panel.
- Save-panel cancellation discard.
- Permission revocation and recovery.

## CI and Release

GitHub Actions:

- Run on `macos-latest`.
- Build the Swift package and app.
- Run tests.
- Run whitespace and release packaging script checks.
- On release tag, create source ZIP and macOS app ZIP artifacts with checksums.

MVP release does not include a DMG, auto-update, Mac App Store distribution, or Homebrew Cask. The macOS app ZIP is unsigned or ad-hoc signed unless Developer ID signing and notarization credentials are supplied.

## Implementation Assumptions to Validate

- Global hotkeys should first use the least invasive macOS API that supports the required shortcut behavior. If the final implementation requires Accessibility or Input Monitoring, onboarding must request and explain that permission.
- Click-to-select window should first use ScreenCaptureKit window metadata plus overlay hit testing. If reliable hit testing requires Accessibility, onboarding must request and explain that permission.
- Microphone capture should remain a separate AVFoundation input path unless ScreenCaptureKit provides a simpler, reliable microphone path for the final macOS 14+ implementation.

These assumptions affect implementation detail, not MVP product scope.
