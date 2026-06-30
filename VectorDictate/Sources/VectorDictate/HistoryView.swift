import SwiftUI
import AppKit
import Foundation

struct HistoryView: View {
    @ObservedObject var store = HistoryStore.shared
    @State private var searchText = ""

    private var filtered: [DictationRecord] {
        guard !searchText.isEmpty else { return store.records }
        return store.records.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Поиск по истории…", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                Button("Очистить всё", role: .destructive) {
                    store.clearAll()
                }
                .disabled(store.records.isEmpty)
            }
            .padding(12)

            Divider()

            if filtered.isEmpty {
                Spacer()
                Text(store.records.isEmpty ? "История пока пуста.\nПродиктуйте что-нибудь — нажмите ваш хоткей." : "Ничего не найдено.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding()
                Spacer()
            } else {
                List(filtered) { record in
                    HistoryRowView(record: record, onCopy: {
                        PasteSimulator.copyToClipboard(record.text)
                    }, onPaste: {
                        PasteSimulator.copyToClipboard(record.text)
                        _ = PasteSimulator.paste()
                    }, onDelete: {
                        store.delete(id: record.id)
                    })
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 460, minHeight: 420)
    }
}

private struct HistoryRowView: View {
    let record: DictationRecord
    let onCopy: () -> Void
    let onPaste: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(record.text)
                .font(.system(size: 13))
                .lineLimit(4)

            HStack {
                Text(record.date, style: .date) + Text(" · ") + Text(record.date, style: .time)
                Text("· \(Int(record.durationSeconds))с")
                if !record.pasted {
                    Text("· не вставлено автоматически")
                        .foregroundColor(.orange)
                }
                Spacer()
                Button("Копировать", action: onCopy)
                    .buttonStyle(.borderless)
                Button("Вставить", action: onPaste)
                    .buttonStyle(.borderless)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

final class HistoryWindowController: NSWindowController {
    static let shared = HistoryWindowController()

    private convenience init() {
        let hosting = NSHostingController(rootView: HistoryView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "Vector Dictate — История"
        window.setContentSize(NSSize(width: 480, height: 460))
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.center()
        self.init(window: window)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
