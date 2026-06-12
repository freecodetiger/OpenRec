import Foundation

public struct DisplaySourceMetadata: Equatable, Sendable {
    public var id: DisplayID
    public var name: String
    public var pixelSize: CGSize
    public var isAvailable: Bool

    public init(
        id: DisplayID,
        name: String,
        pixelSize: CGSize,
        isAvailable: Bool
    ) {
        self.id = id
        self.name = name
        self.pixelSize = pixelSize
        self.isAvailable = isAvailable
    }

    public var source: CaptureSource {
        .display(id)
    }

    public var captureMetadata: CaptureSourceMetadata {
        CaptureSourceMetadata(
            source: source,
            pixelSize: pixelSize,
            isAvailable: isAvailable
        )
    }
}

public struct WindowSourceMetadata: Equatable, Sendable {
    public var id: WindowID
    public var title: String
    public var owningApplicationName: String?
    public var pixelSize: CGSize
    public var screenFrame: CGRect?
    public var isAvailable: Bool

    public init(
        id: WindowID,
        title: String,
        owningApplicationName: String?,
        pixelSize: CGSize,
        screenFrame: CGRect? = nil,
        isAvailable: Bool
    ) {
        self.id = id
        self.title = title
        self.owningApplicationName = owningApplicationName
        self.pixelSize = pixelSize
        self.screenFrame = screenFrame
        self.isAvailable = isAvailable
    }

    public var source: CaptureSource {
        .window(id)
    }

    public var captureMetadata: CaptureSourceMetadata {
        CaptureSourceMetadata(
            source: source,
            pixelSize: pixelSize,
            isAvailable: isAvailable
        )
    }
}

public protocol CaptureSourceProvider: Sendable {
    func displays() async throws -> [DisplaySourceMetadata]
    /// Returns on-screen windows in front-to-back order so visual selection can resolve
    /// overlapping windows by choosing the first recordable hit.
    func windows() async throws -> [WindowSourceMetadata]
}

public struct InMemoryCaptureSourceProvider: CaptureSourceProvider {
    private let displayMetadata: [DisplaySourceMetadata]
    private let windowMetadata: [WindowSourceMetadata]

    public init(
        displays: [DisplaySourceMetadata],
        windows: [WindowSourceMetadata]
    ) {
        displayMetadata = displays
        windowMetadata = windows
    }

    public func displays() async throws -> [DisplaySourceMetadata] {
        displayMetadata
    }

    public func windows() async throws -> [WindowSourceMetadata] {
        windowMetadata
    }
}

public enum CaptureSourceSelection {
    public static func defaultDisplaySource(
        from displays: [DisplaySourceMetadata]
    ) throws -> CaptureSource {
        guard !displays.isEmpty else {
            throw OpenRecError.captureSourceUnavailable(.display(DisplayID(rawValue: 0)))
        }

        guard displays.count == 1 else {
            throw OpenRecError.captureConfigurationInvalid("Multiple displays require explicit selection.")
        }

        let display = displays[0]
        guard display.isAvailable else {
            throw OpenRecError.captureSourceUnavailable(.display(display.id))
        }

        return .display(display.id)
    }
}
