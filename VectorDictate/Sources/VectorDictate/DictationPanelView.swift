import SwiftUI
import Combine
import Foundation

enum DictationState: Equatable {
    case idle
    case recording(level: Float, elapsed: TimeInterval)
    case transcribing
    case error(String)
}

final class DictationViewModel: ObservableObject {
    @Published var state: DictationState = .idle
    var onStopRequested: (() -> Void)?
    var onCancelRequested: (() -> Void)?
}

struct DictationPanelView: View {
    @ObservedObject var viewModel: DictationViewModel

    var body: some View {
        HStack(spacing: 14) {
            iconView
            VStack(alignment: .leading, spacing: 4) {
                statusText
                if case .recording(let level, _) = viewModel.state {
                    LevelMeterView(level: level)
                        .frame(height: 18)
                }
            }
            Spacer(minLength: 8)
            if case .recording = viewModel.state {
                Button(action: { viewModel.onStopRequested?() }) {
                    Text("Stop")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 320, height: 76)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        )
    }

    @ViewBuilder
    private var iconView: some View {
        ZStack {
            Circle()
                .fill(iconColor.opacity(0.18))
                .frame(width: 40, height: 40)
            Image(systemName: iconSymbol)
                .foregroundColor(iconColor)
                .font(.system(size: 18, weight: .medium))
        }
    }

    private var iconSymbol: String {
        switch viewModel.state {
        case .idle: return "mic"
        case .recording: return "mic.fill"
        case .transcribing: return "waveform"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch viewModel.state {
        case .idle: return .secondary
        case .recording: return .red
        case .transcribing: return .blue
        case .error: return .orange
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch viewModel.state {
        case .idle:
            Text("Vector Dictate").font(.system(size: 13, weight: .semibold))
        case .recording(_, let elapsed):
            Text("Запись… \(formatted(elapsed))")
                .font(.system(size: 13, weight: .semibold))
            Text(hintText)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(2)
        case .transcribing:
            Text("Распознавание текста…")
                .font(.system(size: 13, weight: .semibold))
        case .error(let message):
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.orange)
                .lineLimit(2)
        }
    }

    private var hintText: String {
        guard PasteSimulator.isAccessibilityTrusted() else {
            return "Enter/Esc сейчас не блокируются (нет доступа Accessibility) · используйте Stop или хоткей"
        }
        return "Enter — отправить · Esc — отмена · хоткей — стоп"
    }

    private func formatted(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Tiny animated bar-style level meter driven by the recorder's normalized
/// (0...1) audio level.
struct LevelMeterView: View {
    let level: Float
    private let barCount = 24

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(barColor(for: index))
                        .frame(width: max(1, geo.size.width / CGFloat(barCount) - 2))
                }
            }
            .frame(height: geo.size.height, alignment: .center)
        }
    }

    private func barColor(for index: Int) -> Color {
        let threshold = Float(index) / Float(barCount)
        let active = level > threshold
        return active ? Color.red.opacity(0.8) : Color.secondary.opacity(0.2)
    }
}
