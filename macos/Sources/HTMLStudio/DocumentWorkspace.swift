import Foundation

@MainActor
final class DocumentWorkspace: ObservableObject {
    @Published private(set) var documents: [EditorDocument]
    @Published var selectedDocumentID: UUID

    init() {
        let initialDocument = EditorDocument(restoreDraft: true)
        documents = [initialDocument]
        selectedDocumentID = initialDocument.id
    }

    var activeDocument: EditorDocument {
        documents.first { $0.id == selectedDocumentID } ?? documents[0]
    }

    @discardableResult
    func newDocument() -> EditorDocument {
        let document = EditorDocument()
        documents.append(document)
        selectedDocumentID = document.id
        return document
    }

    @discardableResult
    func open(_ url: URL) throws -> EditorDocument {
        if let existing = documents.first(where: {
            $0.fileURL?.standardizedFileURL == url.standardizedFileURL
        }) {
            selectedDocumentID = existing.id
            return existing
        }

        let document = EditorDocument()
        try document.open(url)
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
            let replacement = EditorDocument()
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
