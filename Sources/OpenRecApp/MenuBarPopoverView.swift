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
        switch snapshot.status {
        case .ready:
            MenuBarPresentationModel(
                showsSourceActions: true,
                showsMicrophone: true,
                showsSettingsSummary: true,
                showsPermissionActions: false,
                showsSaveActions: false,
                showsPreferences: true,
                primaryActionTitle: "Start Full Screen Recording",
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
                primaryActionTitle: "Stop Recording",
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
                primaryActionTitle: "Start Full Screen Recording",
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
                primaryActionTitle: "Save Again",
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
                primaryActionTitle: "Start Full Screen Recording",
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
    private let elapsedTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var presentation: MenuBarPresentationModel {
        MenuBarPresentationModel.make(
            snapshot: viewModel.snapshot,
            isRecording: viewModel.isRecording,
            canStartRecording: viewModel.canStartRecording
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StatusHeader(snapshot: viewModel.snapshot)

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
    }

    @ViewBuilder
    private var stateContent: some View {
        switch viewModel.snapshot.status {
        case .ready:
            fullScreenPrimaryAction
            sourceActions
            microphonePicker
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
            viewModel.selectMode(.display)
            viewModel.startRecording()
        } label: {
            Label(presentation.primaryActionTitle, systemImage: presentation.primaryActionSymbolName)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!presentation.isPrimaryActionEnabled)
    }

    private var primaryRecordingAction: some View {
        Button {
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
            Text("Record another source")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    onCloseMenu()
                    onRequestWindowRecordingWorkflow()
                } label: {
                    sourceActionLabel("Window...", systemImage: "macwindow")
                }
                .buttonStyle(.bordered)

                Button {
                    onCloseMenu()
                    onRequestApplicationRecordingWorkflow()
                } label: {
                    sourceActionLabel("Application...", systemImage: "square.stack.3d.up")
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
            Label("Microphone", systemImage: "mic")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)

            Picker("Microphone", selection: Binding(
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
        let settings = viewModel.snapshot.settings
        return "\(settings.qualityPreset.label) · \(settings.frameRate.label) · \(settings.videoCodec.label)"
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
        }
    }

    private var saveActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                viewModel.saveRecording()
            } label: {
                Label("Save Again", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSaveRecording)

            Button(role: .destructive) {
                viewModel.discardRecording()
            } label: {
                Label("Discard Recording", systemImage: "trash")
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
            Label("Re-check", systemImage: "arrow.clockwise")
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
                            Label(item.statusText, systemImage: "exclamationmark.triangle")
                            if item.kind == .screenRecording {
                                Button {
                                    viewModel.reopenApplication()
                                } label: {
                                    Label("Reopen OpenRec", systemImage: "arrow.clockwise.circle")
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
                    Label("Open System Settings", systemImage: "gearshape")
                }

                Button {
                    viewModel.refreshPermissions()
                } label: {
                    Label("Re-check", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
        }
    }

    private var quickActions: some View {
        HStack {
            if presentation.showsPreferences {
                Button {
                    openWindow(id: "preferences")
                } label: {
                    Label("Preferences", systemImage: "gearshape")
                }
            }

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
        }
        .buttonStyle(.borderless)
    }
}

private struct StatusHeader: View {
    var snapshot: AppShellSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: snapshot.status.symbolName)
                .font(.title2)
                .foregroundStyle(snapshot.status.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(snapshot.status.title)
                        .font(.headline)
                    Spacer()
                    if let elapsedTimeText = snapshot.elapsedTimeText {
                        Text(elapsedTimeText)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(snapshot.errorMessage ?? snapshot.status.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
