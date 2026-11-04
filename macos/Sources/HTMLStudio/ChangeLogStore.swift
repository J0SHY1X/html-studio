import CryptoKit
import Foundation

struct ChangeLogEntry: Codable, Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let source: String
    let action: String
    let summary: String
    let filePath: String?
    let html: String
}

final class ChangeLogStore {
    static let shared = ChangeLogStore()

    private let fileManager: FileManager
    private let historyDirectory: URL
    private let maximumEntries = 120
    private let maximumApproximateCharacters = 18_000_000
    private let persistenceQueue = DispatchQueue(
        label: "HTMLStudio.ChangeLogPersistence",
        qos: .utility
    )
    private let pendingLock = NSLock()
    private var writeGenerations: [String: Int] = [:]

    init(fileManager: FileManager = .default, supportDirectory: URL? = nil) {
        self.fileManager = fileManager
        let supportDirectory = supportDirectory ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        historyDirectory = supportDirectory
            .appendingPathComponent("HTMLStudio", isDirectory: true)
            .appendingPathComponent("History", isDirectory: true)
    }

    func key(for fileURL: URL?, fallback: UUID) -> String {
        guard let fileURL else { return "untitled-\(fallback.uuidString.lowercased())" }
        let normalizedPath = fileURL.standardizedFileURL.path
        let digest = SHA256.hash(data: Data(normalizedPath.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func entries(for key: String) -> [ChangeLogEntry] {
        guard
            let data = try? Data(contentsOf: url(for: key)),
            let entries = try? decoder.decode([ChangeLogEntry].self, from: data)
        else {
            return []
        }
        return entries.sorted { $0.timestamp < $1.timestamp }
    }

    func append(
        _ entry: ChangeLogEntry,
        for key: String,
        existing: [ChangeLogEntry]? = nil
    ) -> [ChangeLogEntry] {
        var values = existing ?? entries(for: key)
        if let last = values.last,
           last.html == entry.html,
           last.action == entry.action {
            return values
        }
        values.append(entry)
        let documentSize = max(1, entry.html.utf8.count)
        let sizeAwareLimit = max(
            8,
            min(maximumEntries, maximumApproximateCharacters / documentSize)
        )
        if values.count > sizeAwareLimit {
            values.removeFirst(values.count - sizeAwareLimit)
        }
        persistAsync(values, for: key)
        return values
    }

    func migrate(from oldKey: String, to newKey: String) -> [ChangeLogEntry] {
        guard oldKey != newKey else { return entries(for: newKey) }
        let combined = (entries(for: newKey) + entries(for: oldKey))
            .sorted { $0.timestamp < $1.timestamp }
        let trimmed = Array(combined.suffix(maximumEntries))
        persist(trimmed, for: newKey)
        try? fileManager.removeItem(at: url(for: oldKey))
        return trimmed
    }

    func export(_ entries: [ChangeLogEntry], to url: URL) throws {
        let data = try encoder.encode(entries)
        try data.write(to: url, options: .atomic)
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func url(for key: String) -> URL {
        historyDirectory.appendingPathComponent("\(key).json")
    }

    private func persist(_ entries: [ChangeLogEntry], for key: String) {
        do {
            try fileManager.createDirectory(
                at: historyDirectory,
                withIntermediateDirectories: true
            )
            try encoder.encode(entries).write(to: url(for: key), options: .atomic)
        } catch {
            // Logging must never interrupt the editing workflow.
        }
    }

    private func persistAsync(_ entries: [ChangeLogEntry], for key: String) {
        pendingLock.lock()
        let generation = (writeGenerations[key] ?? 0) + 1
        writeGenerations[key] = generation
        pendingLock.unlock()
        persistenceQueue.async { [weak self] in
            guard let self else { return }
            self.pendingLock.lock()
            let isLatest = self.writeGenerations[key] == generation
            self.pendingLock.unlock()
            guard isLatest else { return }
            self.persist(entries, for: key)
        }
    }
}
