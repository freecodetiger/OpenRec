public enum CaptureSource: Codable, Equatable, Sendable {
    case display(DisplayID)
    case window(WindowID)

    public var displayID: DisplayID? {
        guard case let .display(id) = self else { return nil }
        return id
    }

    public var windowID: WindowID? {
        guard case let .window(id) = self else { return nil }
        return id
    }
}

public enum CaptureMode: String, Codable, Equatable, Sendable, CaseIterable {
    case display
    case window
}

