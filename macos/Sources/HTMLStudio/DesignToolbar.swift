import AppKit
import SwiftUI

struct DesignToolbar: View {
    @ObservedObject var controller: DesignEditorController
    @Binding var isEditable: Bool
    let onInsertComponent: (HTMLComponentKind) -> Void

    @State private var selectedFont = "PingFang SC"
    @State private var selectedSize = 16
    @State private var selectedBlock = "p"

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
                    Label("可视化页面", systemImage: "square.and.pencil")
                        .font(.caption)
                        .fontWeight(.medium)

                    Picker("页面模式", selection: $isEditable) {
                        Text("直接编辑").tag(true)
                        Text("交互预览").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 168)
                    .onChange(of: isEditable) { value in
                        controller.setEditable(value)
                    }
                    .help("直接编辑可修改文字和格式；交互预览用于点击链接和运行页面脚本")

                    Text(isEditable ? "可修改文字与格式" : "可操作链接与脚本")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize()

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

                    SimpleColorPaletteButton(
                        title: "文字颜色",
                        systemImage: "textformat",
                        paletteID: "text",
                        colors: EditorColorPalette.text,
                        initialColor: "#111827"
                    ) { color in
                        if let color { controller.execute("foreColor", value: color) }
                    }

                    HighlighterTool(controller: controller)

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
                        onInsertComponent(.link)
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
                        onInsertComponent(.image)
                    } label: {
                        Image(systemName: "photo")
                    }
                    .help("插入图片（网址或本地图片）")

                    Menu {
                        Button("复制当前页到后面") {
                            controller.pageAction(.duplicateCurrent)
                        }
                        Button("在当前页后新增空白页") {
                            controller.pageAction(.insertBlankAfter)
                        }
                        Button("从光标处拆分为两页") {
                            controller.pageAction(.splitCurrent)
                        }

                        Divider()

                        Button("清除页面底色") {
                            controller.setPageBackgroundColor(nil)
                        }
                    } label: {
                        Label("页面", systemImage: "doc.on.doc")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("复制、新增、拆分页面或清除页面底色")

                    SimpleColorPaletteButton(
                        title: "页面底色",
                        systemImage: "doc.fill",
                        paletteID: "page-background",
                        colors: EditorColorPalette.surface,
                        initialColor: "#FFFFFF",
                        clearTitle: "恢复原页面底色"
                    ) { color in
                        controller.setPageBackgroundColor(color)
                    }

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

                        Button("清除表格底色") {
                            controller.setTableBackgroundColor(nil)
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

                    SimpleColorPaletteButton(
                        title: "表格底色",
                        systemImage: "tablecells.fill",
                        paletteID: "table-background",
                        colors: EditorColorPalette.surface,
                        initialColor: "#FFFFFF",
                        clearTitle: "恢复原表格底色"
                    ) { color in
                        controller.setTableBackgroundColor(color)
                    }

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

}

private struct HighlighterTool: View {
    @ObservedObject var controller: DesignEditorController

    var body: some View {
        HStack(spacing: 0) {
            Button {
                controller.toggleHighlighter()
            } label: {
                Label(
                    controller.highlighterColor == nil ? "取消高亮" : "荧光笔",
                    systemImage: controller.highlighterColor == nil
                        ? "eraser.fill" : "highlighter"
                )
                .padding(.horizontal, 4)
                .frame(height: 22)
                .background(
                    controller.isHighlighterActive
                        ? Color.accentColor.opacity(0.18) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 4)
                )
            }
            .help(controller.isHighlighterActive ? "结束荧光笔涂刷" : "开始荧光笔涂刷")

            Menu {
                ForEach(EditorColorPalette.highlighters) { color in
                    Button {
                        controller.selectHighlighter(color.hex)
                    } label: {
                        Label(color.name, systemImage: "circle.fill")
                    }
                }
                Divider()
                Button {
                    controller.selectHighlighter(nil)
                } label: {
                    Label("取消颜色（擦除高亮）", systemImage: "eraser")
                }
            } label: {
                Image(systemName: "chevron.down")
                    .frame(width: 16, height: 22)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("选择六色荧光笔或擦除模式；选择后自动开始涂刷")
        }
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.secondary.opacity(0.35))
        )
    }
}
