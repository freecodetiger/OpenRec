import Foundation
import OpenRecCore

struct OpenRecLocalization: Equatable {
    var language: AppLanguage

    init(_ language: AppLanguage) {
        self.language = language
    }

    func text(_ english: String, _ chinese: String) -> String {
        language == .simplifiedChinese ? chinese : english
    }

    var appLanguageTitle: String { text("Language", "语言") }
    var appLanguageDetail: String { text("Controls menus, windows, and recording controls.", "用于菜单、窗口和录制控制。") }
    var preferencesTitle: String { text("Preferences", "偏好设置") }
    var generalTitle: String { text("General", "通用") }
    var recordingTitle: String { text("Recording", "录制") }
    var videoTitle: String { text("Video", "视频") }
    var audioTitle: String { text("Audio", "音频") }
    var shortcutsTitle: String { text("Shortcuts", "快捷键") }
    var permissionsTitle: String { text("Permissions", "权限") }
    var sourceSelectionTitle: String { text("Source Selection", "选择来源") }
    var saveRecordingTitle: String { text("Save Recording", "保存录制") }
    var chooseApplicationTitle: String { text("Choose Application", "选择应用") }
    var showSystemCursor: String { text("Show system cursor", "显示系统指针") }
    var format: String { text("Format", "格式") }
    var codec: String { text("Codec", "编码") }
    var frameRate: String { text("Frame rate", "帧率") }
    var quality: String { text("Video bitrate", "视频码率") }
    var videoBitrateDetail: String { text("Estimated encoder target for the selected source and preset.", "基于当前录制来源和预设计算的视频编码目标码率。") }
    var microphone: String { text("Microphone", "麦克风") }
    var audioQuality: String { text("Audio encoding", "音频编码") }
    var audioEncodingDetail: String { text("AAC-LC target bitrate for microphone capture.", "麦克风音频的 AAC-LC 目标码率。") }
    var globalShortcut: String { text("Global shortcut", "全局快捷键") }
    var recordShortcut: String { text("Record Shortcut", "录制快捷键") }
    var recheckPermissions: String { text("Re-check Permissions", "重新检查权限") }
    var openSystemSettings: String { text("Open System Settings", "打开系统设置") }
    var openSettings: String { text("Open Settings", "打开设置") }
    var reopenOpenRec: String { text("Reopen OpenRec", "重新打开 OpenRec") }
    var cancel: String { text("Cancel", "取消") }
    var start: String { text("Start", "开始") }
    var quit: String { text("Quit", "退出") }
    var ok: String { text("OK", "好") }
    var recheck: String { text("Re-check", "重新检查") }
    var saveAgain: String { text("Save Recording", "保存录制") }
    var discardRecording: String { text("Discard Recording", "丢弃录制") }
    var saveAs: String { text("Save As...", "另存为...") }
    var retrySave: String { text("Retry Save", "重试保存") }
    var discard: String { text("Discard", "丢弃") }
    var windowRecording: String { text("Record Window", "录制窗口") }
    var applicationRecording: String { text("Record Application", "录制应用") }
    var recordAnotherSource: String { text("Other recording modes", "其他录制模式") }
    var startFullScreenRecording: String { text("Start Full Screen Recording", "开始全屏录制") }
    var stopRecording: String { text("Stop Recording", "停止录制") }
    var chooseSourceDetail: String { text("Choose the display or window OpenRec should record.", "选择 OpenRec 要录制的显示器或窗口。") }
    var displayRecording: String { text("Display Recording", "显示器录制") }
    var windowRecordingMode: String { text("Window Recording", "窗口录制") }
    var mode: String { text("Mode", "模式") }
    var selectWindowOnScreen: String { text("Select Window on Screen", "在屏幕上选择窗口") }
    var useSelectedSource: String { text("Use Selected Source", "使用所选来源") }
    var openRecPermissions: String { text("OpenRec Permissions", "OpenRec 权限") }
    var permissionsIntro: String { text("OpenRec records locally and needs macOS access before capture can start.", "OpenRec 在本地录制，开始前需要 macOS 授权。") }
    var saveRecordingDetail: String { text("Choose where to save the finished recording.", "选择录制完成后保存的位置。") }
    var status: String { text("Status", "状态") }
    var target: String { text("Target", "目标") }
    var temporaryFile: String { text("Temporary File", "临时文件") }
    var notConfigured: String { text("Not configured", "未配置") }
    var configured: String { text("Configured", "已配置") }
    var noRecordableWindowsTitle: String { text("No Recordable Windows", "没有可录制窗口") }
    var noRecordableWindowsDetail: String { text("Open a window and try Window Recording again.", "打开一个窗口后再尝试窗口录制。") }
    var noRecordableApplicationsTitle: String { text("No Recordable Applications", "没有可录制应用") }
    var noRecordableApplicationsDetail: String { text("Open an application window and try Application Recording again.", "打开一个应用窗口后再尝试应用录制。") }
    var noSourceSelected: String { text("No Source Selected", "未选择来源") }
    var chooseAvailableSource: String { text("Choose an available display or window.", "选择一个可用的显示器或窗口。") }
    var settingsLoadFailure: String { text("OpenRec could not load local settings.", "OpenRec 无法加载本地设置。") }
    var hotkeyRegistrationFailure: String { text("OpenRec could not register the global shortcut.", "OpenRec 无法注册全局快捷键。") }
    var recordingStateUpdateFailure: String { text("OpenRec could not update recording state.", "OpenRec 无法更新录制状态。") }
    var sourceUnavailable: String { text("The selected source is no longer available.", "所选来源不再可用。") }
    var microphoneUnavailable: String { text("No microphone input is available.", "没有可用的麦克风输入。") }
    var hotkeyConflict: String { text("That global shortcut is already in use.", "该全局快捷键已被占用。") }
    var chooseSaveLocationOrDiscard: String { text("Choose a save location or discard the recording.", "请选择保存位置或丢弃录制。") }
    var systemDefault: String { text("System Default", "系统默认") }
    var systemDefaultInputDevice: String { text("System default input device", "系统默认输入设备") }
    var inputDevice: String { text("Input device", "输入设备") }
    var usesCurrentMacOSInputDevice: String { text("Uses the current macOS input device", "使用当前 macOS 输入设备") }
    var untitledWindow: String { text("Untitled Window", "未命名窗口") }
    var originalResolution: String { text("original resolution", "原始分辨率") }

