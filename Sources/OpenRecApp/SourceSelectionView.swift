import SwiftUI
import OpenRecCore

struct SourceSelectionView: View {
    @ObservedObject var viewModel: AppShellViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SourceSelectionDraft

    init(viewModel: AppShellViewModel) {
        self.viewModel = viewModel
        _draft = State(initialValue: SourceSelectionDraft(snapshot: viewModel.snapshot))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Source Selection", systemImage: "rectangle.dashed")
                .font(.title2.weight(.semibold))

            Text("Choose the display or window OpenRec should record.")
                .foregroundStyle(.secondary)

            modePicker
            targetList
            actions
        }
        .padding(24)
        .onChange(of: viewModel.snapshot) { _, snapshot in
            draft = SourceSelectionDraft(snapshot: snapshot)
        }
    }

    private var modePicker: some View {
        Picker("Mode", selection: Binding(
            get: { draft.mode },
            set: { draft.selectMode($0) }
        )) {
            Text("Display Recording").tag(CaptureMode.display)
            Text("Window Recording").tag(CaptureMode.window)
        }
        .pickerStyle(.segmented)
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
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button("Use Selected Source") {
                viewModel.applySourceSelection(draft)
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!draft.canApply)
        }
    }
}
