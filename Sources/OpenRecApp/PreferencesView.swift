import SwiftUI
import OpenRecCore

struct PreferencesView: View {
    var snapshot: AppShellSnapshot
    var onSettingsChange: (RecordingSettings) -> Void = { _ in }
    var onLanguageChange: (AppLanguage) -> Void = { _ in }
    var onOpenPermissionSettings: (PermissionKind) -> Void = { _ in }
    var onRequestPermission: (PermissionKind) -> Void = { _ in }
    var onRefreshPermissions: () -> Void = {}

    @State private var draftSettings: RecordingSettings
    @State private var selectedSection: PreferenceSection = .general

    private var strings: OpenRecLocalization {
        OpenRecLocalization(snapshot.appLanguage)
    }
    private var parameterSummary: RecordingParameterSummary {
        RecordingParameterSummary.make(
            target: snapshot.selectedTarget,
            settings: draftSettings,
            strings: strings
        )
    }

    init(
        snapshot: AppShellSnapshot,
        onSettingsChange: @escaping (RecordingSettings) -> Void = { _ in },
        onLanguageChange: @escaping (AppLanguage) -> Void = { _ in },
        onOpenPermissionSettings: @escaping (PermissionKind) -> Void = { _ in },
        onRequestPermission: @escaping (PermissionKind) -> Void = { _ in },
        onRefreshPermissions: @escaping () -> Void = {}
    ) {
        self.snapshot = snapshot
        self.onSettingsChange = onSettingsChange
        self.onLanguageChange = onLanguageChange
        self.onOpenPermissionSettings = onOpenPermissionSettings
        self.onRequestPermission = onRequestPermission
        self.onRefreshPermissions = onRefreshPermissions
        _draftSettings = State(initialValue: snapshot.settings)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    settingsError
                    sectionContent
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(minWidth: 720, minHeight: 520)
        .onChange(of: snapshot) { _, snapshot in
            draftSettings = snapshot.settings
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(strings.preferencesTitle)
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .padding(.bottom, 6)

            ForEach(PreferenceSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    Label(section.title(strings), systemImage: section.symbolName)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedSection == section ? Color.accentColor.opacity(0.12) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(width: 188)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(selectedSection.title(strings), systemImage: selectedSection.symbolName)
                .font(.title2.weight(.semibold))
            Text(selectedSection.detail(strings))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .general:
            settingsGroup {
                preferenceRow(title: strings.appLanguageTitle, detail: strings.appLanguageDetail) {
                    Picker(strings.appLanguageTitle, selection: languageBinding) {
                        ForEach(AppLanguage.allCases, id: \.self) { language in
                            Text(strings.languageLabel(language)).tag(language)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
                Divider()
                Toggle(strings.showSystemCursor, isOn: settingBinding(\.includeCursor))
            }
        case .recording:
            settingsGroup {
                preferenceRow(title: strings.format) {
                    Picker(strings.format, selection: settingBinding(\.outputFormat)) {
                        ForEach(OutputFormat.allCases, id: \.self) { format in
                            Text(format.label).tag(format)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }
                Divider()
                preferenceRow(title: strings.codec) {
                    Picker(strings.codec, selection: settingBinding(\.videoCodec)) {
                        ForEach(VideoCodec.allCases, id: \.self) { codec in
                            Text(codec.label).tag(codec)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }
                Divider()
                preferenceRow(title: strings.frameRate) {
                    Picker(strings.frameRate, selection: settingBinding(\.frameRate)) {
                        ForEach(FrameRatePreset.allCases, id: \.self) { frameRate in
                            Text(frameRate.label).tag(frameRate)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }
                Divider()
                preferenceRow(title: strings.quality, detail: strings.videoBitrateDetail) {
                    Picker(strings.quality, selection: settingBinding(\.qualityPreset)) {
                        ForEach(QualityPreset.allCases, id: \.self) { quality in
                            Text(strings.qualityLabel(quality)).tag(quality)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }
                bitrateSummaryRows
            }
        case .audio:
            settingsGroup {
                preferenceRow(title: strings.microphone) {
                    Picker(strings.microphone, selection: microphoneBinding) {
                        ForEach(snapshot.microphones) { microphone in
                            Text(microphone.title).tag(microphone.id)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                }
                Divider()
                preferenceRow(title: strings.audioQuality, detail: strings.audioEncodingDetail) {
                    Picker(strings.audioQuality, selection: settingBinding(\.audioPreset)) {
                        ForEach(AudioPreset.allCases, id: \.self) { preset in
                            Text(strings.audioPresetLabel(preset)).tag(preset)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }
                audioSummaryRows
            }
        case .shortcuts:
            settingsGroup {
                preferenceRow(title: strings.globalShortcut, detail: snapshot.settings.globalHotkey.localizedLabel(strings)) {
                    Button(strings.recordShortcut) {}
                        .disabled(true)
                }
            }
        case .permissions:
            settingsGroup {
                PermissionPlaceholderView(
                    snapshot: snapshot,
                    strings: strings,
                    onOpenPermissionSettings: onOpenPermissionSettings,
                    onRequestPermission: onRequestPermission
                )
                Divider()
                Button(strings.recheckPermissions, action: onRefreshPermissions)
            }
        }
    }

    @ViewBuilder
    private var settingsError: some View {
        if let errorMessage = snapshot.errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func preferenceRow<Content: View>(
        title: String,
        detail: String? = nil,
        @ViewBuilder control: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 20)
            control()
        }
    }

    private var bitrateSummaryRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            LabeledContent(strings.quality) {
                Text(parameterSummary.bitrateText)
                    .monospacedDigit()
            }
            LabeledContent(strings.videoTitle) {
                Text(parameterSummary.videoDetailText)
            }
            LabeledContent(strings.audioTitle) {
                Text(parameterSummary.audioDetailText)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var audioSummaryRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            LabeledContent(strings.audioQuality) {
                Text(parameterSummary.audioDetailText)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { snapshot.appLanguage },
            set: { onLanguageChange($0) }
        )
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

private enum PreferenceSection: String, CaseIterable, Identifiable {
    case general
    case recording
    case audio
    case shortcuts
    case permissions

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .general:
            "gearshape"
        case .recording:
            "film"
        case .audio:
            "mic"
        case .shortcuts:
            "keyboard"
        case .permissions:
            "lock.shield"
        }
    }

    func title(_ strings: OpenRecLocalization) -> String {
        switch self {
        case .general:
            strings.generalTitle
        case .recording:
            strings.recordingTitle
        case .audio:
            strings.audioTitle
        case .shortcuts:
            strings.shortcutsTitle
        case .permissions:
            strings.permissionsTitle
        }
    }

    func detail(_ strings: OpenRecLocalization) -> String {
        switch self {
        case .general:
            return strings.text("Application-wide behavior and language.", "应用全局行为与语言。")
        case .recording:
            return strings.text("Video container, codec, frame rate, and bitrate preset.", "视频封装、编码、帧率与码率预设。")
        case .audio:
            return strings.text("Microphone input and AAC encoding parameters.", "麦克风输入与 AAC 编码参数。")
        case .shortcuts:
            return strings.text("Global keyboard shortcut status.", "全局键盘快捷键状态。")
        case .permissions:
            return strings.text("macOS permissions required by OpenRec.", "OpenRec 所需的 macOS 权限。")
        }
    }
}

private extension Optional where Wrapped == Hotkey {
    func localizedLabel(_ strings: OpenRecLocalization) -> String {
        self == nil ? strings.notConfigured : strings.configured
    }
}
