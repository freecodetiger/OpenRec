public enum PermissionKind: String, Codable, Equatable, Sendable, CaseIterable {
    case screenRecording
    case microphone
    case accessibility
    case inputMonitoring
}

public enum OpenRecError: Error, Equatable, Sendable {
    case permissionDenied(PermissionKind)
    case captureSourceUnavailable(CaptureSource)
    case captureConfigurationInvalid(String)
    case microphoneUnavailable(String?)
    case hotkeyConflict
    case writerInitializationFailed(String)
    case writerFailed(String)
    case saveCancelled(String)
    case unknown(String)
}

