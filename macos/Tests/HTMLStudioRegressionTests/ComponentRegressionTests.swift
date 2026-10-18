import AppKit
import SwiftUI
import Testing
import WebKit
@testable import HTMLStudio

extension DocumentRegressionTests {
    @Test
    func standaloneHTMLDoesNotRequestUnneededDirectoryAccess() {
        let base = URL(fileURLWithPath: "/Users/example/Downloads", isDirectory: true)
        for html in ["<p>独立页面</p>", "<a href='https://example.com'>链接</a>", "<a href='#section'>目录</a>", "<img src='data:image/png;base64,AA=='>", "<style>body{background:url(https://example.com/a.png)}</style>"] {
            #expect(PreviewBaseURL.effectiveURL(for: html, proposed: base) == nil)
        }
        for html in ["<img src='images/a.png'>", "<link href=styles.css rel=stylesheet>", "<style>body{background:url('../a.png')}</style>", "<style>@import 'styles.css';</style>", "<script>fetch('data.json')</script>", "<img srcset='a.png 1x, b.png 2x'>", "<img src='file:///Users/example/a.png'>"] {
            #expect(PreviewBaseURL.effectiveURL(for: html, proposed: base) == base)
        }
    }

    @Test
    func componentFieldsAreTextAndAddressesAreValidated() throws {
        for kind in HTMLComponentKind.allCases {
            let html = try HTMLComponent(kind: kind, title: "<标题> & \"文字\"", address: "https://example.com/?a=1&b=2", content: "正文 <script>\n第二行", newWindow: true).render()
            #expect(html.contains("data-html-studio-component=\"\(kind.rawValue)\""))
            #expect(!html.contains("<script>"))
            #expect(!html.contains("<标题>"))
        }
        #expect(try HTMLComponent(kind: .button, title: "按钮").render().contains("type=\"button\""))
        #expect(try HTMLComponent(kind: .button, address: "../page.html").render().contains("role=\"button\" href=\"../page.html\""))
        #expect(try HTMLComponent(kind: .image, address: "data:image/png;base64,AA==").render().contains("data:image/png;base64,AA=="))
        for value in ["javascript:alert(1)", "data:text/html,<script>", "java\nscript:alert(1)", ""] {
            #expect(throws: HTMLComponent.InvalidAddress.self) { try HTMLComponent(kind: .link, address: value).render() }
            #expect(throws: HTMLComponent.InvalidAddress.self) { try HTMLComponent(kind: .image, address: value).render() }
        }
    }

