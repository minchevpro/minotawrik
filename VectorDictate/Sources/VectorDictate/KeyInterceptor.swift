import Cocoa
import CoreGraphics

/// Watches for Enter/Escape while a dictation is in progress.
///
/// When Accessibility permission is granted, this installs a CGEventTap so
/// the keystroke is *swallowed* before it reaches the focused app — so
/// pressing Enter to stop dictation doesn't also submit a chat message or
/// insert a newline wherever the user was typing. Without Accessibility
/// permission it falls back to a passive global monitor: stop/cancel still
/// fires, but the keystroke also continues on to the focused app since a
/// passive monitor cannot block events.
final class KeyInterceptor {
    var onEnter: (() -> Void)?
    var onEscape: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var fallbackGlobalMonitor: Any?
    private var fallbackLocalMonitor: Any?

    func start() {
        stop()
        if PasteSimulator.isAccessibilityTrusted(), installEventTap() {
            return
        }
        installFallbackMonitors()
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil

        if let fallbackGlobalMonitor { NSEvent.removeMonitor(fallbackGlobalMonitor) }
        if let fallbackLocalMonitor { NSEvent.removeMonitor(fallbackLocalMonitor) }
        fallbackGlobalMonitor = nil
        fallbackLocalMonitor = nil
    }

    private func installEventTap() -> Bool {
        let mask: CGEventMask = 1 << CGEventType.keyDown.rawValue

        let callback: CGEventTapCallBack = { _, type, cgEvent, refcon in
            guard type == .keyDown, let refcon else {
                return Unmanaged.passRetained(cgEvent)
            }
            let interceptor = Unmanaged<KeyInterceptor>.fromOpaque(refcon).takeUnretainedValue()
            let keyCode = cgEvent.getIntegerValueField(.keyboardEventKeycode)

            switch keyCode {
            case 36, 76: // Return, keypad Enter
                DispatchQueue.main.async { interceptor.onEnter?() }
                return nil
            case 53: // Escape
                DispatchQueue.main.async { interceptor.onEscape?() }
                return nil
            default:
                return Unmanaged.passRetained(cgEvent)
            }
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: selfPtr
        ) else {
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            return false
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        return true
    }

    private func installFallbackMonitors() {
        let handle: (NSEvent) -> Void = { [weak self] event in
            switch event.keyCode {
            case 36, 76: self?.onEnter?()
            case 53: self?.onEscape?()
            default: break
            }
        }
        fallbackGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: handle)
        fallbackLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return event
        }
    }

    deinit {
        stop()
    }
}
