import SwiftUI
import OpenRecCore

struct OnboardingView: View {
    var snapshot: AppShellSnapshot
    var onOpenPermissionSettings: (PermissionKind) -> Void = { _ in }
    var onRequestPermission: (PermissionKind) -> Void = { _ in }
    var onRefreshPermissions: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("OpenRec Permissions", systemImage: "lock.shield")
                .font(.title2.weight(.semibold))

            Text("OpenRec records locally and needs macOS access before capture can start.")
                .foregroundStyle(.secondary)

            PermissionPlaceholderView(
                snapshot: snapshot,
                onOpenPermissionSettings: onOpenPermissionSettings,
                onRequestPermission: onRequestPermission
            )

            Spacer()

            HStack {
                Button("Open System Settings") {
                    onRequestPermission(snapshot.requiredPermissions.first ?? .screenRecording)
                }
                Button("Re-check Permissions", action: onRefreshPermissions)
            }
        }
        .padding(28)
    }
}

struct PermissionPlaceholderView: View {
    var snapshot: AppShellSnapshot
    var onOpenPermissionSettings: (PermissionKind) -> Void = { _ in }
    var onRequestPermission: (PermissionKind) -> Void = { _ in }

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
                    Button("Open Settings") {
                        onRequestPermission(item.kind)
                    }
                }
            }
        }
    }
}
