import SwiftUI
import OpenRecCore

struct SourceSelectionView: View {
    var snapshot: AppShellSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Source Selection", systemImage: "rectangle.dashed")
                .font(.title2.weight(.semibold))

            Text("This boundary will host display selection and the transparent window picker overlay.")
                .foregroundStyle(.secondary)

            Picker("Mode", selection: .constant(snapshot.mode)) {
                Text("Display Recording").tag(CaptureMode.display)
                Text("Window Recording").tag(CaptureMode.window)
            }
            .pickerStyle(.segmented)

            List(snapshot.availableTargets) { target in
                VStack(alignment: .leading, spacing: 4) {
                    Text(target.title)
                    Text(target.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button("Cancel") {}
                    .disabled(true)
                Button("Use Selected Source") {}
                    .disabled(true)
            }
        }
        .padding(24)
    }
}
