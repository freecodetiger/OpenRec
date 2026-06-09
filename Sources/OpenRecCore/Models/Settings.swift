public struct AppSettings: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var appLanguage: AppLanguage
    public var recording: RecordingSettings

    public init(schemaVersion: Int, appLanguage: AppLanguage = .english, recording: RecordingSettings) {
        self.schemaVersion = schemaVersion
        self.appLanguage = appLanguage
        self.recording = recording
    }

    public static let defaults = AppSettings(
        schemaVersion: 1,
        appLanguage: .english,
        recording: .defaults
    )

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case appLanguage
        case recording
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        appLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .appLanguage) ?? .english
        recording = try container.decode(RecordingSettings.self, forKey: .recording)
    }
}

public enum AppLanguage: String, Codable, Equatable, Sendable, CaseIterable {
    case english
    case simplifiedChinese
}

public struct RecordingSettings: Codable, Equatable, Sendable {
    public var defaultMode: CaptureMode
    public var outputFormat: OutputFormat
    public var videoCodec: VideoCodec
    public var qualityPreset: QualityPreset
    public var frameRate: FrameRatePreset
    public var includeCursor: Bool
    public var microphoneDeviceID: String?
    public var audioPreset: AudioPreset
    public var globalHotkey: Hotkey?

    public init(
        defaultMode: CaptureMode,
        outputFormat: OutputFormat,
        videoCodec: VideoCodec,
        qualityPreset: QualityPreset,
        frameRate: FrameRatePreset,
        includeCursor: Bool,
        microphoneDeviceID: String?,
        audioPreset: AudioPreset,
        globalHotkey: Hotkey?
    ) {
        self.defaultMode = defaultMode
        self.outputFormat = outputFormat
        self.videoCodec = videoCodec
        self.qualityPreset = qualityPreset
        self.frameRate = frameRate
        self.includeCursor = includeCursor
        self.microphoneDeviceID = microphoneDeviceID
        self.audioPreset = audioPreset
        self.globalHotkey = globalHotkey
    }

    public static let defaults = RecordingSettings(
        defaultMode: .display,
        outputFormat: .mp4,
        videoCodec: .h264,
        qualityPreset: .standard,
        frameRate: .fps30,
        includeCursor: true,
        microphoneDeviceID: nil,
        audioPreset: .standard,
        globalHotkey: nil
    )
}

public enum OutputFormat: String, Codable, Equatable, Sendable, CaseIterable {
    case mp4
    case mov
}

public enum VideoCodec: String, Codable, Equatable, Sendable, CaseIterable {
    case h264
    case hevc
}

public enum QualityPreset: String, Codable, Equatable, Sendable, CaseIterable {
    case compact
    case standard
    case high
}

public enum FrameRatePreset: Int, Codable, Equatable, Sendable, CaseIterable {
    case fps25 = 25
    case fps30 = 30
    case fps60 = 60
}

public enum AudioPreset: String, Codable, Equatable, Sendable, CaseIterable {
    case standard
    case high
}
