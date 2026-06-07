import SwiftUI

struct OnboardingView: View {
    var snapshot: AppShellSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("OpenRec Permissions", systemImage: "lock.shield")
                .font(.title2.weight(.semibold))

            Text("OpenRec records locally and needs macOS access before capture can start.")
                .foregroundStyle(.secondary)

            PermissionPlaceholderView(snapshot: snapshot)

            Spacer()

            HStack {
                Button("Open System Settings") {}
                    .disabled(true)
                Button("Re-check Permissions") {}
                    .disabled(true)
            }
        }
        .padding(28)
    }
}

struct PermissionPlaceholderView: View {
    var snapshot: AppShellSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(PermissionDisplayItem.items(for: snapshot), id: \.kind) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(item.isGranted ? .green : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                        Text(item.reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
    }
}
