import SwiftUI

struct SaveFlowView: View {
    var snapshot: AppShellSnapshot
    var onSave: () -> Void = {}
    var onRetrySave: () -> Void = {}
    var onDiscard: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Save Recording", systemImage: "square.and.arrow.down")
                .font(.title2.weight(.semibold))

            Text("Choose where to save the finished recording.")
                .foregroundStyle(.secondary)

            LabeledContent("Status", value: snapshot.status.title)
            LabeledContent("Target", value: snapshot.selectedTarget.summary)
            if let pendingSaveURL = snapshot.pendingSaveURL {
                LabeledContent("Temporary File", value: pendingSaveURL.lastPathComponent)
            }
            if let errorMessage = snapshot.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }

            HStack {
                Button("Save As...", action: onSave)
                    .disabled(!canUseSaveActions)
                Button("Retry Save", action: onRetrySave)
                    .disabled(!canUseSaveActions)
                Button("Discard", role: .destructive, action: onDiscard)
                    .disabled(!canUseSaveActions)
            }
        }
        .padding(24)
    }

    private var canUseSaveActions: Bool {
        snapshot.status == .awaitingSave
    }
}
