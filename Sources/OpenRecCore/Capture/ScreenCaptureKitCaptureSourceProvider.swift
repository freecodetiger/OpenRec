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
                // isOnScreen keeps every app's never-shown helper windows out of the
                // picker. They report plausible frames that overlap real windows, so
                // they would otherwise win the hover test on z-order alone.
                isAvailable: window.isOnScreen
            )
        }
    }

    private func shareableContent() async throws -> SCShareableContent {
        // onScreenWindowsOnly must stay false: it limits results to the current
        // Space, which hides fullscreen apps (each owns its own Space) as well as
        // anything hidden by the act of opening the menu bar. Listing every window
        // and filtering in isRecordableWindow is what keeps the picker complete.
        try await SCShareableContent.excludingDesktopWindows(
            true,
            onScreenWindowsOnly: false
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
