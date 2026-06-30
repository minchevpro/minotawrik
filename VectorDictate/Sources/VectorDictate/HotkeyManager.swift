import Cocoa
import Carbon.HIToolbox

/// Wraps the Carbon `RegisterEventHotKey` API to provide a truly global
/// keyboard shortcut that fires no matter which app is frontmost, without
/// requiring Accessibility permission (unlike a CGEventTap).
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x56445054 /* 'VDPT' */), id: 1)

    /// Called every time the registered hotkey is pressed.
    var onHotkeyPressed: (() -> Void)?

    private init() {}

    func registerCurrentHotkey() {
        register(combo: AppSettings.shared.hotkey)
    }

    func register(combo: HotkeyCombo) {
        unregister()
        installEventHandlerIfNeeded()

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if status == noErr {
            hotKeyRef = ref
        } else {
            NSLog("VectorDictate: failed to register hotkey, status=\(status)")
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))

        let callback: EventHandlerUPP = { _, eventRef, userData in
            guard let userData, let eventRef else { return noErr }
            var receivedID = EventHotKeyID()
            let status = GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &receivedID
            )
            guard status == noErr else { return status }

            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            if receivedID.id == manager.hotKeyID.id {
                DispatchQueue.main.async {
                    manager.onHotkeyPressed?()
                }
            }
            return noErr
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType, selfPtr, &eventHandler)
    }
}

/// Lightweight helper for capturing a key combo typed by the user in the
/// Settings UI (used by the shortcut-recorder control).
enum HotkeyCapture {
    /// Translate an NSEvent's modifier flags into the Carbon modifier mask
    /// expected by `RegisterEventHotKey`.
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }
}
