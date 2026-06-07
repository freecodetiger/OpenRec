# OpenRecCore API Contract v0.1

## Status

Frozen for MVP implementation. Changes require a `contract-change/*` branch and Coordinator approval.

## Public Models

- `CaptureSource`: `.display(DisplayID)` or `.window(WindowID)`.
- `CaptureMode`: `.display`, `.window`.
- `AppSettings`: schema version plus `RecordingSettings`.
- `RecordingSettings`: bounded MVP settings only.
- `ResolvedRecordingConfiguration`: concrete configuration used by capture and writer.
- `RecordingState`: `idle`, `preparing`, `recording`, `stopping`, `awaitingSave`, `failed`.
- `OpenRecError`: structured errors surfaced to App UI.

## MVP Presets

- Output formats: `mp4`, `mov`.
- Video codecs: `h264`, `hevc`.
- Frame rates: `25`, `30`, `60`.
- Quality presets: `compact`, `standard`, `high`.
- Resolution: source original size only.

## Boundary Rules

- App code must not duplicate Core business logic.
- Core code must not depend on SwiftUI.
- Settings persistence is JSON, not UserDefaults.
- Network, telemetry, updates, uploads, recording history, and arbitrary resolution controls are out of scope.

