import SwiftUI
import OpenRecCore

extension AppShellStatus {
    var shortTitle: String {
        switch self {
        case .ready:
            "Ready"
        case .recording:
            "Rec"
        case .permissionRequired:
            "Perm"
        case .error:
            "Error"
        }
    }

    var symbolName: String {
        switch self {
        case .ready:
            "checkmark.circle.fill"
        case .recording:
            "record.circle.fill"
        case .permissionRequired:
            "exclamationmark.triangle.fill"
        case .error:
            "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .ready:
            .green
        case .recording:
            .red
        case .permissionRequired:
            .orange
        case .error:
            .red
        }
    }
}

extension OutputFormat {
    var label: String {
        switch self {
        case .mp4:
            "MP4"
        case .mov:
            "MOV"
        }
    }
}

extension VideoCodec {
    var label: String {
        switch self {
        case .h264:
            "H.264"
        case .hevc:
            "HEVC/H.265"
        }
    }
}

extension QualityPreset {
    var label: String {
        switch self {
        case .compact:
            "Compact"
        case .standard:
            "Standard"
        case .high:
            "High"
        }
    }
}

extension FrameRatePreset {
    var label: String {
        "\(rawValue) fps"
    }
}

extension AudioPreset {
    var label: String {
        switch self {
        case .standard:
            "Standard"
        case .high:
            "High"
        }
    }
}

struct PermissionDisplayItem {
    var kind: PermissionKind
    var title: String
    var reason: String
    var isGranted: Bool

    static func items(for snapshot: AppShellSnapshot) -> [PermissionDisplayItem] {
        PermissionKind.allCases.map { kind in
            PermissionDisplayItem(
                kind: kind,
                title: kind.title,
                reason: kind.reason,
                isGranted: !snapshot.requiredPermissions.contains(kind)
            )
        }
    }
}

private extension PermissionKind {
    var title: String {
        switch self {
        case .screenRecording:
            "Screen Recording"
        case .microphone:
            "Microphone"
        case .accessibility:
            "Accessibility"
        case .inputMonitoring:
            "Input Monitoring"
        }
    }

    var reason: String {
        switch self {
        case .screenRecording:
            "Required for display and window capture."
        case .microphone:
            "Required when microphone audio is enabled."
        case .accessibility:
            "May be required for window selection and hotkeys."
        case .inputMonitoring:
            "May be required for global shortcut handling."
        }
    }
}
