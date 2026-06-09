import Foundation
import ScreenCaptureKit

@available(macOS 14.0, *)
public struct ScreenCaptureKitCaptureSourceProvider: CaptureSourceProvider {
    public init() {}

    public func displays() async throws -> [DisplaySourceMetadata] {
        let content = try await shareableContent()

        return content.displays.map { display in
            let pixelSize = Self.pixelSize(
                for: SCContentFilter(display: display, excludingWindows: [])
            )

            return DisplaySourceMetadata(
                id: DisplayID(rawValue: display.displayID),
                name: "Display \(display.displayID)",
                pixelSize: pixelSize,
                isAvailable: true
            )
        }
    }

    public func windows() async throws -> [WindowSourceMetadata] {
        let content = try await shareableContent()

        return content.windows.map { window in
            let pixelSize = Self.pixelSize(
                for: SCContentFilter(desktopIndependentWindow: window)
            )

            return WindowSourceMetadata(
                id: WindowID(rawValue: window.windowID),
                title: window.title ?? "",
                owningApplicationName: window.owningApplication?.applicationName,
                pixelSize: pixelSize,
                screenFrame: window.frame,
                isAvailable: true
            )
        }
    }

    private func shareableContent() async throws -> SCShareableContent {
        try await SCShareableContent.excludingDesktopWindows(
            true,
            onScreenWindowsOnly: true
        )
    }

    private static func pixelSize(for filter: SCContentFilter) -> CGSize {
        let contentRect = filter.contentRect
        let pointPixelScale = CGFloat(filter.pointPixelScale)

        return CGSize(
            width: (contentRect.width * pointPixelScale).rounded(),
            height: (contentRect.height * pointPixelScale).rounded()
        )
    }
}
