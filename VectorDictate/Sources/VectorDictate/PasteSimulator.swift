import Cocoa
import ApplicationServices

/// Puts text on the clipboard and, if possible, simulates Cmd+V so it lands
/// in whatever field was focused before the dictation panel appeared.
///
/// Design note: we deliberately do NOT try to detect or address a specific
/// text field (no Accessibility-API "find the focused element and set its
/// value" trick). That approach breaks constantly across different apps,
/// web views, and frameworks. Clipboard + synthetic Cmd+V is what every
/// frontmost app already knows how to handle, so it is far more reliable.
/// If the frontmost app rejects/ignores the paste, the text still sits on
/// the clipboard and in history — nothing is lost.
enum PasteSimulator {
    /// Returns true if macOS has granted this app Accessibility permission,
    /// which is required both for posting synthetic key events and for the
    /// global key-down monitor used to detect Enter/Escape while recording.
    static func isAccessibilityTrusted(promptIfNeeded: Bool = false) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        let options: [NSString: Bool] = [key: promptIfNeeded]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Always copies `text` to the general pasteboard. This step never
    /// fails and never requires any special permission — it's the
    /// guaranteed fallback the spec calls for: even if auto-paste can't
    /// run, the text is on the clipboard and in history.
    static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Simulates Cmd+V into whatever app/field currently has focus.
    /// Requires Accessibility permission; returns whether the synthetic
    /// keystroke was posted — not a guarantee it landed in a text field,
    /// since some apps legitimately ignore paste outside an editable
    /// context (the text remains safely on the clipboard either way).
    @discardableResult
    static func paste() -> Bool {
        guard isAccessibilityTrusted() else { return false }
        postCmdV()
        return true
    }

    private static func postCmdV() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }

        let vKeyCode: CGKeyCode = 9 // kVK_ANSI_V

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
