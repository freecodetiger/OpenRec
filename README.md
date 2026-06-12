# OpenRec

OpenRec is an open-source macOS screen recorder intended as a lightweight QuickTime screen recording replacement. The MVP is menu-bar-first, offline, privacy-preserving, and focused on reliable local recording rather than editing, sharing, analytics, or cloud workflows.

## MVP Scope

- macOS 14 or later.
- Display recording with explicit display selection.
- Window recording with click-to-select selection.
- App window recording by choosing an application first, then one visible window from that application.
- Microphone audio recording.
- Menu bar start and stop controls.
- User-configurable global hotkey that opens window selection from ready state and stops active recordings.
- Output formats: MP4 and MOV.
- Video codecs: H.264 and HEVC/H.265.
- Frame-rate presets: 25, 30, and 60 fps.
- Quality presets: compact, standard, and high.
- Original source resolution only.
- Save panel after recording; cancelling the save panel discards the temporary recording.

Out of scope for the MVP: system audio, pause/resume, countdowns, recording history, save retry after cancellation, built-in editing, uploads, telemetry, automatic updates, Mac App Store distribution, and arbitrary resolution controls.

## Build and Test

The current repository baseline is SwiftPM-buildable and SwiftPM-testable. It has a SwiftPM executable target for development, and the release pipeline can produce source and macOS app ZIP artifacts. The app artifact is not Developer ID signed or notarized unless signing credentials are supplied.

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

For release tags, CI creates release artifacts:

```sh
scripts/package-release.sh
```

The source ZIP is written to `dist/OpenRec-<tag>.zip` and contains the repository source at the tagged commit. Treat this artifact like source code: unzip it, inspect it, then build or test it locally with SwiftPM.

Release artifact smoke testing is intentionally run from an exported source tree so uncommitted local files cannot affect the result:

```sh
scripts/test-release-artifact.sh
```

By default the smoke test exports `git archive HEAD` to a temporary directory and runs `swift test` there. To validate a packaged source ZIP instead, pass the ZIP path:

```sh
scripts/test-release-artifact.sh dist/OpenRec-<tag>.zip
```

For unusually constrained CI jobs, `OPENREC_RELEASE_SMOKE_COMMAND` can replace the default `swift test` command with another lightweight validation command.

The package script also creates `dist/OpenRec-<version>-macos.zip`, which contains `OpenRec.app`, plus a `.sha256` checksum file. Without Developer ID signing variables, this app artifact is unsigned or ad-hoc signed only. It does not include a Sparkle feed, updater, installer, telemetry, or network service.

## Privacy

OpenRec is designed to run fully offline in the MVP:

- No network requests.
- No telemetry or analytics.
- No crash reporting.
- No update checks.
- No upload or sharing flow.
- Settings are stored locally as JSON in `~/Library/Application Support/OpenRec/settings.json`.
- Temporary recordings are local and are cleaned up after save, explicit discard, or save-panel cancellation.

## Release Artifacts and Gatekeeper

OpenRec currently distinguishes two artifact types:

- Source ZIP: a repository source archive for developers. It is expected to build with SwiftPM and is not a macOS application bundle.
- macOS app artifact: a packaged `OpenRec.app` for manual testing or distribution review. The current CI can build this without Apple credentials by leaving it unsigned or ad-hoc signed.

The development `.app` wrapper created by `scripts/launch-dev-app.sh` is ad-hoc signed for local TCC permission stability only. It is not notarized, is not an end-user release artifact, and does not require Apple Developer credentials.

If a developer builds or distributes an unsigned or ad-hoc signed app bundle from this source, macOS Gatekeeper may block it after download or transfer. Users may need to manually allow the app in System Settings or use the Finder context menu Open flow for unsigned software they trust.

If a release publishes a Developer ID signed and notarized macOS app artifact, verify it before installation with:

```sh
codesign --verify --deep --strict --verbose=2 OpenRec.app
spctl -a -vv -t exec OpenRec.app
xcrun stapler validate OpenRec.app
```

Developer ID signing and notarization are optional package-script paths. CI only passes these values to the tag packaging step, and the script does not require them for local dry-runs or unsigned artifacts.

Environment variables:

- `OPENREC_VERSION` or `OPENREC_RELEASE_VERSION`: overrides the version used in `dist/OpenRec-<version>.zip`, `dist/OpenRec-<version>-macos.zip`, `CFBundleVersion`, and `CFBundleShortVersionString`. Tags such as `v1.2.3` are used when these are unset.
- `OPENREC_APP_PATH`: packages an existing `.app` instead of building one with `swift build -c release`.
- `OPENREC_BUNDLE_ID`: overrides the production bundle identifier, which defaults to `com.freecodetiger.OpenRec`.
- `OPENREC_SHORT_VERSION`, `OPENREC_BUILD_VERSION`: override generated bundle version metadata.
- `OPENREC_SIGN_IDENTITY`: Developer ID Application identity for hardened runtime signing.
- `OPENREC_ENTITLEMENTS`: optional entitlements plist path for `codesign`.
- `OPENREC_NOTARY_PROFILE`: notarytool keychain profile.
- `OPENREC_NOTARY_APPLE_ID`, `OPENREC_NOTARY_TEAM_ID`, `OPENREC_NOTARY_PASSWORD`: Apple ID notarization credentials used when no profile is supplied.
- `OPENREC_NOTARIZE=1`: require notarization; packaging fails if Developer ID signing identity or notary credentials are missing.
- `OPENREC_AD_HOC_SIGN=1`: ad-hoc sign when no Developer ID identity is configured.
- `OPENREC_SKIP_CODESIGN=1`: leave the app unsigned even if signing-related variables are present.
- `OPENREC_DRY_RUN=1`: print signing, notarization, and stapler commands without running them.
- `OPENREC_PACKAGE_SOURCE_ZIP=0`: skip the source ZIP and only create the macOS app ZIP.

With `OPENREC_SIGN_IDENTITY` and notary credentials set, packaging uses hardened runtime signing, `xcrun notarytool submit --wait`, `xcrun stapler staple`, then creates the final `dist/OpenRec-<version>-macos.zip` and `dist/OpenRec-<version>-macos.zip.sha256`.

## License

OpenRec is released under the MIT License. See `LICENSE`.
