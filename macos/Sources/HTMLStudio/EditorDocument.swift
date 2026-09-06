import AppKit
import Foundation
import HTMLStudioCore

@MainActor
final class EditorDocument: ObservableObject, Identifiable {
    static let starterHTML = """
    <!doctype html>
    <html lang="zh-CN">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>未命名页面</title>
      <style>
        body {
          max-width: 780px;
          margin: 64px auto;
          padding: 0 28px;
          color: #172033;
          background: #ffffff;
          font: 17px/1.7 -apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif;
        }
        h1 { letter-spacing: -0.025em; }
        .card {
          margin-top: 32px;
          padding: 24px;
          border: 1px solid #d9dee7;
          border-radius: 16px;
          background: #f5f7fb;
        }
      </style>
    </head>
    <body>
      <h1>欢迎使用 HTML Studio</h1>
      <p>可以在左侧编辑 HTML，也可以直接点击右侧页面进行可视化编辑。</p>
      <div class="card">
        <strong>可以从这里开始：</strong>
        <ul>
          <li>在标签页中同时打开多个 HTML 文件</li>
          <li>像 Word 一样修改字体、段落和表格</li>
          <li>右键使用剪贴板、纯文本粘贴、文字颜色和背景颜色</li>
          <li>复制、追加页面，或从光标处把当前页拆成两页</li>
          <li>查看修改日志并恢复历史版本</li>
        </ul>
      </div>
    </body>
    </html>
    """

    let id: UUID
    let designController = DesignEditorController()

    @Published var html: String
    @Published private(set) var fileURL: URL?
    @Published private(set) var isDirty = false
    @Published var errorMessage: String?
    @Published private(set) var lastSavedAt: Date?
    @Published private(set) var previewRevision = 0
    @Published private(set) var changeLogEntries: [ChangeLogEntry] = []

    private let conversionService: ConversionService
    private let draftStore: DraftStore
    private let historyStore: ChangeLogStore
    private var draftWorkItem: DispatchWorkItem?
    private var historyTask: Task<Void, Never>?
    private var savedHTML: String
    private var draftIdentifier: UUID
    private var historyKey = ""

    init(
        conversionService: ConversionService = .shared,
        draftStore: DraftStore = .shared,
        historyStore: ChangeLogStore = .shared,
        restoreDraft: Bool = false
    ) {
        let identifier = UUID()
        id = identifier
        draftIdentifier = identifier
        self.conversionService = conversionService
        self.draftStore = draftStore
        self.historyStore = historyStore

        if restoreDraft,
           let draft = draftStore.restoreLatest(),
           !draft.html.isEmpty {
            html = draft.html
            fileURL = draft.filePath.map(URL.init(fileURLWithPath:))
            isDirty = draft.isDirty
            savedHTML = draft.isDirty ? "" : draft.html
            draftIdentifier = draft.identifier ?? identifier
        } else {
            html = Self.starterHTML
            savedHTML = Self.starterHTML
        }

        historyKey = historyStore.key(for: fileURL, fallback: draftIdentifier)
        changeLogEntries = historyStore.entries(for: historyKey)
        if changeLogEntries.isEmpty {
            recordHistoryImmediately(
                action: restoreDraft && isDirty ? "恢复自动草稿" : "创建文档",
                source: "文件",
                summary: "\(html.count) 个字符"
            )
        }
    }

    deinit {
        historyTask?.cancel()
        draftWorkItem?.cancel()
    }

    var displayName: String {
        fileURL?.lastPathComponent ?? "未命名.html"
    }

    var baseURL: URL? {
        fileURL?.deletingLastPathComponent()
    }

    var lineCount: Int {
        max(1, html.reduce(into: 1) { count, character in
            if character == "\n" { count += 1 }
        })
    }

    func updateHTML(_ newValue: String) {
        applyHTMLUpdate(
            newValue,
            action: "编辑 HTML 源码",
            source: "源码"
        )
        previewRevision &+= 1
    }

    func updateHTMLFromDesign(
        _ newValue: String,
        action: String = "编辑可视化页面"
    ) {
        applyHTMLUpdate(
            newValue,
            action: action,
            source: "页面"
        )
    }

    private func applyHTMLUpdate(
        _ newValue: String,
        action: String,
        source: String
    ) {
        guard newValue != html else { return }
        let previousCount = html.count
        html = newValue
        isDirty = newValue != savedHTML
        scheduleDraftSave()
        scheduleHistory(
            action: action,
            source: source,
            summary: Self.changeSummary(
                previousCount: previousCount,
                newCount: newValue.count
            )
        )
    }

