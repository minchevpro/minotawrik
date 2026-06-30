import Cocoa
import AVFoundation

/// Centralizes the permission checks/prompts Vector Dictate needs:
/// microphone (to record) and Accessibility (to post the synthetic
/// Cmd+V and to watch for Enter/Escape globally while recording).
enum PermissionsManager {
    static func requestAccessibilityIfNeeded() {
        guard !PasteSimulator.isAccessibilityTrusted() else { return }
        // This triggers the system prompt that adds Vector Dictate to
        // System Settings → Privacy & Security → Accessibility.
        _ = PasteSimulator.isAccessibilityTrusted(promptIfNeeded: true)
    }

    static func showAccessibilityInstructionsIfNeeded() {
        guard !PasteSimulator.isAccessibilityTrusted() else { return }

        let alert = NSAlert()
        alert.messageText = "Нужен доступ Accessibility"
        alert.informativeText = """
        Чтобы Vector Dictate мог автоматически вставлять текст (Cmd+V) и реагировать на Enter/Esc во время записи, разрешите доступ в:
        Системные настройки → Конфиденциальность и безопасность → Универсальный доступ.

        Без этого разрешения диктовка всё равно будет работать, текст будет копироваться в буфер обмена и сохраняться в историю — просто без автоматической вставки.
        """
        alert.addButton(withTitle: "Открыть настройки")
        alert.addButton(withTitle: "Позже")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    static func microphoneStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }
}
