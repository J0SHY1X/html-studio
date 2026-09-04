import Foundation

struct DraftSnapshot: Codable {
    let identifier: UUID?
    let html: String
    let filePath: String?
    let isDirty: Bool
    let savedAt: Date
}

final class DraftStore {
    static let shared = DraftStore()

    private let fileManager: FileManager
    private let supportDirectory: URL
    private let legacyDraftURL: URL
    private let draftsDirectory: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let supportDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        self.supportDirectory = supportDirectory
            .appendingPathComponent("HTMLStudio", isDirectory: true)
        legacyDraftURL = self.supportDirectory
            .appendingPathComponent("Autosave.json")
        draftsDirectory = self.supportDirectory
            .appendingPathComponent("Drafts", isDirectory: true)
    }

    func save(
        identifier: UUID,
        html: String,
        filePath: String?,
        isDirty: Bool
    ) {
        guard isDirty else {
            clear(identifier: identifier)
            return
        }

        do {
            try fileManager.createDirectory(
                at: draftsDirectory,
                withIntermediateDirectories: true
            )
            let snapshot = DraftSnapshot(
                identifier: identifier,
                html: html,
                filePath: filePath,
                isDirty: isDirty,
                savedAt: Date()
            )
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: draftURL(for: identifier), options: .atomic)
        } catch {
            // Draft persistence must never interrupt editing.
        }
    }

    func restoreLatest() -> DraftSnapshot? {
        var candidates: [DraftSnapshot] = []

        if let data = try? Data(contentsOf: legacyDraftURL),
           let snapshot = try? JSONDecoder().decode(DraftSnapshot.self, from: data) {
            candidates.append(snapshot)
        }

        if let urls = try? fileManager.contentsOfDirectory(
            at: draftsDirectory,
            includingPropertiesForKeys: nil
        ) {
            for url in urls where url.pathExtension == "json" {
                guard
                    let data = try? Data(contentsOf: url),
                    let snapshot = try? JSONDecoder().decode(DraftSnapshot.self, from: data)
                else {
                    continue
                }
                candidates.append(snapshot)
            }
        }

        return candidates
            .filter(\.isDirty)
            .max { $0.savedAt < $1.savedAt }
    }

    func clear(identifier: UUID) {
        try? fileManager.removeItem(at: draftURL(for: identifier))
        if let legacy = restoreLegacy(), legacy.identifier == nil {
            try? fileManager.removeItem(at: legacyDraftURL)
        }
    }

    private func draftURL(for identifier: UUID) -> URL {
        draftsDirectory.appendingPathComponent("\(identifier.uuidString).json")
    }

    private func restoreLegacy() -> DraftSnapshot? {
        guard
            let data = try? Data(contentsOf: legacyDraftURL),
            let snapshot = try? JSONDecoder().decode(DraftSnapshot.self, from: data)
        else {
            return nil
        }
        return snapshot
    }
}
