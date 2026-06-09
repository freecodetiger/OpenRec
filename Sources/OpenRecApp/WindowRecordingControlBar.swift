import AppKit
import SwiftUI
import OpenRecCore

struct WindowRecordingControlBarLayout: Equatable {
    var targetFrame: CGRect?
    var visibleScreenFrame: CGRect

    private let preferredSize = CGSize(width: 760, height: 96)
    private let compactHeight: CGFloat = 128
    private let minimumSize = CGSize(width: 320, height: 96)
    private let edgeInset: CGFloat = 12

    func panelFrame() -> CGRect {
        guard let targetFrame, targetFrame.width > 0, targetFrame.height > 0 else {
            return fallbackFrame()
        }

        let clampingFrame = targetFrame.intersection(visibleScreenFrame)
        guard !clampingFrame.isNull, !clampingFrame.isEmpty else {
            return fallbackFrame()
        }

        let width = min(preferredSize.width, max(minimumSize.width, clampingFrame.width - edgeInset * 2))
        let height = clampingFrame.height < 220 ? min(compactHeight, max(minimumSize.height, clampingFrame.height - edgeInset * 2)) : preferredSize.height
        let proposedX = targetFrame.midX - width / 2
        let proposedY = targetFrame.minY + edgeInset

        return CGRect(
            x: clamp(proposedX, min: clampingFrame.minX + edgeInset, max: clampingFrame.maxX - edgeInset - width),
            y: clamp(proposedY, min: clampingFrame.minY + edgeInset, max: clampingFrame.maxY - edgeInset - height),
            width: width,
            height: height
        )
    }

    private func fallbackFrame() -> CGRect {
        let width = min(preferredSize.width, max(minimumSize.width, visibleScreenFrame.width - edgeInset * 2))
        let height = min(preferredSize.height, max(minimumSize.height, visibleScreenFrame.height - edgeInset * 2))

        return CGRect(
            x: visibleScreenFrame.midX - width / 2,
            y: visibleScreenFrame.midY - height / 2,
            width: width,
            height: height
        )
    }

    private func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        guard minimum <= maximum else { return minimum }
        return Swift.min(Swift.max(value, minimum), maximum)
    }
}

struct WindowRecordingControlBarView: View {
    var snapshot: AppShellSnapshot
    var onSettingsChange: @MainActor (RecordingSettings) -> Void = { _ in }
    var onStart: @MainActor () -> Void = {}
    var onCancel: @MainActor () -> Void = {}

    @State private var draftSettings: RecordingSettings

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
        onSettingsChange: @escaping @MainActor (RecordingSettings) -> Void = { _ in },
        onStart: @escaping @MainActor () -> Void = {},
        onCancel: @escaping @MainActor () -> Void = {}
    ) {
        self.snapshot = snapshot
        self.onSettingsChange = onSettingsChange
        self.onStart = onStart
        self.onCancel = onCancel
        _draftSettings = State(initialValue: snapshot.settings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                settingPicker(strings.format, selection: settingBinding(\.outputFormat), values: OutputFormat.allCases) { $0.label }
                settingPicker(strings.codec, selection: settingBinding(\.videoCodec), values: VideoCodec.allCases) { $0.label }
                settingPicker(strings.frameRate, selection: settingBinding(\.frameRate), values: FrameRatePreset.allCases) { $0.label }
                settingPicker(strings.quality, selection: settingBinding(\.qualityPreset), values: QualityPreset.allCases) {
                    strings.qualityLabel($0)
                }
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(strings.quality): \(parameterSummary.bitrateText)")
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                    Text("\(parameterSummary.videoDetailText) · \(parameterSummary.audioDetailText)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(minWidth: 220, alignment: .leading)

                Picker(strings.microphone, selection: microphoneBinding) {
                    ForEach(snapshot.microphones) { microphone in
                        Text(microphone.title).tag(microphone.id)
                    }
                }
                .labelsHidden()
                .frame(minWidth: 160)

                Spacer(minLength: 8)

                Button(strings.cancel, role: .cancel) {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button(strings.start) {
                    onStart()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minWidth: 320, idealWidth: 760, maxWidth: .infinity, minHeight: 96, alignment: .center)
        .background(.regularMaterial)
        .onChange(of: snapshot) { _, snapshot in
            draftSettings = snapshot.settings
        }
    }

    private var microphoneBinding: Binding<String> {
        Binding(
            get: {
                snapshot.microphones.first { $0.deviceID == draftSettings.microphoneDeviceID }?.id ??
                    snapshot.selectedMicrophoneID
            },
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

    private func settingPicker<Value: Hashable>(
        _ title: String,
        selection: Binding<Value>,
        values: [Value],
        label: @escaping (Value) -> String
    ) -> some View {
        Picker(title, selection: selection) {
            ForEach(values, id: \.self) { value in
                Text(label(value)).tag(value)
            }
        }
        .labelsHidden()
        .frame(minWidth: 86)
    }
}

@MainActor
final class WindowRecordingControlBarPresenter {
    private var panel: NSPanel?

    func present(
        target: SourceTargetOption,
        snapshot: AppShellSnapshot,
        onSettingsChange: @escaping @MainActor (RecordingSettings) -> Void,
        onStart: @escaping @MainActor () -> Void,
        onCancel: @escaping @MainActor () -> Void
    ) {
        dismiss()

        let visibleScreenFrame = Self.visibleScreenFrame(containing: target.screenFrame)
        let frame = WindowRecordingControlBarLayout(
            targetFrame: target.screenFrame,
            visibleScreenFrame: visibleScreenFrame
        ).panelFrame()
        let controlPanel = WindowRecordingControlBarPanel(
            contentRect: frame,
            onCancel: { [weak self] in
                self?.dismiss()
                onCancel()
            }
        )

        controlPanel.contentView = NSHostingView(
            rootView: WindowRecordingControlBarView(
                snapshot: snapshot,
                onSettingsChange: onSettingsChange,
                onStart: { [weak self] in
                    self?.dismiss()
                    onStart()
                },
                onCancel: { [weak self] in
                    self?.dismiss()
                    onCancel()
                }
            )
        )
        controlPanel.setFrame(frame, display: true)
        controlPanel.orderFrontRegardless()
        panel = controlPanel
    }

    func dismiss() {
        panel?.close()
        panel = nil
    }

    private static func visibleScreenFrame(containing targetFrame: CGRect?) -> CGRect {
        if let targetFrame,
           let screen = NSScreen.screens.first(where: { $0.frame.intersects(targetFrame) }) {
            return screen.visibleFrame
        }

        return NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 760, height: 420)
    }
}

private final class WindowRecordingControlBarPanel: NSPanel {
    private let onCancel: @MainActor () -> Void

    init(
        contentRect: CGRect,
        onCancel: @escaping @MainActor () -> Void
    ) {
        self.onCancel = onCancel
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        ignoresMouseEvents = false
    }

    override var canBecomeKey: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel()
            return
        }

        super.keyDown(with: event)
    }
}
