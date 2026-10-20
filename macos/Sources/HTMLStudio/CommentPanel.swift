import SwiftUI

struct PageComment: Identifiable {
    let id: String
    let note: String
    let text: String
}

struct CommentPanel: View {
    @ObservedObject var controller: DesignEditorController
    var isEditable: Bool
    @State private var showComposer = false
    @State private var quote = ""
    @State private var note = ""
    @State private var error = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("批注").font(.headline)
            Text("选择页面文字，或将光标置于段落中，再添加批注。")
                .font(.caption).foregroundStyle(.secondary)
            Button("＋ 添加批注") {
                controller.prepareComment { text in
                    if text.isEmpty { error = "请先在页面中选择文字，或点击需要批注的段落。" }
                    else { quote = text; note = ""; error = ""; showComposer = true }
                }
            }
            .disabled(!isEditable || !controller.isReady)
            if !error.isEmpty { Text(error).font(.caption).foregroundStyle(.red) }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if controller.comments.isEmpty {
                        Text("暂无批注").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(controller.comments) { comment in
                        VStack(alignment: .leading, spacing: 8) {
                            Button { controller.revealComment(comment.id) } label: {
                                Text(comment.text).font(.caption).lineLimit(3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.plain).foregroundStyle(.orange).help("定位到批注文字")
                            Text(comment.note).font(.callout).textSelection(.enabled)
                            Button("删除批注") { controller.removeComment(comment.id) }
                                .font(.caption).disabled(!isEditable)
                        }
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(14).frame(maxHeight: .infinity, alignment: .topLeading)
        .onAppear { controller.refreshComments() }
        .sheet(isPresented: $showComposer) {
            VStack(alignment: .leading, spacing: 14) {
                Text("添加批注").font(.headline)
                Text(String(quote.prefix(240))).font(.caption).foregroundStyle(.secondary).lineLimit(5)
                TextEditor(text: $note).frame(height: 140).border(Color.secondary.opacity(0.3))
                    .accessibilityLabel("批注内容")
                HStack {
                    Spacer()
                    Button("取消") { showComposer = false }.keyboardShortcut(.cancelAction)
                    Button("添加批注") {
                        controller.addComment(note) { success in
                            if success { showComposer = false }
                            else { error = "请选择尚未批注的文字或段落。"; showComposer = false }
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || note.count > 4000)
                }
            }.padding(20).frame(width: 440)
        }
    }
}
