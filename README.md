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

The current repository baseline is SwiftPM-buildable and SwiftPM-testable. It has a SwiftPM executable target for development, but the release pipeline does not yet produce a signed `.app` bundle, installer, or notarized archive.

```sh
swift build
swift test
```

For local app permission testing, launch the development `.app` wrapper with:

```sh
scripts/launch-dev-app.sh
```

This wrapper uses the stable bundle identifier `dev.freecodetiger.OpenRec` and a stable local code signing requirement so macOS TCC permissions do not drift across rebuilds. If Screen Recording or Microphone still appears denied after switching launch methods, remove the old OpenRec entry in System Settings, then grant permissions again to this development app.

For quick non-permission development, the SwiftPM executable can also be launched with:

```sh
swift run OpenRecApp
```

These are developer launch paths, not end-user app distribution paths. macOS permissions such as Screen Recording, Microphone, and global hotkey access must still be granted on real hardware.

For release tags, CI also creates a source ZIP artifact:

```sh
scripts/package-release.sh
```

The ZIP is written to `dist/` and contains the repository source at the tagged commit. It does not contain a prebuilt `.app`, code signature, notarization ticket, Sparkle feed, updater, or installer.

## Privacy

OpenRec is designed to run fully offline in the MVP:

- No network requests.
- No telemetry or analytics.
- No crash reporting.
- No update checks.
- No upload or sharing flow.
- Settings are stored locally as JSON in `~/Library/Application Support/OpenRec/settings.json`.
- Temporary recordings are local and should be cleaned up after save or discard.

## Release Stage and Gatekeeper

MVP release artifacts are source archives only. If a developer builds an app bundle locally from this source, that local build is unsigned and not notarized unless they add their own signing pipeline. macOS Gatekeeper may block unsigned app bundles after download or transfer. Users may need to manually allow the app in System Settings or use the Finder context menu Open flow for unsigned software they trust.

## License

OpenRec is released under the MIT License. See `LICENSE`.
