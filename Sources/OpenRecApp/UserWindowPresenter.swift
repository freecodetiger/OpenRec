import AppKit

@MainActor
protocol ForegroundActivating {
    func activateIgnoringOtherApps()
}

@MainActor
struct NSApplicationForegroundActivator: ForegroundActivating {
    func activateIgnoringOtherApps() {
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
struct UserWindowPresenter {
    private let foregroundActivator: any ForegroundActivating

    init(foregroundActivator: any ForegroundActivating = NSApplicationForegroundActivator()) {
        self.foregroundActivator = foregroundActivator
    }

    func activateApplication() {
        foregroundActivator.activateIgnoringOtherApps()
    }

    func present(_ openWindow: () -> Void) {
        activateApplication()
        openWindow()
    }
}

@MainActor
struct OnboardingWindowPresentationGate {
    private var hasPresentedOnboarding = false

    mutating func presentIfNeeded(
        for snapshot: AppShellSnapshot,
        presenter: UserWindowPresenter,
        openWindow: () -> Void
    ) {
        guard snapshot.status == .permissionRequired,
              !snapshot.requiredPermissions.isEmpty,
              !hasPresentedOnboarding else {
            return
        }

        hasPresentedOnboarding = true
        presenter.present(openWindow)
    }
}
