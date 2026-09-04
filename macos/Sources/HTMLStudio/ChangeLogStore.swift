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

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let supportDirectory = fileManager.urls(
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

    func append(_ entry: ChangeLogEntry, for key: String) -> [ChangeLogEntry] {
        var values = entries(for: key)
        if let last = values.last,
           last.html == entry.html,
           last.action == entry.action {
            return values
        }
        values.append(entry)
        if values.count > maximumEntries {
            values.removeFirst(values.count - maximumEntries)
        }
        persist(values, for: key)
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
}
