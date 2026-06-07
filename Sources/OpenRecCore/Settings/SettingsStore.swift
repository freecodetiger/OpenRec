import Foundation

public struct SettingsStore: Sendable {
    public let settingsDirectory: URL
    public let settingsFileURL: URL

    private let invalidSettingsFileName = "settings.invalid.json"

    public init(settingsDirectory: URL) {
        self.settingsDirectory = settingsDirectory
        self.settingsFileURL = settingsDirectory.appending(path: "settings.json")
    }

    public init(applicationSupportDirectory: URL) {
        self.init(settingsDirectory: applicationSupportDirectory.appending(path: "OpenRec"))
    }

    public init() throws {
        let applicationSupportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        self.init(applicationSupportDirectory: applicationSupportDirectory)
    }

    public func load() throws -> AppSettings {
        guard FileManager.default.fileExists(atPath: settingsFileURL.path(percentEncoded: false)) else {
            let defaults = AppSettings.defaults
            try save(defaults)
            return defaults
        }

        do {
            let data = try Data(contentsOf: settingsFileURL)
            return try decoder.decode(AppSettings.self, from: data)
        } catch {
            try moveInvalidSettingsAside()
            let defaults = AppSettings.defaults
            try save(defaults)
            return defaults
        }
    }

    public func save(_ settings: AppSettings) throws {
        try FileManager.default.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)

        let data = try encoder.encode(settings)
        let temporaryURL = settingsDirectory.appending(path: ".settings.\(UUID().uuidString).tmp")
        try data.write(to: temporaryURL, options: [.atomic])

        if FileManager.default.fileExists(atPath: settingsFileURL.path(percentEncoded: false)) {
            _ = try FileManager.default.replaceItemAt(settingsFileURL, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: settingsFileURL)
        }
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private var decoder: JSONDecoder {
        JSONDecoder()
    }

    private func moveInvalidSettingsAside() throws {
        let invalidURL = settingsDirectory.appending(path: invalidSettingsFileName)
        if FileManager.default.fileExists(atPath: invalidURL.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: invalidURL)
        }
        try FileManager.default.moveItem(at: settingsFileURL, to: invalidURL)
    }
}
