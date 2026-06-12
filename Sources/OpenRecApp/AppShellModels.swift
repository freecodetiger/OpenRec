import Foundation
import OpenRecCore

enum AppShellStatus: Equatable, Sendable {
    case ready
    case recording
    case awaitingSave
    case permissionRequired
    case error

    var title: String {
        switch self {
        case .ready:
            "Ready"
        case .recording:
            "Recording"
        case .awaitingSave:
            "Awaiting Save"
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
        case .awaitingSave:
            "Save or discard the finished recording."
        case .permissionRequired:
            "OpenRec needs macOS permissions before recording."
        case .error:
            "Resolve the issue before starting again."
        }
    }
}

enum WindowRecordingWorkflowState: Equatable, Sendable {
    case idle
    case selectingWindow(previousMode: CaptureMode, previousTargetID: String)
    case selectingApplication(previousMode: CaptureMode, previousTargetID: String)
    case selectingApplicationWindow(previousMode: CaptureMode, previousTargetID: String, applicationName: String)
    case configuringWindow(previousMode: CaptureMode, previousTargetID: String, selectedTargetID: String)
}

enum DisplayRecordingWorkflowState: Equatable, Sendable {
    case idle
    case selectingDisplay(previousMode: CaptureMode, previousTargetID: String)
}

struct ApplicationTargetOption: Equatable, Identifiable, Sendable {
    var id: String
    var title: String
    var windows: [SourceTargetOption]

    var subtitle: String {
        windows.count == 1 ? "1 window" : "\(windows.count) windows"
    }
}

struct SourceTargetOption: Equatable, Identifiable, Sendable {
    var id: String
    var mode: CaptureMode
    var source: CaptureSource
    var title: String
    var subtitle: String
    var screenFrame: CGRect? = nil

    var summary: String {
        title
    }

    var applicationName: String {
        let parts = title.split(separator: "-", maxSplits: 1).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return parts.first?.isEmpty == false ? parts[0] : title
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
    var permissionStatuses: [PermissionKind: PermissionStatus]
    var requiredPermissions: [PermissionKind]
    var errorMessage: String?
    var elapsedTimeText: String?
    var pendingSaveURL: URL?
    var appLanguage: AppLanguage
    var audioLevel: AudioLevelSnapshot

    var selectedMicrophone: MicrophoneOption {
        microphones.first { $0.id == selectedMicrophoneID } ?? microphones[0]
    }
}

struct SourceSelectionDraft: Equatable, Sendable {
    private let availableTargets: [SourceTargetOption]
    private(set) var mode: CaptureMode
    private(set) var selectedTargetID: String

    init(snapshot: AppShellSnapshot) {
        self.availableTargets = snapshot.availableTargets
        self.mode = snapshot.mode
        self.selectedTargetID = snapshot.selectedTarget.id
    }

    var visibleTargets: [SourceTargetOption] {
        availableTargets.filter { $0.mode == mode }
    }

    var selectedTarget: SourceTargetOption? {
        visibleTargets.first { $0.id == selectedTargetID }
    }

    var canApply: Bool {
        selectedTarget != nil
    }

    mutating func selectMode(_ mode: CaptureMode) {
        self.mode = mode
        if !visibleTargets.contains(where: { $0.id == selectedTargetID }),
           let firstTarget = visibleTargets.first {
            selectedTargetID = firstTarget.id
        }
    }

    mutating func selectTarget(id: String) {
        guard visibleTargets.contains(where: { $0.id == id }) else { return }
        selectedTargetID = id
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
        permissionStatuses: Dictionary(uniqueKeysWithValues: PermissionKind.allCases.map { ($0, .granted) }),
        requiredPermissions: [],
        errorMessage: nil,
        elapsedTimeText: nil,
        pendingSaveURL: nil,
        appLanguage: .english,
        audioLevel: .inactive
    )

    static let recording = AppShellSnapshot(
        status: .recording,
        mode: .display,
        selectedTarget: displayTarget,
        availableTargets: [displayTarget, externalDisplayTarget, windowTarget],
        selectedMicrophoneID: studioMicrophone.id,
        microphones: [defaultMicrophone, studioMicrophone],
        settings: .defaults,
        permissionStatuses: Dictionary(uniqueKeysWithValues: PermissionKind.allCases.map { ($0, .granted) }),
        requiredPermissions: [],
        errorMessage: nil,
        elapsedTimeText: "00:12",
        pendingSaveURL: nil,
        appLanguage: .english,
        audioLevel: AudioLevelSnapshot(
            rmsDBFS: -18,
            peakDBFS: -7,
            normalizedLevel: 0.78,
            state: .normal
        )
    )

    static let awaitingSave = AppShellSnapshot(
        status: .awaitingSave,
        mode: .display,
        selectedTarget: displayTarget,
        availableTargets: [displayTarget, externalDisplayTarget, windowTarget],
        selectedMicrophoneID: studioMicrophone.id,
        microphones: [defaultMicrophone, studioMicrophone],
        settings: .defaults,
        permissionStatuses: Dictionary(uniqueKeysWithValues: PermissionKind.allCases.map { ($0, .granted) }),
        requiredPermissions: [],
        errorMessage: nil,
        elapsedTimeText: nil,
        pendingSaveURL: URL(filePath: "/tmp/openrec-finalized.mp4"),
        appLanguage: .english,
        audioLevel: .inactive
    )

    static let permissionRequired = AppShellSnapshot(
        status: .permissionRequired,
        mode: .display,
        selectedTarget: displayTarget,
        availableTargets: [displayTarget, externalDisplayTarget, windowTarget],
        selectedMicrophoneID: defaultMicrophone.id,
        microphones: [defaultMicrophone, studioMicrophone],
        settings: .defaults,
        permissionStatuses: [
            .screenRecording: .denied,
            .microphone: .denied,
            .accessibility: .granted,
            .inputMonitoring: .granted
        ],
        requiredPermissions: [.screenRecording, .microphone],
        errorMessage: nil,
        elapsedTimeText: nil,
        pendingSaveURL: nil,
        appLanguage: .english,
        audioLevel: .inactive
    )

    static let error = AppShellSnapshot(
        status: .error,
        mode: .window,
        selectedTarget: windowTarget,
        availableTargets: [displayTarget, externalDisplayTarget, windowTarget],
        selectedMicrophoneID: defaultMicrophone.id,
        microphones: [defaultMicrophone, studioMicrophone],
        settings: .defaults,
        permissionStatuses: Dictionary(uniqueKeysWithValues: PermissionKind.allCases.map { ($0, .granted) }),
        requiredPermissions: [],
        errorMessage: "The selected window is no longer available.",
        elapsedTimeText: nil,
        pendingSaveURL: nil,
        appLanguage: .english,
        audioLevel: .inactive
    )

    static let mockScenarios: [AppShellSnapshot] = [
        .ready,
        .recording,
        .awaitingSave,
        .permissionRequired,
        .error
    ]
}
