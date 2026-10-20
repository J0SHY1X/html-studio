import Foundation

@MainActor
final class DocumentWorkspace: ObservableObject {
    @Published private(set) var documents: [EditorDocument]
    @Published var selectedDocumentID: UUID
    private var startupDocumentID: UUID?
    private var startupHTML: String
    private let draftStore: DraftStore
    private let historyStore: ChangeLogStore

    init(draftStore: DraftStore = .shared, historyStore: ChangeLogStore = .shared) {
        self.draftStore = draftStore
        self.historyStore = historyStore
        let initialDocument = EditorDocument(draftStore: draftStore, historyStore: historyStore)
        documents = [initialDocument]
        selectedDocumentID = initialDocument.id
        startupDocumentID = initialDocument.id
        startupHTML = initialDocument.html
    }

    var hasRecoverableDraft: Bool {
        guard let snapshot = draftStore.restoreLatest() else { return false }
        return !documents.contains { $0.isDirty && $0.html == snapshot.html }
    }

    func restoreLatestDraft() {
        guard hasRecoverableDraft else { return }
        let restored = EditorDocument(draftStore: draftStore, historyStore: historyStore, restoreDraft: true)
        if documents.count == 1 && activeDocument.id == startupDocumentID && !activeDocument.isDirty {
            documents = [restored]
        } else {
            documents.append(restored)
        }
        startupDocumentID = nil
        selectedDocumentID = restored.id
    }

    var activeDocument: EditorDocument {
        documents.first { $0.id == selectedDocumentID } ?? documents[0]
    }

    @discardableResult
    func newDocument() -> EditorDocument {
        startupDocumentID = nil
        let document = EditorDocument(draftStore: draftStore, historyStore: historyStore)
        documents.append(document)
        selectedDocumentID = document.id
        return document
    }

    @discardableResult
    func open(_ url: URL, fromExternalRequest: Bool = false) throws -> EditorDocument {
        let replaceStartup = documents.count == 1 && documents[0].id == startupDocumentID &&
            documents[0].html == startupHTML && (fromExternalRequest || !documents[0].isDirty)
        if let existing = documents.first(where: {
            ($0.fileURL ?? $0.importedSourceURL)?.standardizedFileURL == url.standardizedFileURL
        }), !replaceStartup {
            selectedDocumentID = existing.id
            return existing
        }

        let document = EditorDocument(draftStore: draftStore, historyStore: historyStore)
        try document.open(url)
        // Drop only the untouched startup placeholder/restored tab. Its draft stays on disk.
        if replaceStartup {
            documents.removeAll()
        }
        startupDocumentID = nil
        documents.append(document)
        selectedDocumentID = document.id
        return document
    }

    func select(_ document: EditorDocument) {
        selectedDocumentID = document.id
    }

    func close(_ document: EditorDocument) {
        document.persistDraftNow()
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else {
            return
        }
        let wasSelected = selectedDocumentID == document.id
        documents.remove(at: index)

        if documents.isEmpty {
            let replacement = EditorDocument(draftStore: draftStore, historyStore: historyStore)
            documents = [replacement]
            selectedDocumentID = replacement.id
        } else if wasSelected {
            selectedDocumentID = documents[min(index, documents.count - 1)].id
        }
    }

    func persistAllDrafts() {
        documents.forEach { $0.persistDraftNow() }
    }
}
