# OpenRec Multi-Agent Development Workflow

## Purpose

This document defines how to use multiple agents to build OpenRec quickly without losing product quality. The operating model is:

1. Freeze shared contracts first.
2. Develop independent Core and App slices in parallel.
3. Keep recording pipeline integration narrow and controlled.
4. Use automatic tests, two-stage review, and manual macOS QA before release.

## Ground Rules

- `main` only accepts reviewed, tested, buildable changes.
- Every agent works in its own branch and worktree.
- Each agent owns a narrow write scope.
- App code uses `OpenRecCore` public APIs only.
- Core code does not depend on SwiftUI or App UI decisions.
- Public model or service API changes require a contract-change PR.
- No agent may add MVP non-goals: system audio, pause/resume, countdown, recording history, upload, telemetry, auto-update, signing/notarization, or arbitrary resolution controls.

## Recommended Agents

Use these six agents for the MVP. If fewer agents are available, merge adjacent roles, but keep the same responsibility boundaries.

| Agent | Responsibility | Primary Write Scope |
| --- | --- | --- |
| Coordinator | PR ordering, contract freeze, conflict decisions, batch sync, final integration checks | `docs/`, `.github/`, small integration fixes |
| Core Settings | JSON settings, schema version, defaults, invalid JSON recovery, setting tests | `Sources/OpenRecCore/Settings/`, `Tests/OpenRecCoreTests/SettingsStoreTests.swift` |
| Core Capture | display/window source discovery, source validation, configuration resolver, bitrate derivation | `Sources/OpenRecCore/Capture/`, `Sources/OpenRecCore/Recording/*ConfigurationResolver*`, related tests |
| Core System | permissions, microphone devices, global hotkeys, fallback/conflict handling | `Sources/OpenRecCore/Permissions/`, `Sources/OpenRecCore/Audio/`, `Sources/OpenRecCore/Hotkeys/`, related tests |
| Core Recording | `RecordingCoordinator`, recording state machine, ScreenCaptureKit/AVFoundation lifecycle, temp file finalization | `Sources/OpenRecCore/Recording/`, `Sources/OpenRecCore/Export/`, capture/audio pipeline adapters |
| App | MenuBarExtra shell, onboarding, preferences, source selection overlay, save panel, UI wiring | `Sources/OpenRecApp/`, `Tests/OpenRecAppTests/` |
| Release/QA | CI, packaging, README release notes, manual QA checklist | `.github/workflows/`, `scripts/`, `README.md`, `docs/qa/` |

## Worktree and Branch Strategy

Create one worktree per active agent:

```text
.worktrees/coordinator
.worktrees/core-settings
.worktrees/core-capture
.worktrees/core-system
.worktrees/core-recording
.worktrees/app
.worktrees/release-ci
```

Branch names:

```text
agent/project-scaffold
agent/core-contract-v0
agent/core-settings
agent/core-capture-config
agent/core-system-permissions-hotkeys
agent/core-recording-lifecycle
agent/app-shell
agent/app-onboarding-preferences
agent/app-source-selection
agent/release-ci
```

Rules:

- Start each branch from latest `main` or `integration/mvp`.
- Keep one task per branch.
- Rebase before review.
- Do not edit another agent's owned files.
- If two agents need the same public type, the Coordinator owns the change.

## Contract Freeze

Before broad parallel work starts, create contract documents:

```text
docs/contracts/core-api-v0.1.md
docs/contracts/app-core-boundary.md
docs/contracts/error-model-v0.1.md
docs/contracts/settings-schema-v0.1.md
```

Frozen contract items:

- `RecordingState`
- `CaptureSource`
- `AppSettings`
- `RecordingSettings`
- `ResolvedRecordingConfiguration`
- `OpenRecError`
- `SettingsStore`
- `CaptureSourceProvider`
- `PermissionChecker`
- `AudioDeviceProvider`
- `HotkeyManager`
- `ConfigurationResolver`
- `RecordingCoordinator`
- settings JSON schema
- error-to-UI behavior mapping
- preset values: MP4/MOV, H.264/HEVC, 25/30/60 fps, compact/standard/high

Contract change process:

1. Open `contract-change/<topic>`.
2. Explain reason, affected agents, alternatives, and migration impact.
3. Coordinator approves or rejects.
4. Affected agents acknowledge.
5. Merge contract PR before implementation PRs.

## Milestone Plan

