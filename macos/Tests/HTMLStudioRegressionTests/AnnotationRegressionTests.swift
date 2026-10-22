import AppKit
import SwiftUI
import Testing
import WebKit
@testable import HTMLStudio

extension DocumentRegressionTests {
    @Test @MainActor
    func annotationsSurviveSavingAndHidingWithoutChangingText() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HTMLStudio-Comments-\(UUID().uuidString)")
        let workspace = DocumentWorkspace(draftStore: DraftStore(supportDirectory: root), historyStore: ChangeLogStore(supportDirectory: root))
        defer { try? FileManager.default.removeItem(at: root) }
        let doc = workspace.activeDocument
        doc.updateHTML("<html><body><p id=target>前文 <strong>重点文字</strong> 后文</p><p id=paragraph>整段文字</p></body></html>")
        let host = NSHostingView(rootView: ContentView(workspace: workspace))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1200, height: 760), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host; window.makeKeyAndOrderFront(nil)
        defer { window.close() }
        host.layoutSubtreeIfNeeded()
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        let web = try #require(descendants(host).compactMap { $0 as? WKWebView }.first)
        for _ in 0..<120 { if doc.designController.isReady { break };try await Task.sleep(nanoseconds: 50_000_000) }
        #expect(doc.designController.isReady)
        _ = try await web.evaluateJavaScript("""
        var range = document.createRange(); range.selectNodeContents(document.querySelector('strong'));
        window.getSelection().removeAllRanges();window.getSelection().addRange(range);
        window.__HTMLStudioEditor.saveSelection();window.__HTMLStudioEditor.prepareComment();
        """)
        let note = "核实 <script> 与 \"引号\" & 第二行"
        let success: Bool = await withCheckedContinuation { continuation in
            doc.designController.addComment(note) { continuation.resume(returning: $0) }
        }
        #expect(success)
        for _ in 0..<80 { if doc.html.contains("data-html-studio-note=\"") { break };try await Task.sleep(nanoseconds: 25_000_000) }
        #expect(doc.html.contains("data-html-studio-note=\""))
        #expect((try await web.evaluateJavaScript("document.querySelector('[data-html-studio-comment]').getAttribute('data-html-studio-comment-index')")) as? String == "1")
        #expect(((try await web.evaluateJavaScript("window.__HTMLStudioEditor.commentsList()[0].index")) as? String) == "1")
        #expect(((try await web.evaluateJavaScript("document.querySelector('#target').textContent")) as? String)?.replacingOccurrences(of: "\u{00a0}", with: " ") == "前文 重点文字 后文")
        doc.designController.execute("undo")
        for _ in 0..<80 { if !doc.html.contains("data-html-studio-note=\"") { break };try await Task.sleep(nanoseconds: 25_000_000) }
        #expect(!doc.html.contains("data-html-studio-note=\""))
        doc.designController.execute("redo")
        for _ in 0..<80 { if doc.html.contains("data-html-studio-note=\"") { break };try await Task.sleep(nanoseconds: 25_000_000) }
        #expect(doc.html.contains("data-html-studio-note=\""))
        let updatedNote = "已编辑并保存的批注"
        let commentID = try #require((try await web.evaluateJavaScript("window.__HTMLStudioEditor.commentsList()[0].id")) as? String)
        let updated: Bool = await withCheckedContinuation { continuation in
            doc.designController.updateComment(commentID, note: updatedNote) { continuation.resume(returning: $0) }
        }
        #expect(updated)
        for _ in 0..<80 { if doc.html.contains(updatedNote) { break };try await Task.sleep(nanoseconds: 25_000_000) }
        #expect(doc.html.contains(updatedNote))
        #expect((try await web.evaluateJavaScript("window.__HTMLStudioEditor.commentsList()[0].note")) as? String == updatedNote)
        #expect((try await web.evaluateJavaScript("document.querySelector('[data-html-studio-comment]').title")) as? String == updatedNote)
        let original = doc.html
        doc.designController.setCommentsVisible(false)
        _ = try await web.evaluateJavaScript("window.__HTMLStudioEditor.snapshot()")
        #expect(doc.html == original)
        #expect((try await web.evaluateJavaScript("document.querySelector('[data-html-studio-comment]').hasAttribute('title')")) as? Bool == false)
        let snapshot = try #require(try await web.evaluateJavaScript("window.__HTMLStudioEditor.snapshot()") as? String)
        #expect(!snapshot.contains("comment-visibility"))
        doc.updateHTML(snapshot)
        let file = root.appendingPathComponent("comments.html");try doc.save(as: file)
        #expect(try String(contentsOf: file).contains("data-html-studio-note=\""))
        doc.designController.loadHTMLImmediately(snapshot, baseURL: nil)
        for _ in 0..<120 { if doc.designController.isReady { break };try await Task.sleep(nanoseconds: 25_000_000) }
        let list = try #require(try await web.evaluateJavaScript("window.__HTMLStudioEditor.commentsList()") as? [[String: String]])
        #expect(list.count == 1);#expect(list.first?["note"] == updatedNote);#expect(list.first?["index"] == "1")
        _ = try await web.evaluateJavaScript("""
        var range = document.createRange();range.setStart(document.querySelector('#paragraph').firstChild,2);range.collapse(true);
        window.getSelection().removeAllRanges();window.getSelection().addRange(range);
        window.__HTMLStudioEditor.saveSelection();window.__HTMLStudioEditor.prepareComment();window.__HTMLStudioEditor.addComment('整段批注');
        """)
        #expect((try await web.evaluateJavaScript("document.querySelector('#paragraph [data-html-studio-comment]').textContent")) as? String == "整段文字")
        #expect((try await web.evaluateJavaScript("window.__HTMLStudioEditor.commentsList().map(item => item.index).join(',')")) as? String == "1,2")
        _ = try await web.evaluateJavaScript("window.__HTMLStudioEditor.removeComment(window.__HTMLStudioEditor.commentsList()[0].id)")
        #expect((try await web.evaluateJavaScript("window.__HTMLStudioEditor.commentsList()[0].index")) as? String == "1")
        _ = try await web.evaluateJavaScript("window.__HTMLStudioEditor.removeComment(window.__HTMLStudioEditor.commentsList()[0].id)")
        #expect((try await web.evaluateJavaScript("document.querySelector('#paragraph').textContent")) as? String == "整段文字")
    }

    @Test @MainActor
    func startupNeverLoadsDraftUntilExplicitRecovery() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HTMLStudio-Startup-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let drafts = DraftStore(supportDirectory: root)
        drafts.save(identifier: UUID(), html: "<p>上一稿</p>", filePath: nil, isDirty: true)
        let workspace = DocumentWorkspace(draftStore: drafts, historyStore: ChangeLogStore(supportDirectory: root))
        #expect(workspace.documents.count == 1)
        #expect(workspace.activeDocument.html == EditorDocument.starterHTML)
        #expect(workspace.hasRecoverableDraft)
        workspace.activeDocument.updateHTML("<p>当前编辑</p>")
        workspace.restoreLatestDraft()
        #expect(workspace.documents.count == 2)
        #expect(workspace.activeDocument.html == "<p>上一稿</p>")
        #expect(workspace.documents.contains { $0.html == "<p>当前编辑</p>" })
    }
}
