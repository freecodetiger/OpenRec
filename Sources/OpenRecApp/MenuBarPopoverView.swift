import AppKit
import SwiftUI
import OpenRecCore

struct MenuBarPopoverView: View {
    @ObservedObject var viewModel: AppShellViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StatusHeader(snapshot: viewModel.snapshot)

            Divider()

            modePicker
            targetPicker
            microphonePicker
            permissionDetails
            permissionActions

            Divider()

            Button {
                viewModel.toggleRecording()
            } label: {
                Label(viewModel.primaryActionTitle, systemImage: viewModel.isRecording ? "stop.fill" : "record.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canStartRecording && !viewModel.isRecording)

            quickActions
        }
        .padding(16)
        .frame(width: 340)
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mode")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Mode", selection: Binding(
                get: { viewModel.snapshot.mode },
                set: { viewModel.selectMode($0) }
            )) {
                Text("Display Recording").tag(CaptureMode.display)
                Text("Window Recording").tag(CaptureMode.window)
            }
            .pickerStyle(.segmented)
        }
    }

    private var targetPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Target", systemImage: "rectangle.dashed")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Target", selection: Binding(
                get: { viewModel.snapshot.selectedTarget.id },
                set: { viewModel.selectTarget(id: $0) }
            )) {
                ForEach(viewModel.visibleTargets) { target in
                    Text(target.title).tag(target.id)
                }
            }

            Text(viewModel.snapshot.selectedTarget.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var microphonePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Microphone", systemImage: "mic")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Microphone", selection: Binding(
                get: { viewModel.snapshot.selectedMicrophoneID },
                set: { viewModel.selectMicrophone(id: $0) }
            )) {
                ForEach(viewModel.snapshot.microphones) { microphone in
                    Text(microphone.title).tag(microphone.id)
                }
            }
        }
    }

    @ViewBuilder
    private var permissionDetails: some View {
        if viewModel.snapshot.status == .permissionRequired {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(PermissionDisplayItem.items(for: viewModel.snapshot), id: \.kind) { item in
                    if item.isRequired {
                        Label(item.statusText, systemImage: "exclamationmark.triangle")
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
            Button {
                openWindow(id: "source-selection")
            } label: {
                Label("Sources", systemImage: "macwindow.badge.plus")
            }

            Button {
                openWindow(id: "preferences")
            } label: {
                Label("Preferences", systemImage: "gearshape")
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
