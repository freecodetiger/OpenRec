import SwiftUI
import OpenRecCore

struct SourceSelectionView: View {
    @ObservedObject var viewModel: AppShellViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SourceSelectionDraft
    @State private var overlayPresenter = WindowSelectionOverlayPresenter()

    private var strings: OpenRecLocalization {
        OpenRecLocalization(viewModel.snapshot.appLanguage)
    }

    init(viewModel: AppShellViewModel) {
        self.viewModel = viewModel
        _draft = State(initialValue: SourceSelectionDraft(snapshot: viewModel.snapshot))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(strings.sourceSelectionTitle, systemImage: "rectangle.dashed")
                .font(.title2.weight(.semibold))

            Text(strings.chooseSourceDetail)
                .foregroundStyle(.secondary)

            modePicker
            if draft.mode == .window {
                overlayAction
            }
            targetList
            actions
        }
        .padding(24)
        .onChange(of: viewModel.snapshot) { _, snapshot in
            draft = SourceSelectionDraft(snapshot: snapshot)
        }
        .onAppear {
            if draft.mode == .window {
                openWindowSelectionOverlay()
            }
        }
        .onChange(of: draft.mode) { _, mode in
            if mode == .window {
                openWindowSelectionOverlay()
            } else {
                overlayPresenter.dismiss()
            }
        }
        .onDisappear {
            overlayPresenter.dismiss()
        }
    }

    private var modePicker: some View {
        Picker(strings.mode, selection: Binding(
            get: { draft.mode },
            set: { draft.selectMode($0) }
        )) {
            Text(strings.displayRecording).tag(CaptureMode.display)
            Text(strings.windowRecordingMode).tag(CaptureMode.window)
        }
        .pickerStyle(.segmented)
    }

    private var overlayAction: some View {
        Button {
            openWindowSelectionOverlay()
        } label: {
            Label(strings.selectWindowOnScreen, systemImage: "macwindow.badge.plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(draft.visibleTargets.isEmpty)
    }

    private var targetList: some View {
        List(draft.visibleTargets) { target in
            targetRow(target)
        }
        .frame(minHeight: 180)
    }

    private func targetRow(_ target: SourceTargetOption) -> some View {
        Button {
            draft.selectTarget(id: target.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: draft.selectedTargetID == target.id ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(draft.selectedTargetID == target.id ? Color.accentColor : Color.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 4) {
                    Text(target.title)
                        .foregroundStyle(.primary)
                    Text(target.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var actions: some View {
        HStack {
            Button(strings.cancel) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button(strings.useSelectedSource) {
                viewModel.applySourceSelection(draft)
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!draft.canApply)
        }
    }

    private func openWindowSelectionOverlay() {
        guard !draft.visibleTargets.isEmpty else { return }

        overlayPresenter.present(
            targets: draft.visibleTargets,
            onSelect: { targetID in
                draft.selectTarget(id: targetID)
                viewModel.applySourceSelection(draft)
                dismiss()
            },
            onCancel: {}
        )
    }
}
