import Foundation
import Testing
@testable import OpenRecCore

@Test func inMemoryCaptureSourceProviderReturnsDisplaysAndWindows() async throws {
    let displays = [
        DisplaySourceMetadata(
            id: DisplayID(rawValue: 1),
            name: "Built-in Display",
            pixelSize: CGSize(width: 3024, height: 1964),
            isAvailable: true
        )
    ]
    let windows = [
        WindowSourceMetadata(
            id: WindowID(rawValue: 10),
            title: "Document",
            owningApplicationName: "Editor",
            pixelSize: CGSize(width: 1440, height: 900),
            screenFrame: CGRect(x: 40, y: 80, width: 720, height: 450),
            isAvailable: true
        )
    ]
    let provider: any CaptureSourceProvider = InMemoryCaptureSourceProvider(displays: displays, windows: windows)

    #expect(try await provider.displays() == displays)
    #expect(try await provider.windows() == windows)
}

@Test func singleDisplayCanBeSelectedByDefault() throws {
    let display = DisplaySourceMetadata(
        id: DisplayID(rawValue: 7),
        name: "Studio Display",
        pixelSize: CGSize(width: 5120, height: 2880),
        isAvailable: true
    )

    let selection = try CaptureSourceSelection.defaultDisplaySource(from: [display])

    #expect(selection == .display(display.id))
}

@Test func multipleDisplaysRequireExplicitSelection() {
    let displays = [
        DisplaySourceMetadata(
            id: DisplayID(rawValue: 1),
            name: "Built-in Display",
            pixelSize: CGSize(width: 3024, height: 1964),
            isAvailable: true
        ),
        DisplaySourceMetadata(
            id: DisplayID(rawValue: 2),
            name: "External Display",
            pixelSize: CGSize(width: 3840, height: 2160),
            isAvailable: true
        )
    ]

    #expect(throws: OpenRecError.captureConfigurationInvalid("Multiple displays require explicit selection.")) {
        try CaptureSourceSelection.defaultDisplaySource(from: displays)
    }
}

@Test func multipleDisplaysRequireExplicitSelectionEvenWhenOnlyOneIsAvailable() {
    let displays = [
        DisplaySourceMetadata(
            id: DisplayID(rawValue: 1),
            name: "Built-in Display",
            pixelSize: CGSize(width: 3024, height: 1964),
            isAvailable: true
        ),
        DisplaySourceMetadata(
            id: DisplayID(rawValue: 2),
            name: "Disconnected Display",
            pixelSize: CGSize(width: 3840, height: 2160),
            isAvailable: false
        )
    ]

    #expect(throws: OpenRecError.captureConfigurationInvalid("Multiple displays require explicit selection.")) {
        try CaptureSourceSelection.defaultDisplaySource(from: displays)
    }
}

@Test func noDisplaysCannotBeSelectedByDefault() {
    #expect(throws: OpenRecError.captureSourceUnavailable(.display(DisplayID(rawValue: 0)))) {
        try CaptureSourceSelection.defaultDisplaySource(from: [])
    }
}

@Test func unavailableSingleDisplayCannotBeSelectedByDefault() {
    let display = DisplaySourceMetadata(
        id: DisplayID(rawValue: 42),
        name: "Unavailable Display",
        pixelSize: CGSize(width: 1920, height: 1080),
        isAvailable: false
    )

    #expect(throws: OpenRecError.captureSourceUnavailable(.display(display.id))) {
        try CaptureSourceSelection.defaultDisplaySource(from: [display])
    }
}

@Test func windowMetadataCanRepresentUnavailableWindowWithOriginalPixelSize() {
    let window = WindowSourceMetadata(
        id: WindowID(rawValue: 99),
        title: "Build Log",
        owningApplicationName: "Terminal",
        pixelSize: CGSize(width: 1280, height: 720),
        isAvailable: false
    )

    #expect(window.source == .window(WindowID(rawValue: 99)))
    #expect(window.pixelSize.width == 1280)
    #expect(window.pixelSize.height == 720)
    #expect(window.screenFrame == nil)
    #expect(!window.isAvailable)
}

@Test func windowMetadataCanStoreScreenFrameForOverlaySelection() {
    let screenFrame = CGRect(x: 120, y: 240, width: 960, height: 540)
    let window = WindowSourceMetadata(
        id: WindowID(rawValue: 7),
        title: "Canvas",
        owningApplicationName: "Design",
        pixelSize: CGSize(width: 1920, height: 1080),
        screenFrame: screenFrame,
        isAvailable: true
    )

    #expect(window.screenFrame == screenFrame)
}
