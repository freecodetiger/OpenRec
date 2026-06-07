import Foundation

public struct CaptureSourceMetadata: Equatable, Sendable {
    public var source: CaptureSource
    public var pixelSize: CGSize
    public var isAvailable: Bool

    public init(
        source: CaptureSource,
        pixelSize: CGSize,
        isAvailable: Bool
    ) {
        self.source = source
        self.pixelSize = pixelSize
        self.isAvailable = isAvailable
    }

    public static func == (
        lhs: CaptureSourceMetadata,
        rhs: CaptureSourceMetadata
    ) -> Bool {
        lhs.source == rhs.source &&
            lhs.pixelSize.width == rhs.pixelSize.width &&
            lhs.pixelSize.height == rhs.pixelSize.height &&
            lhs.isAvailable == rhs.isAvailable
    }
}
