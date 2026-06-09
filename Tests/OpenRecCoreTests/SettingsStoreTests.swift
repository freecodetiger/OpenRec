import Foundation
import Testing
@testable import OpenRecCore

@Suite(.serialized)
struct SettingsStoreTests {
    @Test func loadCreatesDefaultSettingsFileWhenMissing() throws {
        let directory = try temporaryDirectory()
        let store = SettingsStore(settingsDirectory: directory)

        let settings = try store.load()

        #expect(settings == .defaults)
        let data = try Data(contentsOf: directory.appending(path: "settings.json"))
        let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(payload?["schemaVersion"] as? Int == 1)
        #expect(payload?["recording"] != nil)
    }

    @Test func savePersistsSettingsThatCanBeLoadedAgain() throws {
        let directory = try temporaryDirectory()
        let store = SettingsStore(settingsDirectory: directory)
        var settings = AppSettings.defaults
        settings.appLanguage = .simplifiedChinese
        settings.recording.outputFormat = .mov
        settings.recording.videoCodec = .hevc
        settings.recording.frameRate = .fps60
        settings.recording.includeCursor = false
        settings.recording.microphoneDeviceID = "BuiltInMic"

        try store.save(settings)

        let reloaded = try SettingsStore(settingsDirectory: directory).load()
        #expect(reloaded == settings)
    }

    @Test func loadDefaultsLanguageWhenExistingSettingsOmitLanguage() throws {
        let directory = try temporaryDirectory()
        let settingsFile = directory.appending(path: "settings.json")
        let legacyJSON = """
        {
          "schemaVersion" : 1,
          "recording" : {
            "audioPreset" : "standard",
            "defaultMode" : "display",
            "frameRate" : 30,
            "globalHotkey" : null,
            "includeCursor" : true,
            "microphoneDeviceID" : null,
            "outputFormat" : "mp4",
            "qualityPreset" : "standard",
            "videoCodec" : "h264"
          }
        }
        """
        try Data(legacyJSON.utf8).write(to: settingsFile)

        let reloaded = try SettingsStore(settingsDirectory: directory).load()

        #expect(reloaded.appLanguage == .english)
    }

    @Test func defaultStorePathUsesInjectedApplicationSupportDirectory() {
        let applicationSupportDirectory = URL(filePath: "/tmp/openrec-settings-test-support")

        let store = SettingsStore(applicationSupportDirectory: applicationSupportDirectory)

        #expect(store.settingsFileURL == applicationSupportDirectory.appending(path: "OpenRec/settings.json"))
    }

    @Test func loadMovesInvalidJSONAsideAndRecreatesDefaults() throws {
        let directory = try temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let settingsFile = directory.appending(path: "settings.json")
        try Data("{ invalid json".utf8).write(to: settingsFile)
        let store = SettingsStore(settingsDirectory: directory)

        let settings = try store.load()

        #expect(settings == .defaults)
        #expect(FileManager.default.fileExists(atPath: settingsFile.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "settings.invalid.json").path(percentEncoded: false)))

        let recreated = try store.load()
        #expect(recreated == .defaults)
        #expect(FileManager.default.fileExists(atPath: settingsFile.path(percentEncoded: false)))
    }

    @Test func persistedJSONDoesNotContainRecordingHistoryOrFilePaths() throws {
        let directory = try temporaryDirectory()
        let store = SettingsStore(settingsDirectory: directory)

        try store.save(.defaults)

        let json = try String(contentsOf: directory.appending(path: "settings.json"), encoding: .utf8)
        #expect(!json.contains("recordingHistory"))
        #expect(!json.contains("recordingPath"))
        #expect(!json.contains("recordingFile"))
        #expect(!json.contains("filePath"))
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "OpenRecSettingsStoreTests")
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
