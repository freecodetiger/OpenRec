import SwiftUI

struct SaveFlowView: View {
    var snapshot: AppShellSnapshot
    var onSave: () -> Void = {}
    var onDiscard: () -> Void = {}

    private var strings: OpenRecLocalization {
        OpenRecLocalization(snapshot.appLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(strings.saveRecordingTitle, systemImage: "square.and.arrow.down")
                .font(.title2.weight(.semibold))

            Text(strings.saveRecordingDetail)
                .foregroundStyle(.secondary)

            LabeledContent(strings.status, value: strings.statusTitle(snapshot.status))
            LabeledContent(strings.target, value: snapshot.selectedTarget.summary)
            if let pendingSaveURL = snapshot.pendingSaveURL {
                LabeledContent(strings.temporaryFile, value: pendingSaveURL.lastPathComponent)
            }
            if let errorMessage = snapshot.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }

            HStack {
                Button(strings.saveAs, action: onSave)
                    .disabled(!canUseSaveActions)
                Button(strings.discard, role: .destructive, action: onDiscard)
                    .disabled(!canUseSaveActions)
            }
        }
        .padding(24)
    }

    private var canUseSaveActions: Bool {
        snapshot.status == .awaitingSave
    }
}
