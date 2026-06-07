# App/Core Boundary

## App Owns

- SwiftUI menu bar shell.
- Onboarding and Preferences UI.
- Display/window selection interactions.
- Save panel.
- User-facing copy and layout.

## Core Owns

- Settings model and JSON persistence.
- Source discovery and validation.
- Permission checks.
- Audio device discovery.
- Hotkey validation and registration.
- Configuration resolution.
- Recording state machine.
- Capture and writer lifecycle.
- Structured errors.

## Rule

App uses Core public APIs. App must not reimplement Core validation rules for settings, sources, permissions, hotkeys, or recording state transitions.

