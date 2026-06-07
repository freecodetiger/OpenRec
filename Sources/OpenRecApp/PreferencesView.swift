import SwiftUI
import OpenRecCore

struct PreferencesView: View {
    var snapshot: AppShellSnapshot

    var body: some View {
        TabView {
            Form {
                Picker("Default mode", selection: .constant(snapshot.settings.defaultMode)) {
                    Text("Display Recording").tag(CaptureMode.display)
                    Text("Window Recording").tag(CaptureMode.window)
                }
                Toggle("Show system cursor", isOn: .constant(snapshot.settings.includeCursor))
            }
            .padding(20)
            .tabItem { Label("Recording", systemImage: "record.circle") }

            Form {
                Picker("Format", selection: .constant(snapshot.settings.outputFormat)) {
                    ForEach(OutputFormat.allCases, id: \.self) { format in
                        Text(format.label).tag(format)
                    }
                }
                Picker("Codec", selection: .constant(snapshot.settings.videoCodec)) {
                    ForEach(VideoCodec.allCases, id: \.self) { codec in
                        Text(codec.label).tag(codec)
                    }
                }
                Picker("Frame rate", selection: .constant(snapshot.settings.frameRate)) {
                    ForEach(FrameRatePreset.allCases, id: \.self) { frameRate in
                        Text(frameRate.label).tag(frameRate)
                    }
                }
                Picker("Quality", selection: .constant(snapshot.settings.qualityPreset)) {
                    ForEach(QualityPreset.allCases, id: \.self) { quality in
                        Text(quality.label).tag(quality)
                    }
                }
            }
            .padding(20)
            .tabItem { Label("Video", systemImage: "film") }

            Form {
                Picker("Microphone", selection: .constant(snapshot.selectedMicrophoneID)) {
                    ForEach(snapshot.microphones) { microphone in
                        Text(microphone.title).tag(microphone.id)
                    }
                }
                Picker("Audio quality", selection: .constant(snapshot.settings.audioPreset)) {
                    ForEach(AudioPreset.allCases, id: \.self) { preset in
                        Text(preset.label).tag(preset)
                    }
                }
            }
            .padding(20)
            .tabItem { Label("Audio", systemImage: "mic") }

            Form {
                LabeledContent("Global shortcut", value: "Not configured")
                Button("Record Shortcut") {}
                    .disabled(true)
            }
            .padding(20)
            .tabItem { Label("Shortcuts", systemImage: "keyboard") }

            PermissionPlaceholderView(snapshot: snapshot)
                .padding(20)
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
    }
}
