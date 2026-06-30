import Foundation
import Combine
import Carbon.HIToolbox

/// A keyboard shortcut made of a virtual key code plus Carbon modifier flags.
/// Carbon modifier constants (cmdKey, optionKey, controlKey, shiftKey) are used
/// because they are what `RegisterEventHotKey` (the global-hotkey API) expects.
struct HotkeyCombo: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    /// Default shortcut: Option + Space.
    static let defaultCombo = HotkeyCombo(
        keyCode: UInt32(kVK_Space),
        carbonModifiers: UInt32(optionKey)
    )

    var displayString: String {
        var parts = ""
        if carbonModifiers & UInt32(controlKey) != 0 { parts += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { parts += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { parts += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { parts += "⌘" }
        parts += KeyCodeNames.name(for: keyCode)
        return parts
    }
}

enum KeyCodeNames {
    private static let map: [UInt32: String] = [
        UInt32(kVK_Space): "Space",
        UInt32(kVK_Return): "Return",
        UInt32(kVK_Escape): "Escape",
        UInt32(kVK_Tab): "Tab",
        UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
        UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
        UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
        UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2",
        UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8",
        UInt32(kVK_ANSI_9): "9"
    ]

    static func name(for keyCode: UInt32) -> String {
        map[keyCode] ?? "Key(\(keyCode))"
    }
}

enum TranscriptionModel: String, Codable, CaseIterable, Identifiable, Hashable {
    case whisper1 = "whisper-1"
    case gpt4oTranscribe = "gpt-4o-transcribe"
    case gpt4oMiniTranscribe = "gpt-4o-mini-transcribe"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .whisper1: return "Whisper-1 (стабильная)"
        case .gpt4oTranscribe: return "GPT-4o Transcribe"
        case .gpt4oMiniTranscribe: return "GPT-4o Mini Transcribe"
        }
    }
}

struct DictationRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    var text: String
    var durationSeconds: Double
    /// Whether the auto-paste step actually succeeded in posting the
    /// keystroke event (it can still fail to land in a real text field if
    /// the frontmost app refuses paste — the text is preserved either way).
    var pasted: Bool

    init(id: UUID = UUID(), date: Date = Date(), text: String, durationSeconds: Double, pasted: Bool) {
        self.id = id
        self.date = date
        self.text = text
        self.durationSeconds = durationSeconds
        self.pasted = pasted
    }
}

/// User-configurable app settings, persisted to UserDefaults (everything
/// except the API key, which lives in the Keychain).
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Keys {
        static let hotkey = "vd.hotkey"
        static let model = "vd.model"
        static let language = "vd.language"
        static let silenceThresholdDb = "vd.silenceThresholdDb"
        static let silenceDurationSeconds = "vd.silenceDurationSeconds"
        static let autoPasteEnabled = "vd.autoPasteEnabled"
        static let maxRecordingSeconds = "vd.maxRecordingSeconds"
    }

    private let defaults: UserDefaults

    @Published var hotkey: HotkeyCombo {
        didSet { saveHotkey() }
    }
    @Published var model: TranscriptionModel {
        didSet { defaults.set(model.rawValue, forKey: Keys.model) }
    }
    /// ISO-639-1 language hint, empty string = auto-detect.
    @Published var language: String {
        didSet { defaults.set(language, forKey: Keys.language) }
    }
    /// Average power (dBFS) below which audio is considered silence.
    @Published var silenceThresholdDb: Float {
        didSet { defaults.set(silenceThresholdDb, forKey: Keys.silenceThresholdDb) }
    }
    /// How long the signal must stay below the threshold before we
    /// auto-stop the recording.
    @Published var silenceDurationSeconds: Double {
        didSet { defaults.set(silenceDurationSeconds, forKey: Keys.silenceDurationSeconds) }
    }
    @Published var autoPasteEnabled: Bool {
        didSet { defaults.set(autoPasteEnabled, forKey: Keys.autoPasteEnabled) }
    }
    /// Hard safety cap so a stuck recording can't run forever.
    @Published var maxRecordingSeconds: Double {
        didSet { defaults.set(maxRecordingSeconds, forKey: Keys.maxRecordingSeconds) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: Keys.hotkey),
           let decoded = try? JSONDecoder().decode(HotkeyCombo.self, from: data) {
            self.hotkey = decoded
        } else {
            self.hotkey = .defaultCombo
        }

        self.model = TranscriptionModel(rawValue: defaults.string(forKey: Keys.model) ?? "") ?? .whisper1
        self.language = defaults.string(forKey: Keys.language) ?? ""

        let storedThreshold = defaults.object(forKey: Keys.silenceThresholdDb) as? Float
        self.silenceThresholdDb = storedThreshold ?? -35.0

        let storedDuration = defaults.object(forKey: Keys.silenceDurationSeconds) as? Double
        self.silenceDurationSeconds = storedDuration ?? 1.6

        if defaults.object(forKey: Keys.autoPasteEnabled) == nil {
            self.autoPasteEnabled = true
        } else {
            self.autoPasteEnabled = defaults.bool(forKey: Keys.autoPasteEnabled)
        }

        let storedMax = defaults.object(forKey: Keys.maxRecordingSeconds) as? Double
        self.maxRecordingSeconds = storedMax ?? 120.0
    }

    private func saveHotkey() {
        if let data = try? JSONEncoder().encode(hotkey) {
            defaults.set(data, forKey: Keys.hotkey)
        }
    }
}
