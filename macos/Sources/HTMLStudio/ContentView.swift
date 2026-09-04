import AppKit
import HTMLStudioCore
import SwiftUI
import UniformTypeIdentifiers

enum WorkspaceMode: String, CaseIterable, Identifiable {
    case editor = "源码"
    case split = "分屏"
    case preview = "预览"

    var id: Self { self }
}

private enum ActiveEditorSurface {
    case source
    case design
}

struct ContentView: View {
    @StateObject private var workspace = DocumentWorkspace()

    var body: some View {
        DocumentEditorView(
            workspace: workspace,
            document: workspace.activeDocument
        )
    }
}

private struct DocumentEditorView: View {
    @ObservedObject var workspace: DocumentWorkspace
    @ObservedObject var document: EditorDocument
    @StateObject private var codeEditorController = CodeEditorController()

    @State private var mode: WorkspaceMode = .split
    @State private var showSidebar = true
    @State private var showError = false
    @State private var showHistory = false
    @State private var designEditing = true
    @State private var activeEditorSurface: ActiveEditorSurface = .design
    @State private var isPreparingPrint = false

    private let conversionService = ConversionService.shared

    private var outlineItems: [OutlineItem] {
        OutlineParser.items(from: document.html)
    }

    var body: some View {
        editorWithCommands
            .sheet(isPresented: $showHistory) {
                HistoryView(document: document)
            }
            .alert("HTML Studio", isPresented: $showError) {
                Button("好", role: .cancel) {}
            } message: {
                Text(document.errorMessage ?? "发生未知错误。")
            }
    }

