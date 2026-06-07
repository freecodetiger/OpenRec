# OpenRec

OpenRec is an open-source macOS screen recorder intended as a lightweight QuickTime screen recording replacement. The MVP is menu-bar-first, offline, privacy-preserving, and focused on reliable local recording rather than editing, sharing, analytics, or cloud workflows.

## MVP Scope

- macOS 14 or later.
- Display recording with explicit display selection.
- Window recording with click-to-select selection.
- Microphone audio recording.
- Menu bar start and stop controls.
- User-configurable global start/stop hotkey.
- Output formats: MP4 and MOV.
- Video codecs: H.264 and HEVC/H.265.
- Frame-rate presets: 25, 30, and 60 fps.
- Quality presets: compact, standard, and high.
- Original source resolution only.
- Save panel after recording with save retry or discard behavior.

Out of scope for the MVP: system audio, pause/resume, countdowns, recording history, built-in editing, uploads, telemetry, automatic updates, signing, notarization, Mac App Store distribution, and arbitrary resolution controls.

## Build and Test

The current repository baseline is SwiftPM-testable. A full Xcode app archive can be added later when the app target and signing path are ready.

```sh
swift test
```

For release tags, CI also creates a source ZIP artifact:

```sh
scripts/package-release.sh
```

The ZIP is written to `dist/`.

## Privacy

OpenRec is designed to run fully offline in the MVP:

- No network requests.
- No telemetry or analytics.
- No crash reporting.
- No update checks.
- No upload or sharing flow.
- Settings are stored locally as JSON in `~/Library/Application Support/OpenRec/settings.json`.
- Temporary recordings are local and should be cleaned up after save or discard.

## Unsigned Builds and Gatekeeper

MVP release builds are not code signed or notarized. macOS Gatekeeper may block an unsigned app after download. Users may need to manually allow the app in System Settings or use the Finder context menu Open flow for unsigned software they trust.

## License

OpenRec is released under the MIT License. See `LICENSE`.
