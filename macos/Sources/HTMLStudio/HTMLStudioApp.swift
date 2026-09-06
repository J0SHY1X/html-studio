import AppKit
import SwiftUI

extension Notification.Name {
    static let htmlStudioNewDocument = Notification.Name("HTMLStudio.newDocument")
    static let htmlStudioOpenDocument = Notification.Name("HTMLStudio.openDocument")
    static let htmlStudioOpenExternalFiles = Notification.Name("HTMLStudio.openExternalFiles")
    static let htmlStudioSaveDocument = Notification.Name("HTMLStudio.saveDocument")
    static let htmlStudioSaveDocumentAs = Notification.Name("HTMLStudio.saveDocumentAs")
    static let htmlStudioExportMarkdown = Notification.Name("HTMLStudio.exportMarkdown")
    static let htmlStudioExportDOCX = Notification.Name("HTMLStudio.exportDOCX")
    static let htmlStudioExportPDF = Notification.Name("HTMLStudio.exportPDF")
    static let htmlStudioPrint = Notification.Name("HTMLStudio.print")
    static let htmlStudioShowHistory = Notification.Name("HTMLStudio.showHistory")
    static let htmlStudioUndo = Notification.Name("HTMLStudio.undo")
    static let htmlStudioRedo = Notification.Name("HTMLStudio.redo")
    static let htmlStudioPastePlainText = Notification.Name("HTMLStudio.pastePlainText")
    static let htmlStudioFind = Notification.Name("HTMLStudio.find")
    static let htmlStudioFindAndReplace = Notification.Name("HTMLStudio.findAndReplace")
    static let htmlStudioFindNext = Notification.Name("HTMLStudio.findNext")
    static let htmlStudioFindPrevious = Notification.Name("HTMLStudio.findPrevious")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        NotificationCenter.default.post(
            name: .htmlStudioOpenExternalFiles,
            object: nil,
            userInfo: ["urls": urls]
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct HTMLStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("撤销") {
                    NotificationCenter.default.post(name: .htmlStudioUndo, object: nil)
                }
                .keyboardShortcut("z", modifiers: [.command])

                Button("重做") {
                    NotificationCenter.default.post(name: .htmlStudioRedo, object: nil)
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }

            CommandGroup(after: .pasteboard) {
                Button("粘贴为纯文本") {
                    NotificationCenter.default.post(
                        name: .htmlStudioPastePlainText,
                        object: nil
                    )
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
            }

            CommandMenu("查找") {
                Button("查找…") {
                    NotificationCenter.default.post(name: .htmlStudioFind, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command])

                Button("查找与替换…") {
                    NotificationCenter.default.post(
                        name: .htmlStudioFindAndReplace,
                        object: nil
                    )
                }
                .keyboardShortcut("f", modifiers: [.command, .option])

                Divider()

                Button("查找下一个") {
                    NotificationCenter.default.post(name: .htmlStudioFindNext, object: nil)
                }
                .keyboardShortcut("g", modifiers: [.command])

                Button("查找上一个") {
                    NotificationCenter.default.post(name: .htmlStudioFindPrevious, object: nil)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .newItem) {
                Button("新建 HTML") {
                    NotificationCenter.default.post(name: .htmlStudioNewDocument, object: nil)
                }
                .keyboardShortcut("n")

                Button("打开…") {
                    NotificationCenter.default.post(name: .htmlStudioOpenDocument, object: nil)
                }
                .keyboardShortcut("o")

                Divider()

                Button("保存") {
                    NotificationCenter.default.post(name: .htmlStudioSaveDocument, object: nil)
                }
                .keyboardShortcut("s")

                Button("另存为…") {
                    NotificationCenter.default.post(name: .htmlStudioSaveDocumentAs, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .printItem) {
                Button("打印…") {
                    NotificationCenter.default.post(name: .htmlStudioPrint, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command])
            }

            CommandMenu("转换") {
                Button("导出为 Markdown…") {
                    NotificationCenter.default.post(name: .htmlStudioExportMarkdown, object: nil)
                }
                .keyboardShortcut("m", modifiers: [.command, .option])

                Button("导出为 Word (.docx)…") {
                    NotificationCenter.default.post(name: .htmlStudioExportDOCX, object: nil)
                }
                .keyboardShortcut("w", modifiers: [.command, .option])

                Button("导出为 PDF…") {
                    NotificationCenter.default.post(name: .htmlStudioExportPDF, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .option])
            }

            CommandMenu("历史") {
                Button("显示修改历史") {
                    NotificationCenter.default.post(
                        name: .htmlStudioShowHistory,
                        object: nil
                    )
                }
                .keyboardShortcut("h", modifiers: [.command, .option])
            }
        }
    }
}
