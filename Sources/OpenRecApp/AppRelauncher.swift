import Foundation

#if os(macOS)
import AppKit
#endif

@MainActor
protocol AppRelaunching: AnyObject {
    func reopenApplication()
}

@MainActor
final class NSWorkspaceAppRelauncher: AppRelaunching {
    func reopenApplication() {
        #if os(macOS)
        guard let bundleURL = Bundle.main.bundleURL as URL? else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, error in
            if error == nil {
                NSApplication.shared.terminate(nil)
            }
        }
        #endif
    }
}
