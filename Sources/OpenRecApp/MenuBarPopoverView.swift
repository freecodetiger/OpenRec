import AppKit
import SwiftUI
import OpenRecCore

struct MenuBarPresentationModel: Equatable {
    var showsSourceActions: Bool
    var showsMicrophone: Bool
    var showsSettingsSummary: Bool
    var showsPermissionActions: Bool
    var showsSaveActions: Bool
    var showsPreferences: Bool
    var primaryActionTitle: String
    var primaryActionSymbolName: String
    var isPrimaryActionEnabled: Bool

    static func make(snapshot: AppShellSnapshot, isRecording: Bool, canStartRecording: Bool) -> MenuBarPresentationModel {
        let strings = OpenRecLocalization(snapshot.appLanguage)

        return switch snapshot.status {
        case .ready:
            MenuBarPresentationModel(
                showsSourceActions: true,
                showsMicrophone: true,
                showsSettingsSummary: true,
                showsPermissionActions: false,
                showsSaveActions: false,
                showsPreferences: true,
                primaryActionTitle: strings.startFullScreenRecording,
                primaryActionSymbolName: "record.circle",
                isPrimaryActionEnabled: canStartRecording
            )
        case .recording:
            MenuBarPresentationModel(
                showsSourceActions: false,
                showsMicrophone: false,
                showsSettingsSummary: false,
                showsPermissionActions: false,
                showsSaveActions: false,
                showsPreferences: false,
                primaryActionTitle: strings.stopRecording,
                primaryActionSymbolName: "stop.fill",
                isPrimaryActionEnabled: isRecording
            )
        case .permissionRequired:
            MenuBarPresentationModel(
                showsSourceActions: false,
                showsMicrophone: false,
                showsSettingsSummary: false,
                showsPermissionActions: true,
                showsSaveActions: false,
                showsPreferences: true,
                primaryActionTitle: strings.startFullScreenRecording,
                primaryActionSymbolName: "record.circle",
                isPrimaryActionEnabled: false
            )
        case .awaitingSave:
            MenuBarPresentationModel(
                showsSourceActions: false,
                showsMicrophone: false,
                showsSettingsSummary: false,
                showsPermissionActions: false,
                showsSaveActions: true,
                showsPreferences: false,
                primaryActionTitle: strings.saveAgain,
                primaryActionSymbolName: "square.and.arrow.down",
                isPrimaryActionEnabled: true
            )
        case .error:
            MenuBarPresentationModel(
                showsSourceActions: false,
                showsMicrophone: false,
                showsSettingsSummary: false,
                showsPermissionActions: false,
                showsSaveActions: false,
                showsPreferences: true,
                primaryActionTitle: strings.startFullScreenRecording,
                primaryActionSymbolName: "record.circle",
                isPrimaryActionEnabled: false
            )
        }
    }
}

struct MenuBarPopoverView: View {
    @ObservedObject var viewModel: AppShellViewModel
    var onRequestWindowRecordingWorkflow: () -> Void = {}
    var onRequestApplicationRecordingWorkflow: () -> Void = {}
    var onCloseMenu: () -> Void = {}

    @Environment(\.openWindow) private var openWindow
    private let windowPresenter = UserWindowPresenter()
    private let elapsedTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let audioLevelTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private var presentation: MenuBarPresentationModel {
        MenuBarPresentationModel.make(
            snapshot: viewModel.snapshot,
            isRecording: viewModel.isRecording,
            canStartRecording: viewModel.canStartRecording
        )
    }
    private var strings: OpenRecLocalization {
        OpenRecLocalization(viewModel.snapshot.appLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StatusHeader(snapshot: viewModel.snapshot, strings: strings)

            Divider()

            stateContent

            Divider()

            quickActions
        }
        .padding(16)
        .frame(width: 340)
        .onReceive(elapsedTimer) { _ in
            viewModel.refreshElapsedTime()
        }
        .onReceive(audioLevelTimer) { _ in
            viewModel.refreshAudioLevel()
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch viewModel.snapshot.status {
        case .ready:
            fullScreenPrimaryAction
            sourceActions
            microphonePicker
            microphoneLevelIndicator
            settingsSummary
        case .recording:
            recordingSummary
            primaryRecordingAction
        case .permissionRequired:
            permissionDetails
            permissionActions
        case .awaitingSave:
            saveActions
        case .error:
            errorActions
        }
    }

    private var fullScreenPrimaryAction: some View {
        Button {
            viewModel.requestFullScreenRecording()
        } label: {
            Label(presentation.primaryActionTitle, systemImage: presentation.primaryActionSymbolName)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!presentation.isPrimaryActionEnabled)
    }

    private var primaryRecordingAction: some View {
        Button {
            onCloseMenu()
            viewModel.stopRecording()
        } label: {
            Label(presentation.primaryActionTitle, systemImage: presentation.primaryActionSymbolName)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!presentation.isPrimaryActionEnabled)
    }

    private var sourceActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(strings.recordAnotherSource)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    onCloseMenu()
                    onRequestWindowRecordingWorkflow()
                } label: {
                    sourceActionLabel(strings.windowRecording, systemImage: "macwindow")
                }
                .buttonStyle(.bordered)

