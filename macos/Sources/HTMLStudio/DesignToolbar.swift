import AppKit
import SwiftUI

struct DesignToolbar: View {
    @ObservedObject var controller: DesignEditorController
    @Binding var isEditable: Bool

    @State private var selectedFont = "PingFang SC"
    @State private var selectedSize = 16
    @State private var selectedBlock = "p"
    @State private var foregroundColor = Color.primary
    @State private var highlightColor = Color.yellow.opacity(0.45)

    private let fonts = [
        "PingFang SC",
        "Songti SC",
        "Heiti SC",
        "Kaiti SC",
        "Arial",
        "Helvetica",
        "Times New Roman",
        "Georgia",
        "Menlo"
    ]
    private let sizes = [10, 12, 14, 16, 18, 20, 24, 28, 32, 36, 48, 64, 72]

    var body: some View {
        VStack(spacing: 3) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    Toggle(isOn: $isEditable) {
                        Label("直接编辑", systemImage: "cursorarrow.and.square.on.square.dashed")
                            .font(.caption)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .onChange(of: isEditable) { value in
                        controller.setEditable(value)
                    }

                    groupDivider

                    Picker("字体", selection: $selectedFont) {
                        ForEach(fonts, id: \.self) { font in
                            Text(font).tag(font)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 128)
                    .onChange(of: selectedFont) { font in
                        controller.execute("fontName", value: font)
                    }
                    .help("字体")

                    Picker("字号", selection: $selectedSize) {
                        ForEach(sizes, id: \.self) { size in
                            Text("\(size)").tag(size)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 58)
                    .onChange(of: selectedSize) { size in
                        controller.setFontSize(size)
                    }
                    .help("字号")

                    groupDivider

                    commandButton("bold", icon: "bold", help: "粗体")
                    commandButton("italic", icon: "italic", help: "斜体")
                    commandButton("underline", icon: "underline", help: "下划线")
                    commandButton("strikeThrough", icon: "strikethrough", help: "删除线")

                    ColorPicker(
                        "",
                        selection: $foregroundColor,
                        supportsOpacity: false
                    )
                    .labelsHidden()
                    .frame(width: 26)
                    .help("文字颜色")
                    .onChange(of: foregroundColor) { color in
                        controller.execute("foreColor", value: color.hexString)
                    }

                    ColorPicker(
                        "",
                        selection: $highlightColor,
                        supportsOpacity: true
                    )
                    .labelsHidden()
                    .frame(width: 26)
                    .help("文字底色")
                    .onChange(of: highlightColor) { color in
                        controller.execute("hiliteColor", value: color.hexString)
                    }

                    groupDivider

                    commandLabelButton(
                        "undo",
                        title: "撤销",
                        icon: "arrow.uturn.backward",
                        help: "撤销页面编辑"
                    )
                    commandLabelButton(
                        "redo",
                        title: "重做",
                        icon: "arrow.uturn.forward",
                        help: "重做页面编辑"
                    )
                }
                .padding(.horizontal, 8)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    Picker("段落", selection: $selectedBlock) {
                        Text("正文").tag("p")
                        Text("标题 1").tag("h1")
                        Text("标题 2").tag("h2")
                        Text("标题 3").tag("h3")
                        Text("标题 4").tag("h4")
                        Text("引用").tag("blockquote")
                        Text("预格式文本").tag("pre")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 96)
                    .onChange(of: selectedBlock) { block in
                        controller.execute("formatBlock", value: block)
                    }
                    .help("段落和标题样式")

                    commandButton("insertParagraph", icon: "paragraphsign", help: "插入新段落")

                    groupDivider

                    commandButton("justifyLeft", icon: "text.alignleft", help: "左对齐")
                    commandButton("justifyCenter", icon: "text.aligncenter", help: "居中")
                    commandButton("justifyRight", icon: "text.alignright", help: "右对齐")
                    commandButton("justifyFull", icon: "text.justify", help: "两端对齐")

                    groupDivider

                    commandButton(
                        "insertUnorderedList",
                        icon: "list.bullet",
                        help: "项目符号列表"
                    )
                    commandButton(
                        "insertOrderedList",
                        icon: "list.number",
                        help: "编号列表"
                    )
                    commandButton("outdent", icon: "decrease.indent", help: "减少缩进")
                    commandButton("indent", icon: "increase.indent", help: "增加缩进")

                    groupDivider

                    Button {
                        insertLink()
                    } label: {
                        Image(systemName: "link")
                    }
                    .help("插入链接")

                    Button {
                        controller.execute("unlink")
                    } label: {
                        Image(systemName: "link.badge.minus")
                    }
                    .help("移除链接")

                    Button {
                        insertImage()
                    } label: {
                        Image(systemName: "photo")
                    }
                    .help("插入网络图片")

                    Menu {
                        Button("复制当前页到后面") {
                            controller.pageAction(.duplicateCurrent)
                        }
                        Button("在当前页后新增空白页") {
                            controller.pageAction(.insertBlankAfter)
                        }
                    } label: {
                        Label("页面", systemImage: "doc.on.doc")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("复制页面格式或新增页面")

                    Menu {
                        Button("插入 2 × 2 表格") {
                            controller.insertTable(rows: 2, columns: 2)
                        }
                        Button("插入 3 × 3 表格") {
                            controller.insertTable(rows: 3, columns: 3)
                        }
                        Button("插入 4 × 4 表格") {
                            controller.insertTable(rows: 4, columns: 4)
                        }

                        Divider()

                        Button("在上方添加行") {
                            controller.tableAction(.addRowBefore)
                        }
                        Button("在下方添加行") {
                            controller.tableAction(.addRowAfter)
                        }
                        Button("在左侧添加列") {
                            controller.tableAction(.addColumnBefore)
                        }
                        Button("在右侧添加列") {
                            controller.tableAction(.addColumnAfter)
                        }

                        Divider()

                        Button("切换首行为表头") {
                            controller.tableAction(.toggleHeader)
                        }
                        Button("删除当前行") {
                            controller.tableAction(.deleteRow)
                        }
                        Button("删除当前列") {
                            controller.tableAction(.deleteColumn)
                        }
                        Button("删除整个表格", role: .destructive) {
                            controller.tableAction(.deleteTable)
                        }
                    } label: {
                        Label("表格", systemImage: "tablecells")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    Button {
                        controller.execute("insertHorizontalRule")
                    } label: {
                        Image(systemName: "minus")
                    }
                    .help("插入分隔线")

                    Button {
                        controller.execute("removeFormat")
                    } label: {
                        Image(systemName: "eraser")
                    }
                    .help("清除文字格式")

                    groupDivider

                    Label(
                        controller.statusText,
                        systemImage: controller.isReady ? "checkmark.circle.fill" : "clock"
                    )
                    .font(.caption2)
                    .foregroundStyle(controller.isReady ? Color.secondary : Color.orange)
                    .lineLimit(1)
                }
                .padding(.horizontal, 8)
            }
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
        .disabled(!controller.isReady)
    }

    private var groupDivider: some View {
        Divider()
            .frame(height: 18)
            .padding(.horizontal, 2)
    }

    private func commandButton(
        _ command: String,
        icon: String,
        help: String
    ) -> some View {
        Button {
            controller.execute(command)
        } label: {
            Image(systemName: icon)
                .frame(width: 20, height: 18)
        }
        .help(help)
    }

    private func commandLabelButton(
        _ command: String,
        title: String,
        icon: String,
        help: String
    ) -> some View {
        Button {
            controller.execute(command)
        } label: {
            Label(title, systemImage: icon)
        }
        .help(help)
    }

    private func insertLink() {
        guard let value = requestText(
            title: "插入链接",
            message: "输入链接地址：",
            placeholder: "https://example.com"
        ) else {
            return
        }
        controller.execute("createLink", value: value)
    }

    private func insertImage() {
        guard let value = requestText(
            title: "插入图片",
            message: "输入图片 URL 或相对路径：",
            placeholder: "images/example.png"
        ) else {
            return
        }
        controller.execute("insertImage", value: value)
    }

    private func requestText(
        title: String,
        message: String,
        placeholder: String
    ) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "插入")
        alert.addButton(withTitle: "取消")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 24))
        field.placeholderString = placeholder
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

private extension Color {
    var hexString: String {
        guard
            let color = NSColor(self).usingColorSpace(.sRGB)
        else {
            return "#000000"
        }
        let red = Int(round(color.redComponent * 255))
        let green = Int(round(color.greenComponent * 255))
        let blue = Int(round(color.blueComponent * 255))
        if color.alphaComponent < 0.999 {
            let alpha = Int(round(color.alphaComponent * 255))
            return String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
        }
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
