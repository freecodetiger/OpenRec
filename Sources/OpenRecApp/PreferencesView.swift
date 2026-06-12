import AppKit
import SwiftUI
import OpenRecCore

struct PreferencesView: View {
    var snapshot: AppShellSnapshot
    var onSettingsChange: (RecordingSettings) -> Void = { _ in }
    var onLanguageChange: (AppLanguage) -> Void = { _ in }
    var onOpenPermissionSettings: (PermissionKind) -> Void = { _ in }
    var onRequestPermission: (PermissionKind) -> Void = { _ in }
    var onRefreshPermissions: () -> Void = {}
    var onRefreshAudioLevel: () -> Void = {}

    @State private var draftSettings: RecordingSettings
    @State private var selectedSection: PreferenceSection = .general
    @State private var isRecordingShortcut = false
    @State private var shortcutCaptureMessage: String?
    private let audioLevelTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

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
        onRefreshPermissions: @escaping () -> Void = {},
        onRefreshAudioLevel: @escaping () -> Void = {}
    ) {
        self.snapshot = snapshot
        self.onSettingsChange = onSettingsChange
        self.onLanguageChange = onLanguageChange
        self.onOpenPermissionSettings = onOpenPermissionSettings
        self.onRequestPermission = onRequestPermission
        self.onRefreshPermissions = onRefreshPermissions
        self.onRefreshAudioLevel = onRefreshAudioLevel
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
        .onReceive(audioLevelTimer) { _ in
            guard snapshot.status == .recording else { return }
            onRefreshAudioLevel()
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
                MicrophoneLevelIndicator(
                    presentation: MicrophoneLevelPresentation.make(
                        snapshot: snapshot,
                        strings: strings
                    )
                )
                .padding(.horizontal, 2)
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
                let shortcutPresentation = ShortcutPreferencePresentation.make(
                    hotkey: draftSettings.globalHotkey,
                    strings: strings
                )
                preferenceRow(title: strings.globalShortcut, detail: shortcutPresentation.detailText) {
                    HStack(spacing: 8) {
                        Button(shortcutPresentation.primaryActionTitle) {
                            isRecordingShortcut = true
                            shortcutCaptureMessage = nil
                        }
                        .disabled(!shortcutPresentation.isPrimaryActionEnabled)
                        if shortcutPresentation.showsClearAction {
                            Button(strings.clearShortcut) {
                                updateGlobalHotkey(nil)
                            }
                        }
                    }
                }
                if isRecordingShortcut {
                    Divider()
                    shortcutCapturePanel
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

    private var shortcutCapturePanel: some View {
        HStack(spacing: 12) {
            Image(systemName: "keyboard")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(strings.pressShortcut)
                    .font(.body.weight(.medium))
                Text(shortcutCaptureMessage ?? strings.shortcutCaptureHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(strings.cancel) {
                isRecordingShortcut = false
                shortcutCaptureMessage = nil
            }
            .keyboardShortcut(.cancelAction)
            HotkeyCaptureView(
                onCapture: { hotkey in
                    guard hotkey.modifiers.rawValue != 0 else {
                        shortcutCaptureMessage = strings.shortcutRequiresModifier
                        return
                    }
                    updateGlobalHotkey(hotkey)
                },
                onCancel: {
                    isRecordingShortcut = false
                    shortcutCaptureMessage = nil
                }
            )
            .frame(width: 1, height: 1)
            .opacity(0.01)
        }
        .padding(.vertical, 4)
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

    private func updateGlobalHotkey(_ hotkey: Hotkey?) {
        isRecordingShortcut = false
        shortcutCaptureMessage = nil
        updateSettings { settings in
            settings.globalHotkey = hotkey
        }
    }
}

private struct HotkeyCaptureView: NSViewRepresentable {
    var onCapture: (Hotkey) -> Void
    var onCancel: () -> Void

    func makeNSView(context: Context) -> HotkeyCaptureNSView {
        HotkeyCaptureNSView(onCapture: onCapture, onCancel: onCancel)
    }

    func updateNSView(_ nsView: HotkeyCaptureNSView, context: Context) {
        nsView.onCapture = onCapture
        nsView.onCancel = onCancel
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class HotkeyCaptureNSView: NSView {
    var onCapture: (Hotkey) -> Void
    var onCancel: () -> Void

    init(onCapture: @escaping (Hotkey) -> Void, onCancel: @escaping () -> Void) {
        self.onCapture = onCapture
        self.onCancel = onCancel
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel()
            return
        }

        onCapture(Hotkey(
            keyCode: event.keyCode,
            modifiers: HotkeyModifiers(event.modifierFlags)
        ))
    }
}

private extension HotkeyModifiers {
    init(_ modifierFlags: NSEvent.ModifierFlags) {
        var modifiers: HotkeyModifiers = []
        if modifierFlags.contains(.command) {
            modifiers.insert(.command)
        }
        if modifierFlags.contains(.option) {
            modifiers.insert(.option)
        }
        if modifierFlags.contains(.control) {
            modifiers.insert(.control)
        }
        if modifierFlags.contains(.shift) {
            modifiers.insert(.shift)
        }
        self = modifiers
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
