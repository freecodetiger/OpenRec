#if os(macOS)
import ApplicationServices
import AVFoundation
import CoreGraphics
#endif

public enum PermissionStatus: String, Codable, Equatable, Sendable {
    case granted
    case denied
    case notDetermined
    case unknown
}

public protocol PermissionStatusProvider: Sendable {
    func status(for kind: PermissionKind) -> PermissionStatus
}

public struct PermissionChecker: Sendable {
    private let provider: any PermissionStatusProvider

    public init(provider: any PermissionStatusProvider) {
        self.provider = provider
    }

    public func status(for kind: PermissionKind) -> PermissionStatus {
        provider.status(for: kind)
    }

    public func statuses(for kinds: [PermissionKind] = PermissionKind.allCases) -> [PermissionKind: PermissionStatus] {
        Dictionary(uniqueKeysWithValues: kinds.map { ($0, status(for: $0)) })
    }

    public func requireGranted(_ kinds: [PermissionKind]) throws {
        for kind in kinds where status(for: kind) != .granted {
            throw OpenRecError.permissionDenied(kind)
        }
    }
}

public struct InMemoryPermissionStatusProvider: PermissionStatusProvider {
    private let statuses: [PermissionKind: PermissionStatus]
    private let defaultStatus: PermissionStatus

    public init(
        statuses: [PermissionKind: PermissionStatus],
        defaultStatus: PermissionStatus = .unknown
    ) {
        self.statuses = statuses
        self.defaultStatus = defaultStatus
    }

    public func status(for kind: PermissionKind) -> PermissionStatus {
        statuses[kind] ?? defaultStatus
    }
}

#if os(macOS)
public struct SystemPermissionStatusProvider: PermissionStatusProvider {
    private let microphoneAuthorizationStatus: @Sendable () -> AVAuthorizationStatus
    private let screenRecordingStatus: @Sendable () -> PermissionStatus
    private let accessibilityStatus: @Sendable () -> PermissionStatus
    private let inputMonitoringStatus: @Sendable () -> PermissionStatus

    public init(
        microphoneAuthorizationStatus: @escaping @Sendable () -> AVAuthorizationStatus = {
            AVCaptureDevice.authorizationStatus(for: .audio)
        },
        screenRecordingStatus: @escaping @Sendable () -> PermissionStatus = {
            CGPreflightScreenCaptureAccess() ? .granted : .denied
        },
        accessibilityStatus: @escaping @Sendable () -> PermissionStatus = {
            AXIsProcessTrusted() ? .granted : .denied
        },
        inputMonitoringStatus: @escaping @Sendable () -> PermissionStatus = {
            CGPreflightListenEventAccess() ? .granted : .denied
        }
    ) {
        self.microphoneAuthorizationStatus = microphoneAuthorizationStatus
        self.screenRecordingStatus = screenRecordingStatus
        self.accessibilityStatus = accessibilityStatus
        self.inputMonitoringStatus = inputMonitoringStatus
    }

    public func status(for kind: PermissionKind) -> PermissionStatus {
        switch kind {
        case .microphone:
            return Self.permissionStatus(from: microphoneAuthorizationStatus())
        case .screenRecording:
            return screenRecordingStatus()
        case .accessibility:
            return accessibilityStatus()
        case .inputMonitoring:
            return inputMonitoringStatus()
        }
    }

    private static func permissionStatus(from status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .unknown
        }
    }
}
#endif
