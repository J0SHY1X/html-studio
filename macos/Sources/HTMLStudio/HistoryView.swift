import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
    @ObservedObject var document: EditorDocument
    @Environment(\.dismiss) private var dismiss

    @State private var selectedEntryID: UUID?
    @State private var pendingRestore: ChangeLogEntry?
    @State private var errorMessage: String?

    private var newestFirst: [ChangeLogEntry] {
        document.changeLogEntries.reversed()
    }

    private var selectedEntry: ChangeLogEntry? {
        guard let selectedEntryID else { return newestFirst.first }
        return newestFirst.first { $0.id == selectedEntryID }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("修改历史")
                        .font(.title2.weight(.semibold))
                    Text(document.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("导出日志…", action: exportLog)
                Button("完成", action: dismiss.callAsFunction)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)

            Divider()

            if newestFirst.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text("尚无修改记录")
                        .font(.headline)
                    Text("编辑源码或页面后，会在这里记录可恢复的版本。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HSplitView {
                    List(newestFirst, selection: $selectedEntryID) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.action)
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                                Text(entry.source)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(entry.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            Text(Self.dateFormatter.string(from: entry.timestamp))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                        .tag(entry.id)
                    }
                    .frame(minWidth: 300, idealWidth: 360)

                    VStack(alignment: .leading, spacing: 10) {
                        if let entry = selectedEntry {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.action)
                                        .font(.headline)
                                    Text(entry.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("恢复到此版本") {
                                    pendingRestore = entry
                                }
                            }

                            Divider()

                            ScrollView {
                                Text(entry.html)
                                    .font(.system(size: 11, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                    .padding(12)
                            }
                            .background(Color(nsColor: .textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                    }
                    .padding(14)
                    .frame(minWidth: 420)
                }
            }
        }
        .frame(minWidth: 820, minHeight: 560)
        .alert(
            "恢复历史版本？",
            isPresented: Binding(
                get: { pendingRestore != nil },
                set: { if !$0 { pendingRestore = nil } }
            ),
            presenting: pendingRestore
        ) { entry in
            Button("恢复", role: .destructive) {
                document.restoreHistory(entry)
                pendingRestore = nil
            }
            Button("取消", role: .cancel) {
                pendingRestore = nil
            }
        } message: { entry in
            Text("当前内容不会被删除；恢复操作本身也会写入修改日志。目标时间：\(Self.dateFormatter.string(from: entry.timestamp))")
        }
        .alert(
            "无法导出日志",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "发生未知错误。")
        }
    }

    private func exportLog() {
        let panel = NSSavePanel()
        panel.title = "导出修改日志"
        panel.nameFieldStringValue = "\(document.displayName)-修改日志.json"
        panel.allowedContentTypes = [UTType.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let destination = url.pathExtension.isEmpty
                ? url.appendingPathExtension("json")
                : url
            try document.exportHistory(to: destination)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}
