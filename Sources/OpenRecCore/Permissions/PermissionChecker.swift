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
