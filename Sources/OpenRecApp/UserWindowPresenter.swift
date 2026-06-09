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
