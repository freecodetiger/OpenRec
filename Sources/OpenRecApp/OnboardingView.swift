import SwiftUI
import OpenRecCore

struct OnboardingView: View {
    var snapshot: AppShellSnapshot
    var onOpenPermissionSettings: (PermissionKind) -> Void = { _ in }
    var onRequestPermission: (PermissionKind) -> Void = { _ in }
    var onRefreshPermissions: () -> Void = {}

    private var strings: OpenRecLocalization {
        OpenRecLocalization(snapshot.appLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(strings.openRecPermissions, systemImage: "lock.shield")
                .font(.title2.weight(.semibold))

            Text(strings.permissionsIntro)
                .foregroundStyle(.secondary)

            PermissionPlaceholderView(
                snapshot: snapshot,
                strings: strings,
                onOpenPermissionSettings: onOpenPermissionSettings,
                onRequestPermission: onRequestPermission
            )

            Spacer()

            HStack {
                Button(strings.openSystemSettings) {
                    onRequestPermission(snapshot.requiredPermissions.first ?? .screenRecording)
                }
                Button(strings.recheckPermissions, action: onRefreshPermissions)
            }
        }
        .padding(28)
    }
}

struct PermissionPlaceholderView: View {
    var snapshot: AppShellSnapshot
    var strings: OpenRecLocalization = OpenRecLocalization(.english)
    var onOpenPermissionSettings: (PermissionKind) -> Void = { _ in }
    var onRequestPermission: (PermissionKind) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(PermissionDisplayItem.items(for: snapshot), id: \.kind) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(item.isGranted ? .green : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(strings.permissionTitle(item.kind))
                        Text(strings.permissionReason(item.kind))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(strings.openSettings) {
                        onRequestPermission(item.kind)
                    }
                }
            }
        }
    }
}