                Button {
                    onCloseMenu()
                    onRequestApplicationRecordingWorkflow()
                } label: {
                    sourceActionLabel(strings.applicationRecording, systemImage: "square.stack.3d.up")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func sourceActionLabel(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
            Text(title)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 58)
    }

    private var microphonePicker: some View {
        HStack(spacing: 10) {
            Label(strings.microphone, systemImage: "mic")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)

            Picker(strings.microphone, selection: Binding(
                get: { viewModel.snapshot.selectedMicrophoneID },
                set: { viewModel.selectMicrophone(id: $0) }
            )) {
                ForEach(viewModel.snapshot.microphones) { microphone in
                    Text(microphone.title).tag(microphone.id)
                }
            }
            .labelsHidden()
        }
    }

    private var microphoneLevelIndicator: some View {
        MicrophoneLevelIndicator(
            presentation: MicrophoneLevelPresentation.make(
                snapshot: viewModel.snapshot,
                strings: strings
            )
        )
    }

    private var settingsSummary: some View {
        HStack(spacing: 8) {
            Image(systemName: "slider.horizontal.3")
                .foregroundStyle(.secondary)
            Text(settingsSummaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
    }

    private var settingsSummaryText: String {
        let summary = RecordingParameterSummary.make(
            target: viewModel.snapshot.selectedTarget,
            settings: viewModel.snapshot.settings,
            strings: strings
        )
        return "\(summary.bitrateText) · \(summary.videoDetailText) · \(summary.audioDetailText)"
    }

    private var recordingSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(viewModel.snapshot.selectedTarget.title, systemImage: "rectangle.dashed")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(viewModel.snapshot.selectedTarget.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            microphoneLevelIndicator
        }
    }

    private var saveActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                viewModel.saveRecording()
            } label: {
                Label(strings.saveAgain, systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSaveRecording)

            Button(role: .destructive) {
                viewModel.discardRecording()
            } label: {
                Label(strings.discardRecording, systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canDiscardRecording)
        }
    }

    private var errorActions: some View {
        Button {
            Task {
                await viewModel.refresh()
            }
        } label: {
            Label(strings.recheck, systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private var permissionDetails: some View {
        if viewModel.snapshot.status == .permissionRequired {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(PermissionDisplayItem.items(for: viewModel.snapshot), id: \.kind) { item in
                    if item.isRequired {
                        VStack(alignment: .leading, spacing: 2) {
                            Label(strings.permissionStatusText(item), systemImage: "exclamationmark.triangle")
                            if item.kind == .screenRecording {
                                Button {
                                    viewModel.reopenApplication()
                                } label: {
                                    Label(strings.reopenOpenRec, systemImage: "arrow.clockwise.circle")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var permissionActions: some View {
        if viewModel.snapshot.status == .permissionRequired {
            HStack {
                Button {
                    viewModel.requestPermission(
                        for: viewModel.snapshot.requiredPermissions.first ?? .screenRecording
                    )
                } label: {
                    Label(strings.openSystemSettings, systemImage: "gearshape")
                }

                Button {
                    viewModel.refreshPermissions()
                } label: {
                    Label(strings.recheck, systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
        }
    }

    private var quickActions: some View {
        HStack {
            if presentation.showsPreferences {
                Button {
                    windowPresenter.present {
                        openWindow(id: "preferences")
                    }
                } label: {
                    Label(strings.preferencesTitle, systemImage: "gearshape")
                }
            }

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label(strings.quit, systemImage: "power")
            }
        }
        .buttonStyle(.borderless)
    }
}

private struct StatusHeader: View {
    var snapshot: AppShellSnapshot
    var strings: OpenRecLocalization

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: snapshot.status.symbolName)
                .font(.title2)
                .foregroundStyle(snapshot.status.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(strings.statusTitle(snapshot.status))
                        .font(.headline)
                    Spacer()
                    if let elapsedTimeText = snapshot.elapsedTimeText {
                        Text(elapsedTimeText)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(snapshot.errorMessage ?? strings.statusDetail(snapshot.status))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