### M0: Scaffold and Contracts

Serial work. No broad implementation yet.

Deliverables:

- SwiftUI app target.
- `OpenRecCore` Swift Package.
- Test target.
- Minimal CI.
- Frozen public models and service protocols.
- Contract docs.

Exit criteria:

- App and package build.
- Core smoke test runs.
- Other agents can build against stable public types.

### M1: Core Pure Logic

Parallel work.

Agents:

- Core Settings: JSON persistence, defaults, invalid JSON recovery.
- Core Capture: source metadata models, configuration resolver.
- Core System: permission state model, microphone enumeration, hotkey validation.

Exit criteria:

- Unit tests pass for each Core module.
- No UI dependency in Core.
- No public contract drift.

### M2: App UI With Mock Core

Parallel with M1 after M0 is complete.

Agents:

- App shell: menu bar popover, state display, start/stop button shell.
- Onboarding/preferences: permission status UI, settings controls, hotkey UI.
- Source selection: display picker and window overlay.
- Save flow shell: save/retry/discard UI.

Exit criteria:

- UI can show ready, recording, permission required, and error states with mock data.
- Preferences exposes only bounded presets.
- Source selection can cancel and return a selected target model.

### M3: Recording Pipeline

Mostly serial, with narrow parallel slices.

Owner:

- Core Recording owns final integration.

Possible sidecar slices:

- ScreenCaptureKit stream wrapper.
- AVAssetWriter output mapping.
- Microphone capture path.

Exit criteria:

- Display recording can create a playable temp file.
- Microphone can be included or fails clearly before start.
- Stop transitions to `awaitingSave(URL)`.
- Writer failure cleans temporary files and resources.

### M4: App-Core Integration

Serial integration.

Deliverables:

- Menu bar start/stop uses real `RecordingCoordinator`.
- Preferences uses real `SettingsStore`, microphone provider, and hotkey manager.
- Onboarding uses real `PermissionChecker`.
- Source selection validates real display/window targets.
- Save panel moves, retries, or discards finalized temp files.

Exit criteria:

- Full menu bar recording flow works for default MP4/H.264/30fps.
- Permission failure, target loss, and save cancellation are visible and recoverable.

### M5: Release Candidate

Parallel QA/docs/CI, then final serial release decision.

Deliverables:

- GitHub Actions build/test/package.
- Source ZIP artifact for release tags.
- README unsigned Gatekeeper note.
- Manual QA checklist.

Exit criteria:

- Full CI passes.
- `swift build`, `swift test`, `git diff --check`, and release packaging script tests pass.
- Real display recording verified on macOS hardware.
- Real window recording verified on macOS hardware.
- Mic recording verified on macOS hardware.
- Save/cancel/retry/discard verified.
- README states that the current release artifact is source ZIP only, not a signed or notarized `.app`.
- No release-blocking QA issues remain.

## PR Order

1. `PR-0 Project Scaffold`
2. `PR-1 Core API Contract`
3. `PR-2 Settings + Configuration`
4. `PR-3 Permissions + Audio Devices + Hotkey`
5. `PR-4 Source Discovery`
6. `PR-5 Recording Lifecycle`
7. `PR-6 App Shell`
8. `PR-7 Onboarding + Preferences`
9. `PR-8 Source Selection UI`
10. `PR-9 Save Flow + App-Core Integration`
11. `PR-10 Release Packaging + QA Docs`

`PR-2`, `PR-3`, `PR-4`, `PR-6`, `PR-7`, and `PR-8` can overlap once `PR-1` is merged. `PR-5` and `PR-9` are integration-heavy and should have single owners.

## Quality Gates

### Agent Branch to Review

Required:

- Relevant unit tests pass.
- `swift build` passes.
- Affected App target builds if the branch touches App code.
- No network, telemetry, update, upload, recording history, UserDefaults settings, or arbitrary resolution setting code.
- Agent report lists modified files, tests run, contract impact, and residual risks.

### Module PR to Integration

Required:

- `swift test`.
- `swift build`.
- Contract tests for settings JSON fixtures, error mapping, state transitions, and resolved configuration.
- Technical design still matches code.
- No PRD non-goals added.

### Integration to Main

Required:

- Full CI.
- macOS 14+ local smoke test.
- One real display recording.
- One real window recording.
- One microphone recording.
- MP4/H.264 default path works.
- Save, cancel save, retry save, and discard temp file are verified.