    @Test
    @MainActor
    func zoomAndComponentInsertionKeepEditingAndSavingWorking() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HTMLStudio-Components-\(UUID().uuidString)")
        let workspace = DocumentWorkspace(draftStore: DraftStore(supportDirectory: root), historyStore: ChangeLogStore(supportDirectory: root))
        defer { try? FileManager.default.removeItem(at: root) }
        let document = workspace.activeDocument
        let original = "<html><body><p id=target>before selected after</p></body></html>"
        document.updateHTML(original)
        let host = NSHostingView(rootView: ContentView(workspace: workspace))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }
        host.layoutSubtreeIfNeeded()
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        let webView = try #require(descendants(host).compactMap { $0 as? WKWebView }.first)
        for _ in 0..<120 {
            if document.designController.isReady { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(document.designController.isReady)
        let width = (try await webView.evaluateJavaScript("window.innerWidth")) as? Double ?? 0
        document.designController.setZoom(150)
        #expect(webView.pageZoom == 1.5)
        let zoomedWidth = (try await webView.evaluateJavaScript("window.innerWidth")) as? Double ?? 0
        #expect(zoomedWidth < width)
        #expect(document.html == original)
        #expect(HTMLPreview.contextMenuPoint(x: 60, y: 75, in: webView, zoom: 1.5).x == 90)
        _ = try await webView.evaluateJavaScript("""
        const node = document.querySelector('#target').firstChild;
        const range = document.createRange(); range.setStart(node, 7); range.setEnd(node, 15);
        window.getSelection().removeAllRanges(); window.getSelection().addRange(range);
        window.__HTMLStudioEditor.saveSelection();
        """)
        let link = try HTMLComponent(kind: .link, title: "链接 <文字>", address: "https://example.com/?a=1&b=2").render()
        document.designController.insertComponent(link, action: "插入链接组件")
        for _ in 0..<120 {
            if document.html.contains("data-html-studio-component=\"link\"") { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        let actualText = try await webView.evaluateJavaScript("document.querySelector('#target').textContent") as? String
        #expect(document.html.contains("data-html-studio-component=\"link\""))
        #expect(actualText?.replacingOccurrences(of: "\u{00a0}", with: " ") == "before 链接 <文字> after")
        document.designController.execute("undo")
        for _ in 0..<80 {
            if !document.html.contains("data-html-studio-component=\"link\"") { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(!document.html.contains("data-html-studio-component=\"link\""))
        document.designController.execute("redo")
        for _ in 0..<80 {
            if document.html.contains("data-html-studio-component=\"link\"") { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(document.html.contains("data-html-studio-component=\"link\""))
        for kind in HTMLComponentKind.allCases where kind != .link {
            _ = try await webView.evaluateJavaScript("window.__HTMLStudioEditor.placeCaretAtEnd(); true")
            let address = kind == .image
                ? "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=" : ""
            let html = try HTMLComponent(kind: kind, title: kind.defaultTitle, address: address, content: kind.defaultContent).render()
            let before = document.html
            document.designController.insertComponent(html, action: "插入\(kind.name)组件")
            for _ in 0..<80 {
                if document.html != before { break }
                try await Task.sleep(nanoseconds: 25_000_000)
            }
            #expect(document.html != before, "\(kind.name)必须同步到源码")
        }
        #expect((try await webView.evaluateJavaScript("document.querySelectorAll('details').length")) as? Int == 1)
        #expect((try await webView.evaluateJavaScript("document.querySelectorAll('input').length")) as? Int == 1)
        #expect((try await webView.evaluateJavaScript("document.querySelectorAll('img').length")) as? Int == 1)
        let destination = root.appendingPathComponent("components.html")
        try document.save(as: destination)
        let saved = try String(contentsOf: destination, encoding: .utf8)
        #expect(saved.contains("链接 &lt;文字&gt;"))
        #expect(!saved.contains("page-scale"))
        #expect(!saved.contains("pageZoom"))
        let secondWebView = WKWebView()
        document.designController.attach(secondWebView)
        #expect(secondWebView.pageZoom == 1.5)
        document.designController.attach(webView)
    }

    @Test
    @MainActor
    func componentsInsertAtSourceCaretAndUndoAsOneEdit() async throws {
        _ = NSApplication.shared
        let original = "<html><body><p>正文</p></body></html>"
        var source = original
        let controller = CodeEditorController()
        let editor = CodeEditor(text: Binding(get: { source }, set: { source = $0 }), controller: controller, onFocus: {})
        let host = NSHostingView(rootView: editor)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }
        host.layoutSubtreeIfNeeded()
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        let text = try #require(descendants(host).compactMap { $0 as? NSTextView }.first)
        window.makeFirstResponder(text)
        let caret = (original as NSString).range(of: "</body>").location
        text.setSelectedRange(NSRange(location: caret, length: 0))
        let html = try HTMLComponent(kind: .heading, title: "新增标题").render()
        controller.insertHTML(html)
        #expect(source == original.replacingOccurrences(of: "</body>", with: html + "</body>"))
        controller.undo()
        for _ in 0..<40 {
            if source == original { break }
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        #expect(source == original)
        controller.redo()
        for _ in 0..<40 {
            if source.contains("新增标题") { break }
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        #expect(source.contains("新增标题"))
    }
}
