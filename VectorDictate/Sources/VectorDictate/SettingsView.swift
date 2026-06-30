import SwiftUI
import AppKit
import AVFoundation
import Combine
import Foundation

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared

    @State private var apiKey: String = KeychainHelper.loadAPIKey() ?? ""
    @State private var apiKeySaved = false
    @State private var apiKeySaveFailed = false
    @State private var micStatus = PermissionsManager.microphoneStatus()
    @State private var accessibilityTrusted = PasteSimulator.isAccessibilityTrusted()

    private let refreshTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section("Хоткей") {
                HStack {
                    Text("Глобальная комбинация")
                    Spacer()
                    ShortcutRecorderView(combo: Binding(
                        get: { settings.hotkey },
                        set: { newCombo in
                            settings.hotkey = newCombo
                            HotkeyManager.shared.register(combo: newCombo)
                        }
                    ))
                    .frame(width: 160, height: 26)
                }
                Toggle("Автоматически вставлять текст (Cmd+V) после распознавания", isOn: $settings.autoPasteEnabled)
            }

            Section("OpenAI") {
                SecureField("API ключ (sk-…)", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button(apiKeySaved ? "Сохранено ✓" : "Сохранить ключ") {
                        let succeeded = KeychainHelper.save(apiKey: apiKey)
                        apiKeySaved = succeeded
                        apiKeySaveFailed = !succeeded
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { apiKeySaved = false }
                    }
                    .disabled(apiKey.isEmpty)
                    Link("Получить ключ на platform.openai.com", destination: URL(string: "https://platform.openai.com/api-keys")!)
                        .font(.caption)
                }
                if apiKeySaveFailed {
                    Text("Не удалось сохранить ключ в Keychain. Попробуйте ещё раз.")
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Picker("Модель распознавания", selection: $settings.model) {
                    ForEach(TranscriptionModel.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }

                TextField("Язык (код ISO-639-1, например ru, en; пусто = автоопределение)", text: $settings.language)
                    .textFieldStyle(.roundedBorder)
            }

            Section("Автостоп по тишине") {
                VStack(alignment: .leading) {
                    Text("Порог тишины: \(Int(settings.silenceThresholdDb)) dB")
                    Slider(value: $settings.silenceThresholdDb, in: -60...(-10), step: 1)
                }
                VStack(alignment: .leading) {
                    Text("Пауза перед автостопом: \(String(format: "%.1f", settings.silenceDurationSeconds)) с")
                    Slider(value: $settings.silenceDurationSeconds, in: 0.5...5, step: 0.1)
                }
                VStack(alignment: .leading) {
                    Text("Максимальная длительность записи: \(Int(settings.maxRecordingSeconds)) с")
                    Slider(value: $settings.maxRecordingSeconds, in: 15...600, step: 5)
                }
            }

            Section("Разрешения") {
                HStack {
                    Image(systemName: micStatus == .authorized ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(micStatus == .authorized ? .green : .orange)
                    Text("Микрофон")
                    Spacer()
                    Button("Системные настройки") { openSystemSettings(pane: "Privacy_Microphone") }
                }
                HStack {
                    Image(systemName: accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(accessibilityTrusted ? .green : .orange)
                    Text("Universal Access (для автовставки и Enter/Esc)")
                    Spacer()
                    Button("Системные настройки") { openSystemSettings(pane: "Privacy_Accessibility") }
                }
                Text("Без Universal Access диктовка по-прежнему работает: текст копируется в буфер обмена и сохраняется в историю, просто без автоматической вставки.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(refreshTimer) { _ in
            micStatus = PermissionsManager.microphoneStatus()
            accessibilityTrusted = PasteSimulator.isAccessibilityTrusted()
        }
    }

    private func openSystemSettings(pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}

final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private convenience init() {
        let hosting = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "Vector Dictate — Настройки"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        self.init(window: window)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Shortcut recorder control

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var combo: HotkeyCombo

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.currentCombo = combo
        view.onCapture = { newCombo in combo = newCombo }
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.currentCombo = combo
    }
}

final class ShortcutRecorderNSView: NSView {
    var onCapture: ((HotkeyCombo) -> Void)?
    var currentCombo: HotkeyCombo? {
        didSet { needsDisplay = true }
    }

    private var isRecording = false {
        didSet { needsDisplay = true }
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        let modifiers = HotkeyCapture.carbonModifiers(from: event.modifierFlags)
        let newCombo = HotkeyCombo(keyCode: UInt32(event.keyCode), carbonModifiers: modifiers)
        currentCombo = newCombo
        isRecording = false
        onCapture?(newCombo)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    override func draw(_ dirtyRect: NSRect) {
        let background = isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.15) : NSColor.controlBackgroundColor
        background.setFill()
        let path = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        path.fill()
        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()

        let text = isRecording ? "Нажмите комбинацию…" : (currentCombo?.displayString ?? "—")
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.labelColor
        ]
        let size = text.size(withAttributes: attributes)
        let point = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        text.draw(at: point, withAttributes: attributes)
    }
}
