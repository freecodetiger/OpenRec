import SwiftUI

struct SaveFlowView: View {
    var snapshot: AppShellSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Save Recording", systemImage: "square.and.arrow.down")
                .font(.title2.weight(.semibold))

            Text("Choose where to save the finished recording.")
                .foregroundStyle(.secondary)

            LabeledContent("Status", value: snapshot.status.title)
            LabeledContent("Target", value: snapshot.selectedTarget.summary)

            HStack {
                Button("Save As...") {}
                    .disabled(true)
                Button("Retry Save") {}
                    .disabled(true)
                Button("Discard") {}
                    .disabled(true)
            }
        }
        .padding(24)
    }
}
