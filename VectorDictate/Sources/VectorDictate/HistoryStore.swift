import Foundation
import Combine

/// Persists dictation history as JSON in Application Support. Kept
/// deliberately simple (no Core Data) since the data model is tiny and
/// users may want to grep/back up the raw file.
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var records: [DictationRecord] = []

    private let fileURL: URL
    private let ioQueue = DispatchQueue(label: "com.vectordictate.history-io")

    init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let dir = appSupport.appendingPathComponent("VectorDictate", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("history.json")
        load()
    }

    func add(_ record: DictationRecord) {
        records.insert(record, at: 0)
        persist()
    }

    func delete(id: UUID) {
        records.removeAll { $0.id == id }
        persist()
    }

    func clearAll() {
        records.removeAll()
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([DictationRecord].self, from: data) {
            records = decoded
        }
    }

    private func persist() {
        let snapshot = records
        let url = fileURL
        ioQueue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }
}
