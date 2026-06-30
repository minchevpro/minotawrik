import Cocoa
import AVFoundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // no Dock icon, menu-bar-only app

        statusBarController = StatusBarController()

        HotkeyManager.shared.onHotkeyPressed = {
            DictationPanelController.shared.toggleFromHotkey()
        }
        HotkeyManager.shared.registerCurrentHotkey()

        // Touch the panel controller once at launch so its NSPanel is built
        // up front rather than on the first hotkey press.
        _ = DictationPanelController.shared

        requestInitialPermissions()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.unregister()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    private func requestInitialPermissions() {
        // Ask for microphone access immediately so the first dictation
        // isn't delayed by a permission dialog. Accessibility is prompted
        // lazily (see PermissionsManager) since it requires the user to
        // leave the app to grant it in System Settings.
        switch PermissionsManager.microphoneStatus() {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        default:
            break
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            PermissionsManager.showAccessibilityInstructionsIfNeeded()
        }
    }
}
