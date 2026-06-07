import AppKit
import Foundation
import OpenRecCore

@MainActor
protocol SystemSettingsOpening: AnyObject {
    func openPermissionSettings(for kind: PermissionKind)
}

enum SystemSettingsPermissionPane {
    static func url(for kind: PermissionKind) -> URL {
        URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor(for: kind))")!
    }

    private static func anchor(for kind: PermissionKind) -> String {
        switch kind {
        case .screenRecording:
            "Privacy_ScreenCapture"
        case .microphone:
            "Privacy_Microphone"
        case .accessibility:
            "Privacy_Accessibility"
        case .inputMonitoring:
            "Privacy_ListenEvent"
        }
    }
}

final class NSWorkspaceSystemSettingsOpener: SystemSettingsOpening {
    func openPermissionSettings(for kind: PermissionKind) {
        NSWorkspace.shared.open(SystemSettingsPermissionPane.url(for: kind))
    }
}
