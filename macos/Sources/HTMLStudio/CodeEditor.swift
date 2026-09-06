import AppKit
import SwiftUI

struct EditorFindResult: Equatable {
    let current: Int
    let total: Int
    let replaced: Int

    static let empty = EditorFindResult(current: 0, total: 0, replaced: 0)
}

@MainActor
final class CodeEditorController: ObservableObject {
    fileprivate weak var textView: NSTextView?
    private var lastFindKey = ""
    private var currentFindRange: NSRange?

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

    func find(
        _ query: String,
        matchCase: Bool,
        backwards: Bool = false,
        reset: Bool = false
    ) -> EditorFindResult {
        guard let textView, !query.isEmpty else {
            clearFind()
            return .empty
        }

        let matches = findRanges(query, in: textView.string, matchCase: matchCase)
        guard !matches.isEmpty else {
            currentFindRange = nil
            lastFindKey = findKey(query, matchCase: matchCase)
            return .empty
        }

        let key = findKey(query, matchCase: matchCase)
        let currentIndex = currentFindRange.flatMap { current in
            matches.firstIndex(where: { NSEqualRanges($0, current) })
        }
        let nextIndex: Int
        if !reset, key == lastFindKey, let currentIndex {
            nextIndex = backwards
                ? (currentIndex - 1 + matches.count) % matches.count
                : (currentIndex + 1) % matches.count
        } else if backwards {
            let caret = textView.selectedRange().location
            nextIndex = matches.lastIndex(where: { $0.location < caret }) ?? (matches.count - 1)
        } else {
            let caret = textView.selectedRange().location
            nextIndex = matches.firstIndex(where: { $0.location >= caret }) ?? 0
        }

        let range = matches[nextIndex]
        lastFindKey = key
        currentFindRange = range
        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
        return EditorFindResult(current: nextIndex + 1, total: matches.count, replaced: 0)
    }

    func replaceCurrent(
        query: String,
        replacement: String,
        matchCase: Bool
    ) -> EditorFindResult {
        guard let textView, !query.isEmpty else { return .empty }
        let matches = findRanges(query, in: textView.string, matchCase: matchCase)
        guard !matches.isEmpty else {
            currentFindRange = nil
            return .empty
        }

        let selected = textView.selectedRange()
        let target = matches.first(where: { NSEqualRanges($0, selected) })
            ?? currentFindRange.flatMap { current in
                matches.first(where: { NSEqualRanges($0, current) })
            }
            ?? matches[0]
        textView.window?.makeFirstResponder(textView)
        textView.insertText(replacement, replacementRange: target)
        currentFindRange = nil
        lastFindKey = ""
        var result = find(query, matchCase: matchCase, reset: true)
        result = EditorFindResult(
            current: result.current,
            total: result.total,
            replaced: 1
        )
        return result
    }

    func replaceAll(
        query: String,
        replacement: String,
        matchCase: Bool
    ) -> EditorFindResult {
        guard let textView, !query.isEmpty else { return .empty }
        let matches = findRanges(query, in: textView.string, matchCase: matchCase)
        guard !matches.isEmpty else { return .empty }

        let mutable = NSMutableString(string: textView.string)
        for range in matches.reversed() {
            mutable.replaceCharacters(in: range, with: replacement)
        }
        textView.window?.makeFirstResponder(textView)
        textView.insertText(
            mutable as String,
            replacementRange: NSRange(location: 0, length: (textView.string as NSString).length)
        )
        currentFindRange = nil
        lastFindKey = ""
        let remaining = findRanges(query, in: textView.string, matchCase: matchCase).count
        return EditorFindResult(current: 0, total: remaining, replaced: matches.count)
    }

    func clearFind() {
        lastFindKey = ""
        currentFindRange = nil
    }

    private func findKey(_ query: String, matchCase: Bool) -> String {
        "\(matchCase ? "1" : "0"):\(query)"
    }

    private func findRanges(
        _ query: String,
        in source: String,
        matchCase: Bool
    ) -> [NSRange] {
        let text = source as NSString
        let needleLength = (query as NSString).length
        guard needleLength > 0, text.length >= needleLength else { return [] }
        let options: NSString.CompareOptions = matchCase ? [] : [.caseInsensitive]
        var ranges: [NSRange] = []
        var location = 0
        while location <= text.length - needleLength {
            let searchRange = NSRange(location: location, length: text.length - location)
            let match = text.range(of: query, options: options, range: searchRange)
            guard match.location != NSNotFound else { break }
            ranges.append(match)
            location = match.location + max(1, match.length)
        }
        return ranges
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
        menu.addItem(.separator())

        let find = NSMenuItem(
            title: "查找…",
            action: #selector(showHTMLStudioFind(_:)),
            keyEquivalent: ""
        )
        find.target = self
        menu.addItem(find)

        let replace = NSMenuItem(
            title: "查找与替换…",
            action: #selector(showHTMLStudioFindAndReplace(_:)),
            keyEquivalent: ""
        )
        replace.target = self
        menu.addItem(replace)
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

    @objc private func showHTMLStudioFind(_ sender: Any?) {
        NotificationCenter.default.post(name: .htmlStudioFind, object: nil)
    }

    @objc private func showHTMLStudioFindAndReplace(_ sender: Any?) {
        NotificationCenter.default.post(name: .htmlStudioFindAndReplace, object: nil)
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
