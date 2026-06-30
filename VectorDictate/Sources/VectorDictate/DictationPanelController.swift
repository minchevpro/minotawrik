import Cocoa
import SwiftUI

/// Owns the floating dictation panel and orchestrates the whole
/// record → transcribe → clipboard → paste → history pipeline.
final class DictationPanelController: NSObject {
    static let shared = DictationPanelController()

    private var panel: NSPanel!
    private let viewModel = DictationViewModel()
    private let recorder = AudioRecorder()
    private let transcriptionService = OpenAITranscriptionService()
    private let keyInterceptor = KeyInterceptor()

    private var elapsedTimer: Timer?
    private var recordingStartDate: Date?
    private var lastRecordingDuration: TimeInterval = 0
    private var hideWorkItem: DispatchWorkItem?
    private var currentLevel: Float = 0

    private override init() {
        super.init()
        setupPanel()
        recorder.delegate = self
        viewModel.onStopRequested = { [weak self] in self?.stopAndProcess() }
        viewModel.onCancelRequested = { [weak self] in self?.cancel() }
        keyInterceptor.onEnter = { [weak self] in self?.stopAndProcess() }
        keyInterceptor.onEscape = { [weak self] in self?.cancel() }
    }

    /// Called by the global hotkey. Starts a new dictation, or — if one is
    /// already in progress — stops it and sends it for transcription (same
    /// action as the Stop button).
    func toggleFromHotkey() {
        switch viewModel.state {
        case .idle, .error:
            start()
        case .recording:
            stopAndProcess()
        case .transcribing:
            break // a transcription is already in flight; ignore extra presses
        }
    }

    // MARK: - Lifecycle

    private func start() {
        hideWorkItem?.cancel()
        currentLevel = 0
        viewModel.state = .recording(level: 0, elapsed: 0)
        recordingStartDate = Date()
        showPanel()
        keyInterceptor.start()
        startElapsedTimer()
        recorder.requestPermissionAndStart()
    }

    private func stopAndProcess() {
        guard case .recording = viewModel.state else { return }
        recorder.stop()
    }

    private func cancel() {
        recorder.cancel()
        keyInterceptor.stop()
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        viewModel.state = .idle
        hidePanel()
    }

    private func startElapsedTimer() {
        elapsedTimer?.invalidate()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let start = self.recordingStartDate else { return }
            if case .recording = self.viewModel.state {
                self.viewModel.state = .recording(level: self.currentLevel, elapsed: Date().timeIntervalSince(start))
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        elapsedTimer = timer
    }

    private func processRecording(fileURL: URL) {
        keyInterceptor.stop()
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        viewModel.state = .transcribing

        let settings = AppSettings.shared
        let model = settings.model
        let language = settings.language

        Task {
            do {
                let text = try await transcriptionService.transcribe(fileURL: fileURL, model: model, language: language)
                try? FileManager.default.removeItem(at: fileURL)

                await MainActor.run {
                    self.finish(withText: text)
                }
            } catch {
                try? FileManager.default.removeItem(at: fileURL)
                await MainActor.run {
                    self.showError((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
                }
            }
        }
    }

    private func finish(withText text: String) {
        guard !text.isEmpty else {
            showError("Распознанный текст пуст.")
            return
        }

        PasteSimulator.copyToClipboard(text)
        let didPostPaste = AppSettings.shared.autoPasteEnabled ? PasteSimulator.paste() : false

        HistoryStore.shared.add(DictationRecord(text: text, durationSeconds: lastRecordingDuration, pasted: didPostPaste))

        viewModel.state = .idle
        hidePanel()
    }

    private func showError(_ message: String) {
        viewModel.state = .error(message)
        hidePanel(after: 2.5)
    }

    // MARK: - Panel construction

    private func setupPanel() {
        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 76),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.hidesOnDeactivate = false
        newPanel.isMovableByWindowBackground = true
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true
        newPanel.isReleasedWhenClosed = false

        let hosting = NSHostingView(rootView: DictationPanelView(viewModel: viewModel))
        hosting.frame = NSRect(x: 0, y: 0, width: 320, height: 76)
        newPanel.contentView = hosting

        self.panel = newPanel
    }

    private func showPanel() {
        positionPanel()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }
    }

    private func hidePanel(after delay: TimeInterval = 0) {
        hideWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.15
                self.panel.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                self?.panel.orderOut(nil)
                if case .error = self?.viewModel.state {
                    self?.viewModel.state = .idle
                }
            })
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func positionPanel() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let size = panel.frame.size
        let x = screenFrame.midX - size.width / 2
        let y = screenFrame.maxY - size.height - 80
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

extension DictationPanelController: AudioRecorderDelegate {
    func audioRecorder(_ recorder: AudioRecorder, didUpdateLevel normalizedLevel: Float) {
        currentLevel = normalizedLevel
    }

    func audioRecorder(_ recorder: AudioRecorder, didFinishRecording fileURL: URL, duration: TimeInterval) {
        lastRecordingDuration = duration
        processRecording(fileURL: fileURL)
    }

    func audioRecorder(_ recorder: AudioRecorder, didFailWithError error: Error) {
        keyInterceptor.stop()
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        showError((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
    }
}
