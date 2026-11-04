import AppKit
import SwiftUI
import Testing
import WebKit
@testable import HTMLStudio

extension DocumentRegressionTests {
    @Test @MainActor
    func largeVisualDocumentCoalescesFullHTMLSynchronization() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HTMLStudio-Performance-\(UUID().uuidString)")
        let workspace = DocumentWorkspace(
            draftStore: DraftStore(supportDirectory: root),
            historyStore: ChangeLogStore(supportDirectory: root)
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let paragraphs = (0..<2_100).map { index in
            "<p id=\"row-\(index)\">第 \(index) 段：\(String(repeating: "大型文档输入性能测试。", count: 8))</p>"
        }.joined()
        let document = workspace.activeDocument
        document.updateHTML("<!doctype html><html><body>\(paragraphs)</body></html>")

        let host = NSHostingView(rootView: ContentView(workspace: workspace))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 780),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }
        host.layoutSubtreeIfNeeded()

        func descendants(_ view: NSView) -> [NSView] {
            [view] + view.subviews.flatMap(descendants)
        }
        let webView = try #require(descendants(host).compactMap { $0 as? WKWebView }.first)
        for _ in 0..<160 {
            if document.designController.isReady { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(document.designController.isReady)

        let before = try #require(
            try await webView.evaluateJavaScript(
                "window.__HTMLStudioEditor.performanceMetrics()"
            ) as? [String: Any]
        )
        #expect((before["elementCount"] as? NSNumber)?.intValue ?? 0 > 1_500)
        #expect((before["syncDelayMs"] as? NSNumber)?.intValue == 700)

        let inputDuration = try #require(
            try await webView.evaluateJavaScript(#"""
            (() => {
              const target = document.querySelector('#row-1000');
              const started = performance.now();
              for (let index = 0; index < 40; index += 1) {
                target.firstChild.appendData('测');
                target.dispatchEvent(new InputEvent('input', {
                  bubbles: true,
                  inputType: 'insertText',
                  data: '测'
                }));
              }
              return performance.now() - started;
            })()
            """#) as? Double
        )
        let immediatelyAfter = try #require(
            try await webView.evaluateJavaScript(
                "window.__HTMLStudioEditor.performanceMetrics()"
            ) as? [String: Any]
        )
        #expect(inputDuration < 250)
        #expect(
            (immediatelyAfter["snapshotCount"] as? NSNumber)?.intValue
                == (before["snapshotCount"] as? NSNumber)?.intValue
        )
        #expect(document.designController.hasUnsynchronizedChanges)

        for _ in 0..<60 {
            if document.html.contains(String(repeating: "测", count: 40)) { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(document.html.contains(String(repeating: "测", count: 40)))
        let synchronized = try #require(
            try await webView.evaluateJavaScript(
                "window.__HTMLStudioEditor.performanceMetrics()"
            ) as? [String: Any]
        )
        let snapshotsBefore = (before["snapshotCount"] as? NSNumber)?.intValue ?? 0
        let snapshotsAfter = (synchronized["snapshotCount"] as? NSNumber)?.intValue ?? 0
        #expect(snapshotsAfter - snapshotsBefore == 1)
        #expect(!document.designController.hasUnsynchronizedChanges)
    }

    @Test @MainActor
    func textPageTableColorsAndHighlighterRemainIndependent() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HTMLStudio-Colors-\(UUID().uuidString)")
        let workspace = DocumentWorkspace(
            draftStore: DraftStore(supportDirectory: root),
            historyStore: ChangeLogStore(supportDirectory: root)
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let document = workspace.activeDocument
        document.updateHTML("""
        <!doctype html><html><body>
        <section class="html-studio-page" id="page">
          <table id="table"><tbody><tr><td id="cell"><span id="text">独立颜色</span></td></tr></tbody></table>
          <p id="marker">荧光笔测试文字</p>
        </section></body></html>
        """)

        let host = NSHostingView(rootView: ContentView(workspace: workspace))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }
        host.layoutSubtreeIfNeeded()
        func descendants(_ view: NSView) -> [NSView] {
            [view] + view.subviews.flatMap(descendants)
        }
        let webView = try #require(descendants(host).compactMap { $0 as? WKWebView }.first)
        for _ in 0..<120 {
            if document.designController.isReady { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(document.designController.isReady)

        _ = try await webView.evaluateJavaScript(#"""
        (() => {
          const node = document.querySelector('#text').firstChild;
          const range = document.createRange();
          range.selectNodeContents(node);
          const selection = window.getSelection();
          selection.removeAllRanges(); selection.addRange(range);
          window.__HTMLStudioEditor.saveSelection();
          return true;
        })()
        """#)
        document.designController.execute("foreColor", value: "#DC2626")
        try await Task.sleep(nanoseconds: 120_000_000)
        document.designController.setTableBackgroundColor("#DCFCE7")
        try await Task.sleep(nanoseconds: 120_000_000)
        document.designController.setPageBackgroundColor("#DBEAFE")
        try await Task.sleep(nanoseconds: 500_000_000)

        let colorState = try #require(
            try await webView.evaluateJavaScript(#"""
            ({
              text: getComputedStyle(document.querySelector('#text')).color,
              table: getComputedStyle(document.querySelector('#cell')).backgroundColor,
              page: getComputedStyle(document.querySelector('#page')).backgroundColor
            })
            """#) as? [String: String]
        )
        #expect(colorState["text"] == "rgb(220, 38, 38)")
        #expect(colorState["table"] == "rgb(220, 252, 231)")
        #expect(colorState["page"] == "rgb(219, 234, 254)")

        _ = try await webView.evaluateJavaScript(#"""
        (() => {
          const node = document.querySelector('#marker').firstChild;
          const range = document.createRange();
          range.setStart(node, 0); range.setEnd(node, 3);
          const selection = window.getSelection();
          selection.removeAllRanges(); selection.addRange(range);
          window.__HTMLStudioEditor.saveSelection();
          return true;
        })()
        """#)
        document.designController.selectHighlighter("#CFF7D3")
        try await Task.sleep(nanoseconds: 80_000_000)
        let applied = try await webView.evaluateJavaScript(
            "window.__HTMLStudioEditor.applyHighlighterSelection()"
        ) as? Bool
        #expect(applied == true)
        let highlighted = try await webView.evaluateJavaScript(#"""
        Array.from(document.querySelectorAll('#marker *')).some(node =>
          getComputedStyle(node).backgroundColor === 'rgb(207, 247, 211)'
        )
        """#) as? Bool
        #expect(highlighted == true)
        #expect(document.designController.isHighlighterActive)
        document.designController.toggleHighlighter()
        #expect(!document.designController.isHighlighterActive)
    }
}
