import SwiftUI
import OpenRecCore

struct PreferencesView: View {
    var snapshot: AppShellSnapshot
    var onSettingsChange: (RecordingSettings) -> Void = { _ in }
    var onOpenPermissionSettings: (PermissionKind) -> Void = { _ in }
    var onRefreshPermissions: () -> Void = {}
    @State private var draftSettings: RecordingSettings

    init(
        snapshot: AppShellSnapshot,
        onSettingsChange: @escaping (RecordingSettings) -> Void = { _ in },
        onOpenPermissionSettings: @escaping (PermissionKind) -> Void = { _ in },
        onRefreshPermissions: @escaping () -> Void = {}
    ) {
        self.snapshot = snapshot
        self.onSettingsChange = onSettingsChange
        self.onOpenPermissionSettings = onOpenPermissionSettings
        self.onRefreshPermissions = onRefreshPermissions
        _draftSettings = State(initialValue: snapshot.settings)
    }

    var body: some View {
        TabView {
            Form {
                settingsError

                Picker("Default mode", selection: settingBinding(\.defaultMode)) {
                    Text("Display Recording").tag(CaptureMode.display)
                    Text("Window Recording").tag(CaptureMode.window)
                }
                Toggle("Show system cursor", isOn: settingBinding(\.includeCursor))
            }
            .padding(20)
            .tabItem { Label("Recording", systemImage: "record.circle") }

            Form {
                settingsError

                Picker("Format", selection: settingBinding(\.outputFormat)) {
                    ForEach(OutputFormat.allCases, id: \.self) { format in
                        Text(format.label).tag(format)
                    }
                }
                Picker("Codec", selection: settingBinding(\.videoCodec)) {
                    ForEach(VideoCodec.allCases, id: \.self) { codec in
                        Text(codec.label).tag(codec)
                    }
                }
                Picker("Frame rate", selection: settingBinding(\.frameRate)) {
                    ForEach(FrameRatePreset.allCases, id: \.self) { frameRate in
                        Text(frameRate.label).tag(frameRate)
                    }
                }
                Picker("Quality", selection: settingBinding(\.qualityPreset)) {
                    ForEach(QualityPreset.allCases, id: \.self) { quality in
                        Text(quality.label).tag(quality)
                    }
                }
            }
            .padding(20)
            .tabItem { Label("Video", systemImage: "film") }

            Form {
                settingsError

                Picker("Microphone", selection: microphoneBinding) {
                    ForEach(snapshot.microphones) { microphone in
                        Text(microphone.title).tag(microphone.id)
                    }
                }
                Picker("Audio quality", selection: settingBinding(\.audioPreset)) {
                    ForEach(AudioPreset.allCases, id: \.self) { preset in
                        Text(preset.label).tag(preset)
                    }
                }
            }
            .padding(20)
            .tabItem { Label("Audio", systemImage: "mic") }

            Form {
                LabeledContent("Global shortcut", value: snapshot.settings.globalHotkey.label)
                Button("Record Shortcut") {}
                    .disabled(true)
            }
            .padding(20)
            .tabItem { Label("Shortcuts", systemImage: "keyboard") }

            Form {
                PermissionPlaceholderView(
                    snapshot: snapshot,
                    onOpenPermissionSettings: onOpenPermissionSettings
                )
                Button("Re-check Permissions", action: onRefreshPermissions)
            }
                .padding(20)
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .onChange(of: snapshot) { _, snapshot in
            draftSettings = snapshot.settings
        }
    }

    @ViewBuilder
    private var settingsError: some View {
        if let errorMessage = snapshot.errorMessage {
            Text(errorMessage)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var microphoneBinding: Binding<String> {
        Binding(
            get: { draftSelectedMicrophoneID },
            set: { selectedID in
                guard let microphone = snapshot.microphones.first(where: { $0.id == selectedID }) else {
                    return
                }
                updateSettings { settings in
                    settings.microphoneDeviceID = microphone.deviceID
                }
            }
        )
    }

    private var draftSelectedMicrophoneID: String {
        snapshot.microphones.first { $0.deviceID == draftSettings.microphoneDeviceID }?.id ??
            snapshot.selectedMicrophoneID
    }

    private func settingBinding<Value: Equatable>(
        _ keyPath: WritableKeyPath<RecordingSettings, Value>
    ) -> Binding<Value> {
        Binding(
            get: { draftSettings[keyPath: keyPath] },
            set: { value in
                updateSettings { settings in
                    settings[keyPath: keyPath] = value
                }
            }
        )
    }

    private func updateSettings(_ update: (inout RecordingSettings) -> Void) {
        var settings = draftSettings
        update(&settings)
        guard settings != draftSettings else { return }
        draftSettings = settings
        onSettingsChange(settings)
    }
}

private extension Optional where Wrapped == Hotkey {
    var label: String {
        self == nil ? "Not configured" : "Configured"
    }
}
