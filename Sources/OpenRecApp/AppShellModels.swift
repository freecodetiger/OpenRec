import Foundation
import OpenRecCore

enum AppShellStatus: Equatable, Sendable {
    case ready
    case recording
    case permissionRequired
    case error

    var title: String {
        switch self {
        case .ready:
            "Ready"
        case .recording:
            "Recording"
        case .permissionRequired:
            "Permission Required"
        case .error:
            "Error"
        }
    }

    var detail: String {
        switch self {
        case .ready:
            "Choose a source and start recording."
        case .recording:
            "Capture is running with the selected settings."
        case .permissionRequired:
            "OpenRec needs macOS permissions before recording."
        case .error:
            "Resolve the issue before starting again."
        }
    }
}

struct SourceTargetOption: Equatable, Identifiable, Sendable {
    var id: String
    var mode: CaptureMode
    var source: CaptureSource
    var title: String
    var subtitle: String

    var summary: String {
        title
    }
}

struct MicrophoneOption: Equatable, Identifiable, Sendable {
    var id: String
    var deviceID: String?
    var title: String
    var subtitle: String
}

struct AppShellSnapshot: Equatable, Sendable {
    var status: AppShellStatus
    var mode: CaptureMode
    var selectedTarget: SourceTargetOption
    var availableTargets: [SourceTargetOption]
    var selectedMicrophoneID: String
    var microphones: [MicrophoneOption]
    var settings: RecordingSettings
    var requiredPermissions: [PermissionKind]
    var errorMessage: String?
    var elapsedTimeText: String?

    var selectedMicrophone: MicrophoneOption {
        microphones.first { $0.id == selectedMicrophoneID } ?? microphones[0]
    }
}

extension AppShellSnapshot {
    static let displayTarget = SourceTargetOption(
        id: "display-1",
        mode: .display,
        source: .display(DisplayID(rawValue: 1)),
        title: "Built-in Display",
        subtitle: "3024 x 1964, original resolution"
    )

    static let externalDisplayTarget = SourceTargetOption(
        id: "display-2",
        mode: .display,
        source: .display(DisplayID(rawValue: 2)),
        title: "Studio Display",
        subtitle: "5120 x 2880, original resolution"
    )

    static let windowTarget = SourceTargetOption(
        id: "window-42",
        mode: .window,
        source: .window(WindowID(rawValue: 42)),
        title: "Safari - Product Brief",
        subtitle: "Window recording target"
    )

    static let defaultMicrophone = MicrophoneOption(
        id: "default",
        deviceID: nil,
        title: "System Default",
        subtitle: "Uses the current macOS input device"
    )

    static let studioMicrophone = MicrophoneOption(
        id: "studio-mic",
        deviceID: "studio-mic",
        title: "Studio Microphone",
        subtitle: "External input device"
    )

    static let ready = AppShellSnapshot(
        status: .ready,
        mode: .display,
        selectedTarget: displayTarget,
        availableTargets: [displayTarget, externalDisplayTarget, windowTarget],
        selectedMicrophoneID: defaultMicrophone.id,
        microphones: [defaultMicrophone, studioMicrophone],
        settings: .defaults,
        requiredPermissions: [],
        errorMessage: nil,
        elapsedTimeText: nil
    )

    static let recording = AppShellSnapshot(
        status: .recording,
        mode: .display,
        selectedTarget: displayTarget,
        availableTargets: [displayTarget, externalDisplayTarget, windowTarget],
        selectedMicrophoneID: studioMicrophone.id,
        microphones: [defaultMicrophone, studioMicrophone],
        settings: .defaults,
        requiredPermissions: [],
        errorMessage: nil,
        elapsedTimeText: "00:12"
    )

    static let permissionRequired = AppShellSnapshot(
        status: .permissionRequired,
        mode: .display,
        selectedTarget: displayTarget,
        availableTargets: [displayTarget, externalDisplayTarget, windowTarget],
        selectedMicrophoneID: defaultMicrophone.id,
        microphones: [defaultMicrophone, studioMicrophone],
        settings: .defaults,
        requiredPermissions: [.screenRecording, .microphone],
        errorMessage: nil,
        elapsedTimeText: nil
    )

    static let error = AppShellSnapshot(
        status: .error,
        mode: .window,
        selectedTarget: windowTarget,
        availableTargets: [displayTarget, externalDisplayTarget, windowTarget],
        selectedMicrophoneID: defaultMicrophone.id,
        microphones: [defaultMicrophone, studioMicrophone],
        settings: .defaults,
        requiredPermissions: [],
        errorMessage: "The selected window is no longer available.",
        elapsedTimeText: nil
    )

    static let mockScenarios: [AppShellSnapshot] = [
        .ready,
        .recording,
        .permissionRequired,
        .error
    ]
}
