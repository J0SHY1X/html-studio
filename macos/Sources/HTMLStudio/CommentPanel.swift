import SwiftUI

struct PageComment: Identifiable {
    let id: String
    let number: Int
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
    @State private var composerError = ""
    @State private var editingCommentID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("批注").font(.headline)
            Text("选择页面文字，或将光标置于段落中，再添加批注。")
                .font(.caption).foregroundStyle(.secondary)
            Button("＋ 添加批注") {
                controller.prepareComment { text in
                    if text.isEmpty { error = "请先在页面中选择文字，或点击需要批注的段落。" }
                    else {
                        editingCommentID = nil
                        quote = text
                        note = ""
                        error = ""
                        composerError = ""
                        showComposer = true
                    }
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
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("[\(comment.number)]")
                                        .font(.caption.bold())
                                    Text(comment.text)
                                        .font(.caption)
                                        .lineLimit(3)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.plain).foregroundStyle(.orange).help("定位到批注文字")
                            Text(comment.note).font(.callout).textSelection(.enabled)
                            HStack(spacing: 12) {
                                Button("编辑批注") {
                                    editingCommentID = comment.id
                                    quote = comment.text
                                    note = comment.note
                                    composerError = ""
                                    showComposer = true
                                }
                                Button("删除批注") { controller.removeComment(comment.id) }
                            }
                            .font(.caption)
                            .disabled(!isEditable)
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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(editingCommentID == nil ? "添加批注" : "编辑批注")
                        .font(.title3.bold())
                    Text("批注对象")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(String(quote.prefix(240)))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))

                    Text("批注内容")
                        .font(.caption.bold())
                    TextEditor(text: $note)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(minHeight: 150)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                        }
                        .accessibilityLabel("批注内容")

                    if !composerError.isEmpty {
                        Text(composerError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    HStack {
                        Text("\(note.count) / 4000")
                            .font(.caption2)
                            .foregroundStyle(note.count > 4000 ? Color.red : Color.secondary)
                        Spacer()
                        Button("取消") { closeComposer() }
                            .keyboardShortcut(.cancelAction)
                        Button(editingCommentID == nil ? "添加批注" : "保存批注") {
                            saveComment()
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || note.count > 4000)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 30)
                .padding(.bottom, 24)
            }
            .frame(width: 520)
            .frame(minHeight: 430)
        }
    }

    private func closeComposer() {
        showComposer = false
        editingCommentID = nil
        composerError = ""
    }

    private func saveComment() {
        if let editingCommentID {
            controller.updateComment(editingCommentID, note: note) { success in
                if success { closeComposer() }
                else { composerError = "批注已不存在或暂时无法保存，请刷新后重试。" }
            }
        } else {
            controller.addComment(note) { success in
                if success { closeComposer() }
                else { composerError = "请选择尚未批注的文字或段落。" }
            }
        }
    }
}
