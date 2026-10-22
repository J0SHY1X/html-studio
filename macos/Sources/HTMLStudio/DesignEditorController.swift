import Foundation
import AppKit
import WebKit

@MainActor
final class DesignEditorController: ObservableObject {
    @Published private(set) var isReady = false
    @Published private(set) var statusText = "正在准备可视化编辑器…"
    @Published private(set) var zoomPercent = 100

    @Published private(set) var comments: [PageComment] = []
    private var commentsVisible = false

    func refreshComments() {
        invoke("commentsList", arguments: []) { [weak self] value in
            self?.comments = (value as? [[String: String]] ?? []).enumerated().compactMap { offset, item in
                guard let id = item["id"], let note = item["note"], let text = item["text"] else { return nil }
                let number = Int(item["index"] ?? "") ?? offset + 1
                return PageComment(id: id, number: number, note: note, text: text)
            }
        }
    }

    func setCommentsVisible(_ visible: Bool) {
        commentsVisible = visible
        invoke("commentsVisible", arguments: [visible])
        refreshComments()
    }

    func prepareComment(completion: @escaping (String) -> Void) {
        invoke("prepareComment", arguments: []) { completion($0 as? String ?? "") }
    }

    func addComment(_ note: String, completion: @escaping (Bool) -> Void) {
        invoke("addComment", arguments: [note]) { [weak self] value in
            self?.refreshComments()
            completion(value as? Bool ?? false)
        }
    }

    func updateComment(_ id: String, note: String, completion: @escaping (Bool) -> Void) {
        invoke("updateComment", arguments: [id, note]) { [weak self] value in
            self?.refreshComments()
            completion(value as? Bool ?? false)
        }
    }

    func removeComment(_ id: String) { invoke("removeComment", arguments: [id]); refreshComments() }
    func revealComment(_ id: String) { invoke("revealComment", arguments: [id]) }

    private weak var webView: WKWebView?
    private var pendingLoad: DispatchWorkItem?

    func attach(_ webView: WKWebView) {
        self.webView = webView
        webView.pageZoom = Double(zoomPercent) / 100
    }

    func setZoom(_ percent: Int) {
        zoomPercent = min(200, max(50, percent))
        webView?.pageZoom = Double(zoomPercent) / 100
    }

    func selectedText(completion: @escaping (String) -> Void) {
        invoke("selectedText", arguments: []) { completion($0 as? String ?? "") }
    }

    func insertComponent(_ html: String, action: String) {
        invoke("insertComponent", arguments: [html, action])
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
            setCommentsVisible(commentsVisible)
        }
    }

    func setStatus(_ value: String) {
        statusText = value
    }

    func setEditable(_ editable: Bool) {
        invoke("setEditable", arguments: [editable])
    }

    func scrollToHeading(at index: Int) {
        invoke("scrollToHeading", arguments: [index])
    }

    func scheduleHTMLLoad(_ html: String, baseURL: URL?) {
        pendingLoad?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, let webView = self.webView else { return }
            self.setReady(false)
            webView.loadHTMLString(html, baseURL: PreviewBaseURL.effectiveURL(for: html, proposed: baseURL))
        }
        pendingLoad = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16, execute: item)
    }

    func loadHTMLImmediately(_ html: String, baseURL: URL?) {
        pendingLoad?.cancel()
        setReady(false)
        webView?.loadHTMLString(html, baseURL: PreviewBaseURL.effectiveURL(for: html, proposed: baseURL))
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

    func setTableBackgroundColor(_ value: String?) {
        invoke("setTableBackgroundColor", arguments: [value ?? "transparent"])
    }

    func pageAction(_ action: PageEditAction) {
        invoke("pageAction", arguments: [action.rawValue])
    }

    func setPageBackgroundColor(_ value: String?) {
        invoke("setPageBackgroundColor", arguments: [value ?? "transparent"])
    }

    func find(
        _ query: String,
        matchCase: Bool,
        backwards: Bool = false,
        reset: Bool = false,
        completion: @escaping (EditorFindResult) -> Void
    ) {
        invoke(
            "find",
            arguments: [query, matchCase, backwards, reset]
        ) { value in
            completion(Self.findResult(from: value))
        }
    }

    func replaceCurrent(
        query: String,
        replacement: String,
        matchCase: Bool,
        completion: @escaping (EditorFindResult) -> Void
    ) {
        invoke(
            "replaceCurrent",
            arguments: [query, replacement, matchCase]
        ) { value in
            completion(Self.findResult(from: value))
        }
    }

    func replaceAll(
        query: String,
        replacement: String,
        matchCase: Bool,
        completion: @escaping (EditorFindResult) -> Void
    ) {
        invoke(
            "replaceAll",
            arguments: [query, replacement, matchCase]
        ) { value in
            completion(Self.findResult(from: value))
        }
    }

    func clearFind() {
        invoke("clearFind", arguments: [])
    }

    private func invoke(
        _ function: String,
        arguments: [Any],
        completion: ((Any?) -> Void)? = nil
    ) {
        guard let webView else {
            completion?(nil)
            return
        }
        guard
            let data = try? JSONSerialization.data(withJSONObject: arguments),
            let json = String(data: data, encoding: .utf8)
        else {
            completion?(nil)
            return
        }
        let script = """
        if (window.__HTMLStudioEditor) {
          window.__HTMLStudioEditor.\(function).apply(window.__HTMLStudioEditor, \(json));
        }
        """
        webView.evaluateJavaScript(script) { [weak self] value, error in
            if let error {
                Task { @MainActor in
                    self?.statusText = "编辑命令未执行：\(error.localizedDescription)"
                    completion?(nil)
                }
            } else {
                completion?(value)
            }
        }
    }

    private static func findResult(from value: Any?) -> EditorFindResult {
        guard let payload = value as? [String: Any] else { return .empty }
        return EditorFindResult(
            current: (payload["current"] as? NSNumber)?.intValue ?? 0,
            total: (payload["total"] as? NSNumber)?.intValue ?? 0,
            replaced: (payload["replaced"] as? NSNumber)?.intValue ?? 0
        )
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
    case splitCurrent
}