    private var editorWithCommands: some View {
        VStack(spacing: 0) {
            header
            Divider()
            tabBar
            Divider()

            HSplitView {
                if showSidebar {
                    sidebar
                        .frame(minWidth: 190, idealWidth: 220, maxWidth: 280)
                }

                workspaceView
                    .frame(minWidth: 560)
            }

            Divider()
            statusBar
        }
        .navigationTitle(document.displayName + (document.isDirty ? " — 已修改" : ""))
        .onChange(of: document.previewRevision) { _ in
            document.designController.scheduleHTMLLoad(
                document.html,
                baseURL: document.baseURL
            )
        }
        .onDisappear {
            workspace.persistAllDrafts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .htmlStudioNewDocument)) { _ in
            workspace.newDocument()
        }
        .onReceive(NotificationCenter.default.publisher(for: .htmlStudioOpenDocument)) { _ in
            openFromPanel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .htmlStudioOpenExternalFiles)) { notification in
            guard let urls = notification.userInfo?["urls"] as? [URL] else { return }
            urls.forEach(open)
        }
        .onReceive(NotificationCenter.default.publisher(for: .htmlStudioSaveDocument)) { _ in
            _ = save(document)
        }
        .onReceive(NotificationCenter.default.publisher(for: .htmlStudioSaveDocumentAs)) { _ in
            _ = saveAs(document)
        }
        .onReceive(NotificationCenter.default.publisher(for: .htmlStudioExportMarkdown)) { _ in
            exportMarkdown()
        }
        .onReceive(NotificationCenter.default.publisher(for: .htmlStudioExportDOCX)) { _ in
            exportDOCX()
        }
        .onReceive(NotificationCenter.default.publisher(for: .htmlStudioExportPDF)) { _ in
            exportPDF()
        }
        .onReceive(NotificationCenter.default.publisher(for: .htmlStudioPrint)) { _ in
            printDocument()
        }
        .onReceive(NotificationCenter.default.publisher(for: .htmlStudioShowHistory)) { _ in
            showHistory = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .htmlStudioUndo)) { _ in
            performUndo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .htmlStudioRedo)) { _ in
            performRedo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .htmlStudioPastePlainText)) { _ in
            performPastePlainText()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showSidebar.toggle()
                }
            } label: {
                Image(systemName: "sidebar.left")
            }
            .help("显示或隐藏侧边栏")

            Divider()
                .frame(height: 20)

            Button {
                workspace.newDocument()
            } label: {
                Label("新建", systemImage: "doc.badge.plus")
            }

            Button(action: openFromPanel) {
                Label("打开", systemImage: "folder")
            }

            Button {
                _ = save(document)
            } label: {
                Label("保存", systemImage: "square.and.arrow.down")
            }

            Divider()
                .frame(height: 20)

            Button(action: performUndo) {
                Label("撤销", systemImage: "arrow.uturn.backward")
            }
            .help("撤销当前编辑区域的上一步操作（⌘Z）")

            Button(action: performRedo) {
                Label("重做", systemImage: "arrow.uturn.forward")
            }
            .help("重做当前编辑区域的下一步操作（⇧⌘Z）")

            Spacer()

            Picker("工作区", selection: $mode) {
                ForEach(WorkspaceMode.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)

            Spacer()

            Button {
                showHistory = true
            } label: {
                Label("修改历史", systemImage: "clock.arrow.circlepath")
            }
            .help("查看、导出或恢复修改日志")

            Button(action: printDocument) {
                Label(
                    isPreparingPrint ? "准备打印" : "打印",
                    systemImage: "printer"
                )
            }
            .disabled(isPreparingPrint)
            .help("打开系统打印对话框（⌘P）")

            Menu {
                Button("导出 Markdown…", action: exportMarkdown)
                Button("导出 Word (.docx)…", action: exportDOCX)
                Button("导出 PDF…", action: exportPDF)
            } label: {
                Label("转换", systemImage: "arrow.triangle.2.circlepath")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(.bar)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(workspace.documents) { item in
                        DocumentTabItem(
                            document: item,
                            isSelected: item.id == workspace.selectedDocumentID,
                            onSelect: { workspace.select(item) },
                            onClose: { requestClose(item) }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
            }

            Divider()
                .frame(height: 22)

            Button {
                workspace.newDocument()
            } label: {
                Image(systemName: "plus")
                    .frame(width: 24, height: 22)
            }
            .buttonStyle(.borderless)
            .help("新建标签页")
            .padding(.horizontal, 6)
        }
        .frame(height: 36)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("文档")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Label(document.displayName, systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)

                if let url = document.fileURL {
                    Text(url.deletingLastPathComponent().path)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .help(url.path)
                } else {
                    Text("尚未保存")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Label(
                    "\(document.changeLogEntries.count) 条修改记录",
                    systemImage: "clock.arrow.circlepath"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(14)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("页面大纲")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                if outlineItems.isEmpty {
                    Text("添加 h1–h6 标题后会显示大纲")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(outlineItems) { item in
                                HStack(spacing: 6) {
                                    Text("H\(item.level)")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 18)
                                    Text(item.title)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                .padding(.leading, CGFloat(max(0, item.level - 1)) * 7)
                            }
                        }
                    }
                }
            }
            .padding(14)

            Spacer()

            Divider()

            VStack(alignment: .leading, spacing: 5) {
                Label("转换引擎", systemImage: "gearshape.2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(conversionService.conversionStatus)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private var workspaceView: some View {
        switch mode {
        case .editor:
            editorPane
        case .preview:
            previewPane
        case .split:
            HSplitView {
                editorPane
                    .frame(minWidth: 340)
                previewPane
                    .frame(minWidth: 340)
            }
        }
    }

    private var editorPane: some View {
        VStack(spacing: 0) {
            paneTitle("HTML", icon: "chevron.left.forwardslash.chevron.right")
            Divider()
            CodeEditor(text: Binding(
                get: { document.html },
                set: { document.updateHTML($0) }
            ), controller: codeEditorController) {
                activeEditorSurface = .source
            }
            .id(document.id)
        }
    }

    private var previewPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "square.and.pencil")
                Text(designEditing ? "可视化编辑" : "交互预览")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text(designEditing ? "右键支持剪贴板、颜色、段落与页面操作" : "页面脚本和链接可正常交互")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            DesignToolbar(
                controller: document.designController,
                isEditable: $designEditing
            )

            Divider()

            HTMLPreview(
                html: document.html,
                onHTMLChange: { html, action in
                    document.updateHTMLFromDesign(html, action: action)
                },
                baseURL: document.baseURL,
                isEditable: designEditing,
                controller: document.designController,
                onFocus: {
                    activeEditorSurface = .design
                }
            )
            .id(document.id)
        }
    }

    private func paneTitle(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func performUndo() {
        switch activeEditorSurface {
        case .source:
            codeEditorController.undo()
        case .design:
            document.designController.execute("undo")
        }
    }

    private func performRedo() {
        switch activeEditorSurface {
        case .source:
            codeEditorController.redo()
        case .design:
            document.designController.execute("redo")
        }
    }

    private func performPastePlainText() {
        switch activeEditorSurface {
        case .source:
            codeEditorController.pastePlainText()
        case .design:
            document.designController.pastePlainText()
        }
    }

    private var statusBar: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(document.isDirty ? Color.orange : Color.green)
                .frame(width: 7, height: 7)
            Text(
                document.isDirty
                    ? "有未保存更改"
                    : (document.fileURL == nil ? "新文档" : "已保存")
            )

            Spacer()

            Text("\(workspace.documents.count) 个标签页")
            Text("\(document.changeLogEntries.count) 条记录")
            Text("\(document.lineCount) 行")
            Text("\(document.html.count) 字符")
            Text("UTF-8")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(.bar)
    }

    private func openFromPanel() {
        let panel = NSOpenPanel()
        panel.title = "在标签页中打开网页或文档"
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            UTType.html,
            UTType(filenameExtension: "htm") ?? .html,
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "markdown") ?? .plainText,
            UTType(filenameExtension: "docx") ?? .data
        ]
        guard panel.runModal() == .OK else { return }
        panel.urls.forEach(open)
    }

    private func open(_ url: URL) {
        do {
            try workspace.open(url)
        } catch {
            present(error)
        }
    }

    private func requestClose(_ target: EditorDocument) {
        guard target.isDirty else {
            workspace.close(target)
            return
        }

        let alert = NSAlert()
        alert.messageText = "要保存对“\(target.displayName)”的更改吗？"
        alert.informativeText = "关闭标签页前可以保存；自动草稿和修改日志会继续保留。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "不保存并关闭")
        alert.addButton(withTitle: "取消")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            if save(target) { workspace.close(target) }
        case .alertSecondButtonReturn:
            workspace.close(target)
        default:
            break
        }
    }

    private func save(_ target: EditorDocument) -> Bool {
        do {
            if target.fileURL == nil {
                return saveAs(target)
            }
            try target.save()
            return true
        } catch {
            present(error)
            return false
        }
    }

    private func saveAs(_ target: EditorDocument) -> Bool {
        let panel = NSSavePanel()
        panel.title = "保存 HTML"
        panel.nameFieldStringValue = target.fileURL?.lastPathComponent ?? "未命名.html"
        panel.allowedContentTypes = [.html]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return false }

        do {
            let destination = url.pathExtension.isEmpty
                ? url.appendingPathExtension("html")
                : url
            try target.save(as: destination)
            return true
        } catch {
            present(error)
            return false
        }
    }

    private func exportMarkdown() {
        let panel = NSSavePanel()
        panel.title = "导出 Markdown"
        panel.nameFieldStringValue = document.fileURL?
            .deletingPathExtension()
            .appendingPathExtension("md")
            .lastPathComponent ?? "未命名.md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let destination = url.pathExtension.isEmpty
                ? url.appendingPathExtension("md")
                : url
            try document.exportMarkdown(to: destination)
        } catch {
            present(error)
        }
    }

    private func exportDOCX() {
        let panel = NSSavePanel()
        panel.title = "导出 Word 文档"
        panel.nameFieldStringValue = document.fileURL?
            .deletingPathExtension()
            .appendingPathExtension("docx")
            .lastPathComponent ?? "未命名.docx"
        panel.allowedContentTypes = [UTType(filenameExtension: "docx") ?? .data]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let destination = url.pathExtension.isEmpty
                ? url.appendingPathExtension("docx")
                : url
            try document.exportDOCX(to: destination)
        } catch {
            present(error)
        }
    }

    private func exportPDF() {
        let panel = NSSavePanel()
        panel.title = "导出 PDF"
        panel.nameFieldStringValue = document.fileURL?
            .deletingPathExtension()
            .appendingPathExtension("pdf")
            .lastPathComponent ?? "未命名.pdf"
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let destination = url.pathExtension.isEmpty
            ? url.appendingPathExtension("pdf")
            : url
        PDFExportService.shared.export(
            html: document.html,
            baseURL: document.baseURL,
            to: destination
        ) { result in
            if case .failure(let error) = result {
                present(error)
            }
        }
    }

    private func printDocument() {
        guard !isPreparingPrint else { return }
        isPreparingPrint = true

        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HTMLStudio-Print-\(UUID().uuidString)")
            .appendingPathExtension("pdf")

        PDFExportService.shared.export(
            html: document.html,
            baseURL: document.baseURL,
            to: temporaryURL
        ) { result in
            isPreparingPrint = false
            defer {
                try? FileManager.default.removeItem(at: temporaryURL)
            }

            switch result {
            case .success:
                do {
                    try PDFPrintService.printPDF(
                        at: temporaryURL,
                        jobName: document.displayName
                    )
                } catch {
                    present(error)
                }
            case .failure(let error):
                present(error)
            }
        }
    }

    private func present(_ error: Error) {
        document.errorMessage = error.localizedDescription
        showError = true
    }
}

private struct DocumentTabItem: View {
    @ObservedObject var document: EditorDocument
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onSelect) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 10))
                    Text(document.displayName)
                        .lineLimit(1)
                    if document.isDirty {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.leading, 9)
                .padding(.vertical, 5)
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: 17, height: 17)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("关闭标签页")
            .padding(.trailing, 5)
        }
        .font(.caption)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isSelected
                        ? Color(nsColor: .selectedControlColor).opacity(0.24)
                        : Color(nsColor: .windowBackgroundColor)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    isSelected
                        ? Color.accentColor.opacity(0.5)
                        : Color(nsColor: .separatorColor),
                    lineWidth: 1
                )
        )
        .help(document.fileURL?.path ?? "尚未保存")
    }
}
