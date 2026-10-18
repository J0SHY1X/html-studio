import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ComponentInsertView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kind: HTMLComponentKind
    @State private var title: String
    @State private var address = ""
    @State private var content: String
    @State private var newWindow = false
    @State private var errorMessage: String?
    @State private var embeddedImage: String?
    @State private var imageName: String?
    private let selectedText: String
    let onInsert: (String, String) -> Void

    init(kind: HTMLComponentKind, selectedText: String, onInsert: @escaping (String, String) -> Void) {
        _kind = State(initialValue: kind)
        _title = State(initialValue: selectedText.isEmpty ? kind.defaultTitle : selectedText)
        _content = State(initialValue: selectedText.isEmpty ? kind.defaultContent : selectedText)
        self.selectedText = selectedText
        self.onInsert = onInsert
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("插入组件").font(.title2.bold())
            Text("插入到当前光标或选区，之后可在页面或源码中继续编辑。")
                .font(.callout).foregroundStyle(.secondary)
            Picker("组件类型", selection: $kind) {
                ForEach(HTMLComponentKind.allCases) { item in
                    Text(item.name).tag(item)
                }
            }
            .onChange(of: kind) { value in
                title = selectedText.isEmpty ? value.defaultTitle : selectedText
                content = selectedText.isEmpty ? value.defaultContent : selectedText
                address = ""
                embeddedImage = nil
                imageName = nil
                errorMessage = nil
            }

            if kind.hasTitle {
                TextField(kind == .image ? "替代文字" : "文字 / 标题", text: $title)
                    .textFieldStyle(.roundedBorder)
            }
            if kind.hasAddress {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        if let imageName, kind == .image {
                            Text(imageName).lineLimit(1).truncationMode(.middle)
                            Button("清除") { embeddedImage = nil; self.imageName = nil }
                            Spacer()
                        } else {
                            TextField(kind == .image ? "图片地址或相对路径" : "链接地址", text: $address)
                                .textFieldStyle(.roundedBorder)
                        }
                        if kind == .image {
                            Button("选择本地图片…", action: chooseImage)
                        }
                    }
                    if kind == .image {
                        Text(embeddedImage != nil ? "已嵌入本地图片，可随 HTML 文件一起保存。" : "支持图片网址、相对路径，或将本地图片嵌入 HTML。")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        if kind == .button {
                            Text("可选：填写链接后，按钮可跳转到该地址。")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Toggle("在新窗口打开链接", isOn: $newWindow)
                    }
                }
            }
            if kind.hasContent {
                VStack(alignment: .leading, spacing: 6) {
                    Text(contentLabel).font(.callout)
                    TextEditor(text: $content)
                        .font(.body)
                        .frame(height: 110)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
                }
            }
            if kind == .divider {
                Divider().padding(.vertical, 12)
                Text("插入一条水平分隔线。").foregroundStyle(.secondary)
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.callout)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("插入", action: insert).keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 500)
    }

    private var contentLabel: String {
        switch kind {
        case .columns: return "两栏内容（第一行为左栏，其余为右栏）"
        case .list: return "列表内容（每行一项）"
        case .image: return "图片说明（可选）"
        case .input: return "输入提示"
        default: return "内容"
        }
    }

    private func insert() {
        do {
            let html = try HTMLComponent(kind: kind, title: title, address: embeddedImage ?? address, content: content, newWindow: newWindow).render()
            onInsert(html, "插入\(kind.name)组件")
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.title = "选择要嵌入的图片"
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            var data = try Data(contentsOf: url)
            let type = UTType(filenameExtension: url.pathExtension)
            var mime = type?.preferredMIMEType ?? "image/png"
            if !["image/png", "image/jpeg", "image/gif", "image/webp", "image/svg+xml", "image/avif"].contains(mime) {
                guard let bitmap = NSBitmapImageRep(data: data), let png = bitmap.representation(using: .png, properties: [:]) else {
                    errorMessage = "无法读取此图片，请选择 PNG、JPEG、GIF、WebP 或 SVG 图片。"
                    return
                }
                data = png
                mime = "image/png"
            }
            embeddedImage = "data:\(mime);base64,\(data.base64EncodedString())"
            imageName = url.lastPathComponent
            if title.isEmpty || title == kind.defaultTitle { title = url.deletingPathExtension().lastPathComponent }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
