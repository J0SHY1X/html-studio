import AppKit
import HTMLStudioCore
import Testing
import SwiftUI
import WebKit
@testable import HTMLStudio

@Suite(.serialized)
struct DocumentRegressionTests {
    private final class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }

    @MainActor
    private func withWorkspace(_ body: (DocumentWorkspace, DraftStore, URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HTMLStudio-Regression-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let drafts = DraftStore(supportDirectory: root)
        let history = ChangeLogStore(supportDirectory: root)
        try body(DocumentWorkspace(draftStore: drafts, historyStore: history), drafts, root)
    }

    @Test
    func testNewDocumentIsBlank() async throws {
        try await MainActor.run {
            try withWorkspace { workspace, _, _ in
                let document = workspace.newDocument()
                let body = document.html.components(separatedBy: "<body>")[1].components(separatedBy: "</body>")[0]
                #expect(body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                #expect(document.fileURL == nil)
                #expect(!(document.isDirty))
            }
        }
    }

    @Test
    func testExplicitFileOpenDoesNotRestoreOldDraft() async throws {
        try await MainActor.run {
            try withWorkspace { workspace, drafts, root in
                drafts.save(identifier: UUID(), html: "<p>旧草稿</p>", filePath: root.appendingPathComponent("old.html").path, isDirty: true)
                let target = root.appendingPathComponent("selected.html")
                try "<h1>选中文件</h1>".write(to: target, atomically: true, encoding: .utf8)
                let opened = try workspace.open(target, fromExternalRequest: true)
                #expect(workspace.documents.count == 1)
                #expect(workspace.activeDocument === opened)
                #expect(opened.html == "<h1>选中文件</h1>")
                #expect(drafts.restoreLatest()?.html == "<p>旧草稿</p>")
                #expect(try workspace.open(target) === opened)
            }
        }
    }

    @Test
    func testNormalStartupKeepsDraftClosedWhenFileArrives() async throws {
        try await MainActor.run {
            try withWorkspace { workspace, drafts, root in
                drafts.save(identifier: UUID(), html: "<p>旧草稿</p>", filePath: nil, isDirty: true)
                #expect(workspace.activeDocument.html == EditorDocument.starterHTML)
                let target = root.appendingPathComponent("selected.html")
                try "<h1>指定文件</h1>".write(to: target, atomically: true, encoding: .utf8)
                try workspace.open(target, fromExternalRequest: true)
                #expect(workspace.documents.count == 1)
                #expect(drafts.restoreLatest()?.html == "<p>旧草稿</p>")
            }
        }
    }

    @Test
    func testOpeningFilePreservesEditedStartupDocument() async throws {
        try await MainActor.run {
            try withWorkspace { workspace, _, root in
                let edited = workspace.activeDocument
                edited.updateHTML("<p>正在编辑</p>")
                let target = root.appendingPathComponent("selected.html")
                try "<h1>指定文件</h1>".write(to: target, atomically: true, encoding: .utf8)
                try workspace.open(target)
                #expect(workspace.documents.count == 2)
                #expect(workspace.documents.contains { $0 === edited })
            }
        }
    }

    @Test
    func testExternalOpenReadsSelectedFileInsteadOfItsStartupDraft() async throws {
        try await MainActor.run {
            try withWorkspace { workspace, drafts, root in
                let target = root.appendingPathComponent("selected.html")
                try "<h1>磁盘文件</h1>".write(to: target, atomically: true, encoding: .utf8)
                drafts.save(identifier: UUID(), html: "<p>此文件的旧草稿</p>", filePath: target.path, isDirty: true)
                let opened = try workspace.open(target, fromExternalRequest: true)
                #expect(workspace.documents.count == 1)
                #expect(opened.html == "<h1>磁盘文件</h1>")
                #expect(drafts.restoreLatest()?.html == "<p>此文件的旧草稿</p>")
            }
        }
    }

    @Test
    func testMarkdownImportAndHTMLSavePreserveTablesAndFilename() async throws {
        try await MainActor.run {
            try withWorkspace { workspace, _, root in
                let source = root.appendingPathComponent("表格.md")
                try "| 名称 | 数量 |\n| :--- | ---: |\n| 测试 | 31 |".write(to: source, atomically: true, encoding: .utf8)
                let document = try workspace.open(source)
                #expect(document.fileURL == nil)
                #expect(document.displayName == "表格.html")
                #expect(document.baseURL?.path == root.path)
                #expect(document.isDirty)
                #expect(try workspace.open(source) === document)
                let destination = root.appendingPathComponent(document.displayName)
                try document.save(as: destination)
                let saved = try String(contentsOf: destination, encoding: .utf8)
                #expect(saved.contains("<table>"))
                #expect(saved.contains("border-collapse: collapse"))
                #expect(saved.contains("text-align: right"))
                #expect(!(document.isDirty))
                #expect(document.fileURL == destination)
            }
        }
    }

    @Test
    func testLegacyDraftDecodesWithoutImportMetadata() throws {
        let data = Data(#"{"html":"<p>旧草稿</p>","isDirty":true,"savedAt":0}"#.utf8)
        let snapshot = try JSONDecoder().decode(DraftSnapshot.self, from: data)
        #expect(snapshot.importedSourcePath == nil)
        #expect(snapshot.html == "<p>旧草稿</p>")
    }

    @Test
    func testThirtyOneHeadingsIncludeBlankAndNestedTitles() {
        let html = (1...31).map { index in
            index == 2 ? "<h2></h2>" : "<h2><span>目录 \(index)</span></h2>"
        }.joined()
        let items = OutlineParser.items(from: html)
        #expect(items.count == 31)
        #expect(items[1].title == "未命名标题")
        #expect(items[30].title == "目录 31")
    }

    @Test
    func testFallbackMarkdownTablesAndCode() {
        let markdown = """
        | 名称 | 数量 | 备注 |
        | :--- | ---: | :---: |
        | **项目 A** | 12 | `a|b` |
        | 转义 \\| 竖线 | 3 | <script> |
        | 短行 | 1 |

        ## 表格之后

        ```md
        | 代码 | 示例 |
        | --- | --- |
        ```
        """
        let html = FallbackHTMLConverter.markdownToHTML(markdown)
        #expect(html.components(separatedBy: "<table>").count - 1 == 1)
        #expect(html.components(separatedBy: "<td style=").count - 1 == 9)
        #expect(html.contains("<code>a|b</code>"))
        #expect(html.contains("转义 | 竖线"))
        #expect(html.contains("&lt;script&gt;"))
        #expect(html.contains("text-align: right"))
        #expect(html.contains("text-align: center"))
        #expect(html.contains("th, td { border:"))
        #expect(html.contains("<h2>表格之后</h2>"))
        #expect(FallbackHTMLConverter.markdownToHTML("A | B\r\n--- | ---\r\n1 | 2").contains("<table>"))
        #expect(!(FallbackHTMLConverter.markdownToHTML("A | B\n--- | invalid\n1 | 2").contains("<table>")))
    }

    @Test
    @MainActor
    func testContextMenuUsesTheViewsCoordinateSystem() {
        let normal = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let flipped = FlippedView(frame: normal.frame)
        #expect(HTMLPreview.contextMenuPoint(x: 60, y: 75, in: normal) == NSPoint(x: 60, y: 325))
        #expect(HTMLPreview.contextMenuPoint(x: 60, y: 75, in: flipped) == NSPoint(x: 60, y: 75))
    }

    @Test
    @MainActor
    func testNativeWindowLayoutAndHeadingNavigation() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HTMLStudio-UI-\(UUID().uuidString)")
        let workspace = DocumentWorkspace(draftStore: DraftStore(supportDirectory: root), historyStore: ChangeLogStore(supportDirectory: root))
        defer { try? FileManager.default.removeItem(at: root) }
        workspace.activeDocument.updateHTML("<html><body>" + (1...31).map {
            "<h2>目录 \($0)</h2><p>\(String(repeating: "测试正文。", count: 120))</p>"
        }.joined() + "</body></html>")
        let host = NSHostingView(rootView: ContentView(workspace: workspace))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1480, height: 900), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        defer { window.close() }
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        func checkLayout(_ size: NSSize) {
            window.setContentSize(size)
            host.layoutSubtreeIfNeeded()
            let splits = descendants(host).compactMap { $0 as? NSSplitView }
            #expect(!splits.isEmpty)
            if let split = splits.max(by: { $0.bounds.height < $1.bounds.height }) {
                let rect = split.convert(split.bounds, to: host)
                #expect(rect.height > size.height - 150)
                let bottom = host.isFlipped ? size.height - rect.maxY : rect.minY
                #expect(bottom >= 23 && bottom <= 27)
            }
        }
        checkLayout(NSSize(width: 1480, height: 900))
        let webView = try #require(descendants(host).compactMap { $0 as? WKWebView }.first)
        for _ in 0..<60 {
            if (try? await webView.evaluateJavaScript("window.__HTMLStudioEditor != null")) as? Bool == true { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect((try await webView.evaluateJavaScript("document.querySelectorAll('h2').length")) as? Int == 31)
        workspace.activeDocument.designController.scrollToHeading(at: 30)
        var scrollY = 0.0
        for _ in 0..<40 {
            scrollY = (try await webView.evaluateJavaScript("window.scrollY")) as? Double ?? 0
            if scrollY > 1000 { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(scrollY > 1000)
        checkLayout(NSSize(width: 1000, height: 640))
        let outlineScroll = try #require(descendants(host).compactMap { $0 as? NSScrollView }.first {
            $0.bounds.width < 280 && $0.bounds.height > 100
        })
        let outlineContent = try #require(outlineScroll.documentView)
        #expect(outlineContent.bounds.height > outlineScroll.contentView.bounds.height)
        let lastItemY = outlineContent.isFlipped
            ? outlineContent.bounds.height - outlineScroll.contentView.bounds.height : 0
        outlineScroll.contentView.scroll(to: NSPoint(x: 0, y: lastItemY))
        outlineScroll.reflectScrolledClipView(outlineScroll.contentView)
        #expect(abs(outlineScroll.contentView.bounds.origin.y - lastItemY) < 2)
    }
}
