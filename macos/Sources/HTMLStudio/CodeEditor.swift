import AppKit
import SwiftUI

@MainActor
final class CodeEditorController: ObservableObject {
    fileprivate weak var textView: NSTextView?

    func undo() {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
        textView.undoManager?.undo()
    }

    func redo() {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
        textView.undoManager?.redo()
    }

    func pastePlainText() {
        guard
            let textView,
            let value = NSPasteboard.general.string(forType: .string)
        else { return }
        textView.window?.makeFirstResponder(textView)
        textView.insertText(value, replacementRange: textView.selectedRange())
    }
}

private final class HTMLCodeTextView: NSTextView {
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu(title: "HTML 源码编辑")
        addResponderItem("撤销", action: Selector(("undo:")), to: menu)
        addResponderItem("重做", action: Selector(("redo:")), to: menu)
        menu.addItem(.separator())
        addResponderItem("剪切", action: #selector(cut(_:)), to: menu)
        addResponderItem("复制", action: #selector(copy(_:)), to: menu)
        addResponderItem("粘贴", action: #selector(paste(_:)), to: menu)

        let plainText = NSMenuItem(
            title: "粘贴为纯文本",
            action: #selector(pasteHTMLStudioPlainText(_:)),
            keyEquivalent: ""
        )
        plainText.target = self
        menu.addItem(plainText)

        addResponderItem("删除", action: #selector(delete(_:)), to: menu)
        menu.addItem(.separator())
        addResponderItem("全选", action: #selector(selectAll(_:)), to: menu)
        return menu
    }

    private func addResponderItem(
        _ title: String,
        action: Selector,
        to menu: NSMenu
    ) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = nil
        menu.addItem(item)
    }

    @objc private func pasteHTMLStudioPlainText(_ sender: Any?) {
        guard let value = NSPasteboard.general.string(forType: .string) else { return }
        insertText(value, replacementRange: selectedRange())
    }
}

struct CodeEditor: NSViewRepresentable {
    @Binding var text: String
    let controller: CodeEditorController
    let onFocus: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

        let textView = HTMLCodeTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = false
        textView.string = text
        SyntaxHighlighter.apply(to: textView)

        scrollView.documentView = textView
        context.coordinator.textView = textView
        controller.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        controller.textView = context.coordinator.textView
        guard let textView = context.coordinator.textView, textView.string != text else {
            return
        }
        context.coordinator.isApplyingExternalChange = true
        let isFirstResponder = textView.window?.firstResponder === textView
        let selection = isFirstResponder ? textView.selectedRanges : []
        textView.string = text
        SyntaxHighlighter.apply(to: textView, preserveSelection: isFirstResponder)
        let textLength = (text as NSString).length
        let safeSelection = selection.compactMap { value -> NSValue? in
            let range = value.rangeValue
            guard range.location != NSNotFound else { return nil }
            let location = min(range.location, textLength)
            let availableLength = max(0, textLength - location)
            let length = min(range.length, availableLength)
            return NSValue(range: NSRange(location: location, length: length))
        }
        if isFirstResponder {
            textView.selectedRanges = safeSelection.isEmpty
                ? [NSValue(range: NSRange(location: textLength, length: 0))]
                : safeSelection
        }
        context.coordinator.isApplyingExternalChange = false
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditor
        weak var textView: NSTextView?
        var isApplyingExternalChange = false

        init(parent: CodeEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingExternalChange, let textView else { return }
            parent.onFocus()
            parent.text = textView.string
            SyntaxHighlighter.apply(to: textView)
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.onFocus()
        }
    }
}

private enum SyntaxHighlighter {
    static func apply(
        to textView: NSTextView,
        preserveSelection: Bool = true
    ) {
        guard let storage = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        let selection = preserveSelection ? textView.selectedRanges : []
        let baseFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        storage.beginEditing()
        storage.setAttributes(
            [
                .font: baseFont,
                .foregroundColor: NSColor.textColor
            ],
            range: fullRange
        )

        color(#"(?s)<!--.*?-->"#, in: storage, color: .systemGreen)
        color(#"(?i)<!doctype[^>]*>"#, in: storage, color: .systemPurple)
        color(#"(?i)</?[a-z][^>]*>"#, in: storage, color: .systemBlue)
        color(#""[^"\n]*"|'[^'\n]*'"#, in: storage, color: .systemOrange)
        color(#"(?i)(?<=<|</)[a-z][a-z0-9:-]*"#, in: storage, color: .systemPink, bold: true)
        storage.endEditing()
        if preserveSelection {
            let textLength = storage.length
            let safeSelection = selection.compactMap { value -> NSValue? in
                let range = value.rangeValue
                guard range.location != NSNotFound else { return nil }
                let location = min(range.location, textLength)
                let availableLength = max(0, textLength - location)
                let length = min(range.length, availableLength)
                return NSValue(range: NSRange(location: location, length: length))
            }
            textView.selectedRanges = safeSelection.isEmpty
                ? [NSValue(range: NSRange(location: textLength, length: 0))]
                : safeSelection
        }
    }

    private static func color(
        _ pattern: String,
        in storage: NSTextStorage,
        color: NSColor,
        bold: Bool = false
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let range = NSRange(location: 0, length: storage.length)
        regex.enumerateMatches(in: storage.string, range: range) { match, _, _ in
            guard let match else { return }
            storage.addAttribute(.foregroundColor, value: color, range: match.range)
            if bold {
                storage.addAttribute(
                    .font,
                    value: NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold),
                    range: match.range
                )
            }
        }
    }
}
