import Foundation
import OpenRecCore

#if os(macOS)
import AVFoundation
import CoreGraphics
#endif

@MainActor
protocol PermissionRequesting: AnyObject {
    func requestPermission(for kind: PermissionKind) async
}

@MainActor
final class SystemPermissionRequester: PermissionRequesting {
    func requestPermission(for kind: PermissionKind) async {
        switch kind {
        case .microphone:
            #if os(macOS)
            _ = await AVCaptureDevice.requestAccess(for: .audio)
            #endif
        case .screenRecording:
            #if os(macOS)
            _ = CGRequestScreenCaptureAccess()
            #endif
        case .accessibility, .inputMonitoring:
            return
        }
    }
}
