import Foundation
import Testing
@testable import OpenRecCore

@Test func captureSourceMetadataStoresDisplayOriginalPixelSizeAndAvailability() {
    let source = CaptureSource.display(DisplayID(rawValue: 123))
    let metadata = CaptureSourceMetadata(
        source: source,
        pixelSize: CGSize(width: 3024, height: 1964),
        isAvailable: true
    )

    #expect(metadata.source == source)
    #expect(metadata.pixelSize.width == 3024)
    #expect(metadata.pixelSize.height == 1964)
    #expect(metadata.isAvailable)
}

@Test func captureSourceMetadataStoresWindowOriginalPixelSizeAndAvailability() {
    let source = CaptureSource.window(WindowID(rawValue: 456))
    let metadata = CaptureSourceMetadata(
        source: source,
        pixelSize: CGSize(width: 1440, height: 900),
        isAvailable: false
    )

    #expect(metadata.source == source)
    #expect(metadata.pixelSize.width == 1440)
    #expect(metadata.pixelSize.height == 900)
    #expect(!metadata.isAvailable)
}
