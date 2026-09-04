import Foundation
import AppKit
import WebKit

@MainActor
final class DesignEditorController: ObservableObject {
    @Published private(set) var isReady = false
    @Published private(set) var statusText = "正在准备可视化编辑器…"

    private weak var webView: WKWebView?
    private var pendingLoad: DispatchWorkItem?

    func attach(_ webView: WKWebView) {
        self.webView = webView
    }

    func detach(_ webView: WKWebView) {
        if self.webView === webView {
            self.webView = nil
            isReady = false
        }
    }

    func setReady(_ value: Bool) {
        isReady = value
        if value {
            statusText = "可直接编辑页面内容"
        }
    }

    func setStatus(_ value: String) {
        statusText = value
    }

    func setEditable(_ editable: Bool) {
        invoke("setEditable", arguments: [editable])
    }

    func scheduleHTMLLoad(_ html: String, baseURL: URL?) {
        pendingLoad?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, let webView = self.webView else { return }
            self.setReady(false)
            webView.loadHTMLString(html, baseURL: baseURL)
        }
        pendingLoad = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16, execute: item)
    }

    func loadHTMLImmediately(_ html: String, baseURL: URL?) {
        pendingLoad?.cancel()
        setReady(false)
        webView?.loadHTMLString(html, baseURL: baseURL)
    }

    func execute(_ command: String, value: String? = nil) {
        invoke("exec", arguments: [command, value ?? NSNull()])
    }

    func pastePlainText() {
        guard let value = NSPasteboard.general.string(forType: .string) else { return }
        invoke("pastePlainText", arguments: [value])
    }

    func setFontSize(_ size: Int) {
        invoke("setFontSize", arguments: [size])
    }

    func insertTable(rows: Int, columns: Int) {
        invoke("insertTable", arguments: [rows, columns])
    }

    func tableAction(_ action: TableEditAction) {
        invoke("tableAction", arguments: [action.rawValue])
    }

    func pageAction(_ action: PageEditAction) {
        invoke("pageAction", arguments: [action.rawValue])
    }

    private func invoke(_ function: String, arguments: [Any]) {
        guard let webView else { return }
        guard
            let data = try? JSONSerialization.data(withJSONObject: arguments),
            let json = String(data: data, encoding: .utf8)
        else {
            return
        }
        let script = """
        if (window.__HTMLStudioEditor) {
          window.__HTMLStudioEditor.\(function).apply(window.__HTMLStudioEditor, \(json));
        }
        """
        webView.evaluateJavaScript(script) { [weak self] _, error in
            if let error {
                Task { @MainActor in
                    self?.statusText = "编辑命令未执行：\(error.localizedDescription)"
                }
            }
        }
    }
}

enum TableEditAction: String {
    case addRowBefore
    case addRowAfter
    case addColumnBefore
    case addColumnAfter
    case deleteRow
    case deleteColumn
    case toggleHeader
    case deleteTable
}

enum PageEditAction: String {
    case duplicateCurrent
    case insertBlankAfter
}
