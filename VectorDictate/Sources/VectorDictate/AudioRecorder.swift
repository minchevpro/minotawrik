import Foundation
import AVFoundation

enum RecorderError: Error, LocalizedError {
    case microphonePermissionDenied
    case failedToStart

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Доступ к микрофону не разрешён. Откройте Системные настройки → Конфиденциальность → Микрофон."
        case .failedToStart:
            return "Не удалось начать запись звука."
        }
    }
}

protocol AudioRecorderDelegate: AnyObject {
    /// Fired continuously while recording so the UI can animate a level meter.
    func audioRecorder(_ recorder: AudioRecorder, didUpdateLevel normalizedLevel: Float)
    /// Fired once recording stops, whether by user action, silence, or the
    /// max-duration safety cap.
    func audioRecorder(_ recorder: AudioRecorder, didFinishRecording fileURL: URL, duration: TimeInterval)
    func audioRecorder(_ recorder: AudioRecorder, didFailWithError error: Error)
}

/// Records microphone audio to a temporary AAC (.m4a) file, suitable for
/// direct upload to OpenAI's transcription endpoint. Also performs simple
/// silence detection so a recording can auto-stop after a pause.
final class AudioRecorder: NSObject {
    weak var delegate: AudioRecorderDelegate?

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var startDate: Date?
    private var lastLoudDate: Date?

    private(set) var isRecording = false

    func requestPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.start()
                    } else {
                        self.delegate?.audioRecorder(self, didFailWithError: RecorderError.microphonePermissionDenied)
                    }
                }
            }
        case .denied, .restricted:
            delegate?.audioRecorder(self, didFailWithError: RecorderError.microphonePermissionDenied)
        @unknown default:
            delegate?.audioRecorder(self, didFailWithError: RecorderError.microphonePermissionDenied)
        }
    }

    private func start() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vectordictate-\(UUID().uuidString)")
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.isMeteringEnabled = true
            newRecorder.delegate = self
            guard newRecorder.record() else {
                delegate?.audioRecorder(self, didFailWithError: RecorderError.failedToStart)
                return
            }
            recorder = newRecorder
            isRecording = true
            startDate = Date()
            lastLoudDate = Date()
            startMetering()
        } catch {
            delegate?.audioRecorder(self, didFailWithError: error)
        }
    }

    func stop() {
        guard isRecording, let recorder else { return }
        meterTimer?.invalidate()
        meterTimer = nil
        isRecording = false

        let duration = startDate.map { Date().timeIntervalSince($0) } ?? 0
        let url = recorder.url
        recorder.stop()
        self.recorder = nil

        delegate?.audioRecorder(self, didFinishRecording: url, duration: duration)
    }

    func cancel() {
        meterTimer?.invalidate()
        meterTimer = nil
        isRecording = false
        if let recorder {
            recorder.stop()
            try? FileManager.default.removeItem(at: recorder.url)
        }
        recorder = nil
    }

    private func startMetering() {
        meterTimer?.invalidate()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        meterTimer = timer
    }

    private func tick() {
        guard let recorder, isRecording else { return }
        recorder.updateMeters()

        let powerDb = recorder.averagePower(forChannel: 0)
        let normalized = AudioRecorder.normalizedLevel(fromDb: powerDb)
        delegate?.audioRecorder(self, didUpdateLevel: normalized)

        let settings = AppSettings.shared
        if powerDb > settings.silenceThresholdDb {
            lastLoudDate = Date()
        } else if let lastLoudDate, Date().timeIntervalSince(lastLoudDate) >= settings.silenceDurationSeconds {
            stop()
            return
        }

        if let startDate, Date().timeIntervalSince(startDate) >= settings.maxRecordingSeconds {
            stop()
        }
    }

    /// Maps a dBFS value (roughly -60...0) to a 0...1 range for UI meters.
    private static func normalizedLevel(fromDb db: Float) -> Float {
        let minDb: Float = -60
        guard db.isFinite else { return 0 }
        let clamped = max(minDb, min(0, db))
        return (clamped - minDb) / -minDb
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error {
            delegate?.audioRecorder(self, didFailWithError: error)
        }
    }
}