### Release Candidate

Required manual QA:

- First launch onboarding.
- Screen Recording permission grant, denial, revoke, re-check.
- Microphone permission grant, denial, revoke.
- Accessibility/Input Monitoring if final hotkey/window-selection implementation needs them.
- Single-display default selection.
- Multi-display explicit selection.
- Window overlay hover, click, Esc cancel, closed-window recovery.
- MP4/MOV and H.264/HEVC playback in QuickTime.
- 25/30/60 fps smoke verification.
- Microphone device switch and fallback.
- Global hotkey start/stop and conflict behavior.
- Temporary file cleanup.
- Release tag source ZIP download and unzip.
- SwiftPM developer launch path, or locally built unsigned app bundle launch path if one is produced outside CI.
- Unsigned Gatekeeper documentation, with no claim that CI ships a signed or notarized app archive.
- Offline behavior: no network requests.

## Review Model

Every PR gets two reviews.

### Domain Peer Review

Reviewer: neighboring module owner.

Checks:

- Module behavior is correct.
- Failure paths are tested.
- Ownership boundaries are respected.
- Implementation does not require callers to know internals.

### Quality and Integration Review

Reviewer: Coordinator, QA, or architecture owner.

Checks:

- Frozen contracts did not drift.
- App/Core boundary is intact.
- Error model remains consistent.
- JSON schema remains compatible.
- No MVP non-goals were added.
- Manual QA requirements are declared where automation is insufficient.

A PR may not merge if either review requests changes.

## Conflict Handling

Priority:

1. Contract correctness.
2. User-visible MVP behavior.
3. Core testability.
4. Small, isolated PRs.

Process:

1. Agent stops expanding the change.
2. Agent reports conflicting files, blocked work, desired decision, and suggested solution.
3. Coordinator assigns one owner to change the shared surface.
4. Other affected agents rebase after the owner merges.
5. Public type or service signature changes go through contract-change.

## Batch Sync Template

```text
Date:
Batch:
Agent:
Branch:
Status: Not started / In progress / Ready for review / Blocked / Merged

Completed:
Planned next:
Contract impact: None / Changed
Tests run:
Manual QA:
Blockers:
Coordinator decision needed:
Risk:
```

Batch syncs happen after:

- contract freeze,
- Core settings/config completion,
- source/permission/hotkey completion,
- first real recording,
- App-Core integration,
- release candidate.

## Agent Prompt Template

```text
You are the OpenRec [ROLE].

Project context:
OpenRec is a macOS 14+ SwiftUI menu bar screen recorder with an OpenRecCore Swift Package.
MVP includes display/window recording, microphone audio, MP4/MOV, H.264/HEVC,
25/30/60 fps presets, compact/standard/high quality presets, original source resolution,
save panel, JSON settings, custom global start/stop hotkey, and fully offline behavior.

Your responsibility:
[owned modules and files]

You may edit:
[exact paths]

You must not edit:
[other agent paths]

Hard constraints:
- Do not implement PRD non-goals.
- Do not change frozen contracts without a contract-change PR.
- Do not introduce network access, telemetry, uploads, update checks, or recording history.
- Do not use UserDefaults for settings persistence.
- Do not expose arbitrary resolution, arbitrary frame rate, or raw bitrate input in MVP.
- App code must call Core APIs instead of duplicating Core business logic.

Before coding:
1. Read docs/prd.md.
2. Read docs/technical-design.md.
3. Read docs/contracts/*.md.
4. Confirm the target branch is current.
5. State the acceptance criteria for this PR.

Deliver:
- Small focused changes.
- Tests or explicit manual QA notes.
- Contract impact report.
- Residual risk report.
- List of changed files.
```

## Completion Report Template

```text
Agent:
Branch:
PR:
Status: Ready for review / Blocked / Merged

Completed:
-

Changed files:
-

Contract impact:
- None / Changed

Tests:
- Command:
- Result:

Manual QA:
- Verified:
- Not verified:

Risks:
-

Blockers / decisions needed:
-

Recommended next step:
-
```

## Practical Execution Guidance

Do not maximize parallelism on day one. First finish scaffold and contract freeze. After that, run Core pure logic and App mock UI in parallel. Keep real recording lifecycle and final App-Core integration under one owner each, because ScreenCaptureKit, AVFoundation, writer finalization, save flow, and macOS permissions are tightly coupled.