    func languageLabel(_ language: AppLanguage) -> String {
        switch language {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }

    func statusTitle(_ status: AppShellStatus) -> String {
        switch status {
        case .ready:
            return text("Ready", "就绪")
        case .recording:
            return text("Recording", "录制中")
        case .awaitingSave:
            return text("Awaiting Save", "等待保存")
        case .permissionRequired:
            return text("Permission Required", "需要权限")
        case .error:
            return text("Error", "错误")
        }
    }

    func statusDetail(_ status: AppShellStatus) -> String {
        switch status {
        case .ready:
            return text("Choose a source and start recording.", "选择来源并开始录制。")
        case .recording:
            return text("Capture is running with the selected settings.", "正在使用所选设置录制。")
        case .awaitingSave:
            return text("Save, retry, or discard the finished recording.", "保存、重试或丢弃已完成的录制。")
        case .permissionRequired:
            return text("OpenRec needs macOS permissions before recording.", "OpenRec 需要 macOS 权限后才能录制。")
        case .error:
            return text("Resolve the issue before starting again.", "解决问题后再重新开始。")
        }
    }

    func permissionTitle(_ kind: PermissionKind) -> String {
        switch kind {
        case .screenRecording:
            return text("Screen Recording", "屏幕录制")
        case .microphone:
            return text("Microphone", "麦克风")
        case .accessibility:
            return text("Accessibility", "辅助功能")
        case .inputMonitoring:
            return text("Input Monitoring", "输入监控")
        }
    }

    func permissionReason(_ kind: PermissionKind) -> String {
        switch kind {
        case .screenRecording:
            return text("Required for display and window capture.", "用于显示器和窗口录制。")
        case .microphone:
            return text("Required when microphone audio is enabled.", "启用麦克风音频时需要。")
        case .accessibility:
            return text("May be required for window selection and hotkeys.", "窗口选择和快捷键可能需要。")
        case .inputMonitoring:
            return text("May be required for global shortcut handling.", "全局快捷键可能需要。")
        }
    }

    func permissionStatus(_ status: PermissionStatus) -> String {
        switch status {
        case .granted:
            return text("Granted", "已授权")
        case .denied:
            return text("Denied", "已拒绝")
        case .notDetermined:
            return text("Not Determined", "未决定")
        case .unknown:
            return text("Unknown", "未知")
        }
    }

    func permissionStatusText(_ item: PermissionDisplayItem) -> String {
        "\(permissionTitle(item.kind)): \(permissionStatus(item.status))"
    }

    func qualityLabel(_ preset: QualityPreset) -> String {
        switch preset {
        case .compact:
            return text("Compact file", "小文件")
        case .standard:
            return text("Balanced", "均衡")
        case .high:
            return text("High detail", "高细节")
        }
    }

    func audioPresetLabel(_ preset: AudioPreset) -> String {
        switch preset {
        case .standard:
            return text("Standard", "标准")
        case .high:
            return text("High", "高")
        }
    }

    func applicationWindowCount(_ count: Int) -> String {
        if language == .simplifiedChinese {
            return "\(count) 个窗口"
        }
        return count == 1 ? "1 window" : "\(count) windows"
    }

    func videoBitrateValue(_ bitrate: Int) -> String {
        String(format: "%.1f Mbps", Double(bitrate) / 1_000_000)
    }

    func audioBitrateValue(_ bitrate: Int) -> String {
        String(format: "%.0f kbps", Double(bitrate) / 1_000)
    }

    func videoParameterDetail(
        resolution: String,
        frameRate: String,
        codec: String,
        format: String
    ) -> String {
        text(
            "\(resolution), \(frameRate), \(codec), \(format)",
            "\(resolution)，\(frameRate)，\(codec)，\(format)"
        )
    }

    func audioParameterDetail(
        codec: String,
        sampleRate: String,
        channels: String,
        bitrate: String,
        preset: String
    ) -> String {
        text(
            "\(codec), \(sampleRate), \(channels), \(bitrate), \(preset)",
            "\(codec)，\(sampleRate)，\(channels)，\(bitrate)，\(preset)"
        )
    }
}