    func open(_ url: URL) throws {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        let ext = url.pathExtension.lowercased()
        switch ext {
        case "html", "htm":
            html = try Self.readTextFile(url)
        case "md", "markdown":
            let markdown = try Self.readTextFile(url)
            html = try conversionService.markdownToHTML(markdown)
        case "docx":
            html = try conversionService.docxToHTML(url)
        default:
            throw StudioError.unsupportedFormat(ext.isEmpty ? "未知" : ext)
        }

        let isHTMLFile = ext == "html" || ext == "htm"
        fileURL = isHTMLFile ? url : nil
        savedHTML = isHTMLFile ? html : ""
        isDirty = !isHTMLFile
        lastSavedAt = nil
        previewRevision &+= 1

        historyTask?.cancel()
        historyKey = historyStore.key(for: url, fallback: draftIdentifier)
        changeLogEntries = historyStore.entries(for: historyKey)
        recordHistoryImmediately(
            action: isHTMLFile ? "打开 HTML 文件" : "导入 \(ext.uppercased()) 文件",
            source: "文件",
            summary: url.lastPathComponent
        )

        addRecentFile(url)
        scheduleDraftSave()
    }

    func save() throws {
        guard let fileURL else {
            throw StudioError.saveLocationRequired
        }
        try writeHTML(to: fileURL)
    }

    func save(as url: URL) throws {
        let previousKey = historyKey
        try writeHTML(to: url)
        fileURL = url
        historyKey = historyStore.key(for: url, fallback: draftIdentifier)
        changeLogEntries = historyStore.migrate(from: previousKey, to: historyKey)
        addRecentFile(url)
        recordHistoryImmediately(
            action: "另存为 HTML",
            source: "文件",
            summary: url.lastPathComponent
        )
    }

    func exportMarkdown(to url: URL) throws {
        let markdown = try conversionService.htmlToMarkdown(html)
        try Self.write(markdown, to: url)
    }

    func exportDOCX(to url: URL) throws {
        try conversionService.htmlToDOCX(html, destination: url)
    }

    func exportHistory(to url: URL) throws {
        try historyStore.export(changeLogEntries, to: url)
    }

    func restoreHistory(_ entry: ChangeLogEntry) {
        guard entry.html != html else { return }
        historyTask?.cancel()
        let previousCount = html.count
        html = entry.html
        isDirty = html != savedHTML
        previewRevision &+= 1
        scheduleDraftSave()
        recordHistoryImmediately(
            action: "恢复历史版本",
            source: "历史",
            summary: "\(Self.changeSummary(previousCount: previousCount, newCount: html.count))；来源 \(Self.historyDateFormatter.string(from: entry.timestamp))"
        )
    }

    private func writeHTML(to url: URL) throws {
        try Self.write(html, to: url)
        savedHTML = html
        isDirty = false
        lastSavedAt = Date()
        draftStore.clear(identifier: draftIdentifier)
    }

    private func scheduleDraftSave() {
        draftWorkItem?.cancel()
        let snapshot = html
        let path = fileURL?.path
        let dirty = isDirty
        let identifier = draftIdentifier
        let workItem = DispatchWorkItem { [draftStore] in
            draftStore.save(
                identifier: identifier,
                html: snapshot,
                filePath: path,
                isDirty: dirty
            )
        }
        draftWorkItem = workItem
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + 0.7,
            execute: workItem
        )
    }

    private func scheduleHistory(
        action: String,
        source: String,
        summary: String
    ) {
        historyTask?.cancel()
        historyTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled, let self else { return }
            self.recordHistoryImmediately(
                action: action,
                source: source,
                summary: summary
            )
        }
    }

    private func recordHistoryImmediately(
        action: String,
        source: String,
        summary: String
    ) {
        let entry = ChangeLogEntry(
            id: UUID(),
            timestamp: Date(),
            source: source,
            action: action,
            summary: summary,
            filePath: fileURL?.path,
            html: html
        )
        changeLogEntries = historyStore.append(entry, for: historyKey)
    }

    func persistDraftNow() {
        draftWorkItem?.cancel()
        draftStore.save(
            identifier: draftIdentifier,
            html: html,
            filePath: fileURL?.path,
            isDirty: isDirty
        )
    }

    private func addRecentFile(_ url: URL) {
        var paths = UserDefaults.standard.stringArray(forKey: "recentFilePaths") ?? []
        paths.removeAll { $0 == url.path }
        paths.insert(url.path, at: 0)
        UserDefaults.standard.set(Array(paths.prefix(10)), forKey: "recentFilePaths")
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }

    static func readTextFile(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        if let value = String(data: data, encoding: .utf8) {
            return value
        }
        if let value = String(data: data, encoding: .utf16) {
            return value
        }
        if let value = String(data: data, encoding: .isoLatin1) {
            return value
        }
        throw StudioError.textEncoding
    }

    private static func write(_ value: String, to url: URL) throws {
        guard let data = value.data(using: .utf8) else {
            throw StudioError.textEncoding
        }
        try data.write(to: url, options: .atomic)
    }

    private static func changeSummary(
        previousCount: Int,
        newCount: Int
    ) -> String {
        let delta = newCount - previousCount
        if delta > 0 {
            return "增加 \(delta) 个字符；当前 \(newCount) 个字符"
        }
        if delta < 0 {
            return "减少 \(-delta) 个字符；当前 \(newCount) 个字符"
        }
        return "内容或格式发生变化；当前 \(newCount) 个字符"
    }

    private static let historyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}
