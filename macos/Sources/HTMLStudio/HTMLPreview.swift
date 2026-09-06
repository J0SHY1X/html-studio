import AppKit
import SwiftUI
import WebKit

struct HTMLPreview: NSViewRepresentable {
    let html: String
    let onHTMLChange: (String, String) -> Void
    let baseURL: URL?
    let isEditable: Bool
    let controller: DesignEditorController
    let onFocus: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onHTMLChange: onHTMLChange,
            onFocus: onFocus,
            controller: controller
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.add(
            context.coordinator,
            name: Coordinator.messageHandlerName
        )
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: Self.editorBridgeScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView
        context.coordinator.isEditable = isEditable
        controller.attach(webView)
        controller.loadHTMLImmediately(html, baseURL: baseURL)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let editableStateChanged = context.coordinator.isEditable != isEditable
        context.coordinator.onHTMLChange = onHTMLChange
        context.coordinator.onFocus = onFocus
        context.coordinator.isEditable = isEditable
        controller.attach(webView)
        if editableStateChanged {
            controller.setEditable(isEditable)
        }
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: Coordinator.messageHandlerName
        )
        webView.navigationDelegate = nil
        coordinator.controller.detach(webView)
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        static let messageHandlerName = "htmlStudio"

        var onHTMLChange: (String, String) -> Void
        var onFocus: () -> Void
        let controller: DesignEditorController
        weak var webView: WKWebView?
        var isEditable = true
        private var colorPanelCommand = "foreColor"

        init(
            onHTMLChange: @escaping (String, String) -> Void,
            onFocus: @escaping () -> Void,
            controller: DesignEditorController
        ) {
            self.onHTMLChange = onHTMLChange
            self.onFocus = onFocus
            self.controller = controller
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard
                message.name == Self.messageHandlerName,
                let payload = message.body as? [String: Any],
                let type = payload["type"] as? String
            else {
                return
            }

            switch type {
            case "ready":
                controller.setReady(true)
                controller.setEditable(isEditable)
            case "htmlChanged":
                guard let editedHTML = payload["html"] as? String else { return }
                let action = payload["action"] as? String ?? "编辑可视化页面"
                let shouldRefocus = payload["shouldRefocus"] as? Bool ?? false
                onHTMLChange(editedHTML, action)
                if shouldRefocus {
                    DispatchQueue.main.async { [weak self] in
                        guard let webView = self?.webView else { return }
                        webView.evaluateJavaScript(
                            "window.__HTMLStudioEditor?.refocus()"
                        )
                    }
                }
            case "focus":
                onFocus()
            case "showContextMenu":
                guard
                    let webView,
                    let x = payload["x"] as? Double,
                    let y = payload["y"] as? Double
                else {
                    return
                }
                showContextMenu(in: webView, x: x, y: y)
            case "status":
                if let status = payload["value"] as? String {
                    controller.setStatus(status)
                }
            default:
                break
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            controller.setEditable(isEditable)
        }

        private func showContextMenu(
            in webView: WKWebView,
            x: Double,
            y: Double
        ) {
            let menu = NSMenu(title: "页面编辑")
            addResponderItem("撤销", selector: "undo:", to: menu)
            addResponderItem("重做", selector: "redo:", to: menu)
            menu.addItem(.separator())
            addResponderItem("剪切", selector: "cut:", to: menu)
            addResponderItem("复制", selector: "copy:", to: menu)
            addResponderItem("粘贴", selector: "paste:", to: menu)
            addTargetItem(
                "粘贴为纯文本",
                action: #selector(pastePlainText),
                to: menu
            )
            addResponderItem("删除", selector: "delete:", to: menu)
            addResponderItem("全选", selector: "selectAll:", to: menu)
            menu.addItem(.separator())

            addTargetItem("查找…", action: #selector(showFind), to: menu)
            addTargetItem(
                "查找与替换…",
                action: #selector(showFindAndReplace),
                to: menu
            )
            menu.addItem(.separator())

            let formatMenu = NSMenu(title: "文字格式")
            addCommandItem("粗体", command: "bold", to: formatMenu)
            addCommandItem("斜体", command: "italic", to: formatMenu)
            addCommandItem("下划线", command: "underline", to: formatMenu)
            addCommandItem("删除线", command: "strikeThrough", to: formatMenu)
            formatMenu.addItem(.separator())
            addCommandItem("清除文字格式", command: "removeFormat", to: formatMenu)
            let formatRoot = NSMenuItem(title: "文字格式", action: nil, keyEquivalent: "")
            formatRoot.submenu = formatMenu
            menu.addItem(formatRoot)

            addColorMenu(
                title: "文字颜色",
                command: "foreColor",
                includesTransparent: false,
                to: menu
            )
            addColorMenu(
                title: "背景颜色",
                command: "hiliteColor",
                includesTransparent: true,
                to: menu
            )

            let paragraphMenu = NSMenu(title: "段落")
            addCommandItem("正文", command: "formatBlock", value: "p", to: paragraphMenu)
            addCommandItem("标题 1", command: "formatBlock", value: "h1", to: paragraphMenu)
            addCommandItem("标题 2", command: "formatBlock", value: "h2", to: paragraphMenu)
            addCommandItem("标题 3", command: "formatBlock", value: "h3", to: paragraphMenu)
            paragraphMenu.addItem(.separator())
            addCommandItem("插入新段落", command: "insertParagraph", to: paragraphMenu)
            addCommandItem("项目符号列表", command: "insertUnorderedList", to: paragraphMenu)
            addCommandItem("编号列表", command: "insertOrderedList", to: paragraphMenu)
            let paragraphRoot = NSMenuItem(title: "段落与列表", action: nil, keyEquivalent: "")
            paragraphRoot.submenu = paragraphMenu
            menu.addItem(paragraphRoot)

            let alignmentMenu = NSMenu(title: "对齐")
            addCommandItem("左对齐", command: "justifyLeft", to: alignmentMenu)
            addCommandItem("居中", command: "justifyCenter", to: alignmentMenu)
            addCommandItem("右对齐", command: "justifyRight", to: alignmentMenu)
            addCommandItem("两端对齐", command: "justifyFull", to: alignmentMenu)
            let alignmentRoot = NSMenuItem(title: "对齐方式", action: nil, keyEquivalent: "")
            alignmentRoot.submenu = alignmentMenu
            menu.addItem(alignmentRoot)
            menu.addItem(.separator())

            let duplicate = NSMenuItem(
                title: "复制当前页到后面",
                action: #selector(duplicateCurrentPage),
                keyEquivalent: ""
            )
            duplicate.target = self
            menu.addItem(duplicate)

            let blank = NSMenuItem(
                title: "在当前页后新增空白页",
                action: #selector(insertBlankPage),
                keyEquivalent: ""
            )
            blank.target = self
            menu.addItem(blank)

            let point = NSPoint(
                x: x,
                y: max(0, webView.bounds.height - y)
            )
            menu.popUp(positioning: nil, at: point, in: webView)
        }

        private func addResponderItem(
            _ title: String,
            selector: String,
            to menu: NSMenu
        ) {
            let item = NSMenuItem(
                title: title,
                action: Selector((selector)),
                keyEquivalent: ""
            )
            item.target = nil
            menu.addItem(item)
        }

        private func addTargetItem(
            _ title: String,
            action: Selector,
            to menu: NSMenu
        ) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }

        private func addCommandItem(
            _ title: String,
            command: String,
            value: String? = nil,
            to menu: NSMenu
        ) {
            let item = NSMenuItem(
                title: title,
                action: #selector(executeMenuCommand(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = ["command": command, "value": value ?? ""]
            menu.addItem(item)
        }

        private func addColorMenu(
            title: String,
            command: String,
            includesTransparent: Bool,
            to menu: NSMenu
        ) {
            let submenu = NSMenu(title: title)
            if includesTransparent {
                addCommandItem("无背景色", command: command, value: "transparent", to: submenu)
                submenu.addItem(.separator())
            }
            let colors: [(String, String)] = [
                ("黑色", "#111827"),
                ("深灰", "#4B5563"),
                ("红色", "#DC2626"),
                ("橙色", "#EA580C"),
                ("黄色", "#FACC15"),
                ("绿色", "#16A34A"),
                ("蓝色", "#2563EB"),
                ("紫色", "#7C3AED"),
                ("白色", "#FFFFFF")
            ]
            for (name, hex) in colors {
                addCommandItem(name, command: command, value: hex, to: submenu)
            }
            submenu.addItem(.separator())
            let custom = NSMenuItem(
                title: "更多颜色…",
                action: #selector(showCustomColorPanel(_:)),
                keyEquivalent: ""
            )
            custom.target = self
            custom.representedObject = command
            submenu.addItem(custom)

            let root = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            root.submenu = submenu
            menu.addItem(root)
        }

        @objc private func executeMenuCommand(_ sender: NSMenuItem) {
            guard
                let payload = sender.representedObject as? [String: String],
                let command = payload["command"]
            else { return }
            let value = payload["value"]
            controller.execute(command, value: value?.isEmpty == false ? value : nil)
        }

        @objc private func pastePlainText() {
            controller.pastePlainText()
        }

        @objc private func showFind() {
            NotificationCenter.default.post(name: .htmlStudioFind, object: nil)
        }

        @objc private func showFindAndReplace() {
            NotificationCenter.default.post(name: .htmlStudioFindAndReplace, object: nil)
        }

        @objc private func showCustomColorPanel(_ sender: NSMenuItem) {
            colorPanelCommand = sender.representedObject as? String ?? "foreColor"
            let panel = NSColorPanel.shared
            panel.showsAlpha = colorPanelCommand == "hiliteColor"
            panel.setTarget(self)
            panel.setAction(#selector(applyCustomColor(_:)))
            panel.orderFront(nil)
        }

        @objc private func applyCustomColor(_ sender: NSColorPanel) {
            guard let color = sender.color.usingColorSpace(.sRGB) else { return }
            let red = Int(round(color.redComponent * 255))
            let green = Int(round(color.greenComponent * 255))
            let blue = Int(round(color.blueComponent * 255))
            let alpha = Int(round(color.alphaComponent * 255))
            let value = alpha < 255
                ? String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
                : String(format: "#%02X%02X%02X", red, green, blue)
            controller.execute(colorPanelCommand, value: value)
        }

        @objc private func duplicateCurrentPage() {
            controller.pageAction(.duplicateCurrent)
        }

        @objc private func insertBlankPage() {
            controller.pageAction(.insertBlankAfter)
        }
    }

    private static let editorBridgeScript = #"""
    (() => {
      if (window.__HTMLStudioEditor) {
        window.__HTMLStudioEditor.setEditable(true);
        return;
      }

      const handler = window.webkit?.messageHandlers?.htmlStudio;
      const post = (payload) => handler?.postMessage(payload);
      const commandNames = {
        bold: '设置粗体',
        italic: '设置斜体',
        underline: '设置下划线',
        strikeThrough: '设置删除线',
        undo: '撤销',
        redo: '重做',
        insertParagraph: '插入段落',
        justifyLeft: '左对齐',
        justifyCenter: '居中',
        justifyRight: '右对齐',
        justifyFull: '两端对齐',
        insertUnorderedList: '设置项目符号列表',
        insertOrderedList: '设置编号列表',
        outdent: '减少缩进',
        indent: '增加缩进',
        createLink: '插入链接',
        unlink: '移除链接',
        insertImage: '插入图片',
        insertHorizontalRule: '插入分隔线',
        removeFormat: '清除格式',
        fontName: '修改字体',
        foreColor: '修改文字颜色',
        hiliteColor: '修改文字底色',
        formatBlock: '修改段落样式'
      };
      const inputNames = {
        deleteByCut: '剪切内容',
        insertFromPaste: '粘贴内容',
        historyUndo: '撤销',
        historyRedo: '重做',
        deleteContentBackward: '删除内容',
        deleteContentForward: '删除内容',
        deleteByDrag: '移动内容',
        insertFromDrop: '移动内容',
        insertParagraph: '插入段落',
        insertLineBreak: '插入换行'
      };

      const editor = {
        editable: true,
        savedRange: null,
        changeTimer: null,
        pendingAction: null,
        compositionAction: null,
        isComposing: false,
        activePage: null,
        findState: { key: '', matches: [], currentIndex: -1 },
        pageSelector: '[data-slide], [data-page], [data-page-number], .slide, .page, .html-studio-page',

        body() {
          return document.body || document.documentElement;
        },

        isRangeValid(range) {
          if (!range) return false;
          try {
            const root = this.body();
            return !!range.startContainer?.isConnected &&
              !!range.endContainer?.isConnected &&
              root.contains(range.startContainer) &&
              root.contains(range.endContainer);
          } catch (_) {
            return false;
          }
        },

        placeCaretAtEnd(target = null) {
          const root = target && target.isConnected ? target : this.body();
          const range = document.createRange();
          range.selectNodeContents(root);
          range.collapse(false);
          const selection = window.getSelection();
          selection.removeAllRanges();
          selection.addRange(range);
          this.savedRange = range.cloneRange();
          return range;
        },

        saveSelection() {
          if (this.isComposing) return;
          const selection = window.getSelection();
          if (!selection || selection.rangeCount === 0) return;
          const range = selection.getRangeAt(0);
          if (this.isRangeValid(range)) {
            this.savedRange = range.cloneRange();
            this.markActivePage(range.startContainer);
          }
        },

        restoreSelection() {
          const selection = window.getSelection();
          if (!selection) return false;
          if (!this.isRangeValid(this.savedRange)) {
            this.savedRange = null;
            this.placeCaretAtEnd(this.activePage);
            return false;
          }
          try {
            selection.removeAllRanges();
            selection.addRange(this.savedRange);
            return true;
          } catch (_) {
            this.savedRange = null;
            this.placeCaretAtEnd(this.activePage);
            return false;
          }
        },

        repairSelection() {
          if (this.isComposing) return;
          const selection = window.getSelection();
          if (selection?.rangeCount && this.isRangeValid(selection.getRangeAt(0))) {
            this.savedRange = selection.getRangeAt(0).cloneRange();
            return;
          }
          this.savedRange = null;
          this.placeCaretAtEnd(this.activePage);
        },

        refocus() {
          if (!this.editable || this.isComposing) return false;
          const body = this.body();
          body.contentEditable = 'true';
          body.focus({ preventScroll: true });
          this.restoreSelection();
          return true;
        },

        snapshot() {
          const clone = document.documentElement.cloneNode(true);
          clone.querySelectorAll('[data-html-studio-ui]').forEach((node) => node.remove());
          clone.querySelectorAll('[data-html-studio-active-page]').forEach((node) => {
            node.removeAttribute('data-html-studio-active-page');
          });
          const body = clone.querySelector('body');
          if (body) {
            body.removeAttribute('contenteditable');
            body.removeAttribute('spellcheck');
            body.removeAttribute('data-html-studio-editing');
          }
          let doctype = '<!doctype html>';
          if (document.doctype) {
            doctype = '<!DOCTYPE ' + document.doctype.name + '>';
          }
          return doctype + '\n' + clone.outerHTML;
        },

        notifyChange(action = '编辑可视化页面', shouldRefocus = false) {
          if (this.isComposing) {
            this.compositionAction = action || this.compositionAction || '输入组合文字';
            return;
          }
          clearTimeout(this.changeTimer);
          const nextAction = action || '编辑可视化页面';
          this.changeTimer = setTimeout(() => {
            post({
              type: 'htmlChanged',
              action: nextAction,
              shouldRefocus: !!shouldRefocus,
              html: this.snapshot()
            });
          }, 120);
        },

        installEditingStyle() {
          if (document.querySelector('[data-html-studio-ui="editing-style"]')) return;
          const style = document.createElement('style');
          style.dataset.htmlStudioUi = 'editing-style';
          style.textContent = `
            body[data-html-studio-editing="true"] {
              min-height: 100vh !important;
              cursor: text;
            }
            body[data-html-studio-editing="true"] *:hover {
              outline: 1px dashed rgba(59, 130, 246, .28);
              outline-offset: 2px;
            }
            body[data-html-studio-editing="true"] [data-html-studio-active-page] {
              outline: 2px dashed rgba(37, 99, 235, .52) !important;
              outline-offset: 4px !important;
            }
            body[data-html-studio-editing="true"] table {
              cursor: text;
            }
            body[data-html-studio-editing="true"] td,
            body[data-html-studio-editing="true"] th {
              min-width: 28px;
              min-height: 20px;
            }
            body[data-html-studio-editing="true"]:focus {
              outline: none;
            }
          `;
          (document.head || document.documentElement).appendChild(style);
        },

        setEditable(enabled) {
          const nextEditable = !!enabled;
          this.installEditingStyle();
          const body = this.body();
          const editableStateChanged =
            this.editable !== nextEditable ||
            body.isContentEditable !== nextEditable;
          this.editable = nextEditable;
          body.contentEditable = this.editable ? 'true' : 'false';
          body.spellcheck = this.editable;
          body.dataset.htmlStudioEditing = this.editable ? 'true' : 'false';
          if (this.editable && editableStateChanged) {
            document.execCommand('styleWithCSS', false, true);
            this.repairSelection();
          }
          post({
            type: 'status',
            value: this.editable ? '可直接编辑页面内容' : '交互预览模式'
          });
        },

        prepareCommand() {
          if (!this.editable) return false;
          const body = this.body();
          body.contentEditable = 'true';
          body.focus({ preventScroll: true });
          this.restoreSelection();
          document.execCommand('styleWithCSS', false, true);
          return true;
        },

        finishCommand(action) {
          requestAnimationFrame(() => {
            this.repairSelection();
            this.notifyChange(action, true);
          });
        },

        exec(command, value) {
          if (!this.prepareCommand()) return false;
          let result = false;
          try {
            result = document.execCommand(command, false, value ?? null);
          } finally {
            this.finishCommand(commandNames[command] || '执行编辑命令');
          }
          return result;
        },

        pastePlainText(value) {
          if (!this.prepareCommand()) return false;
          const text = String(value ?? '');
          let result = document.execCommand('insertText', false, text);
          if (!result) {
            const selection = window.getSelection();
            const range = selection?.rangeCount ? selection.getRangeAt(0) : null;
            if (range && this.isRangeValid(range)) {
              range.deleteContents();
              const node = document.createTextNode(text);
              range.insertNode(node);
              range.setStartAfter(node);
              range.collapse(true);
              selection.removeAllRanges();
              selection.addRange(range);
              this.savedRange = range.cloneRange();
              result = true;
            }
          }
          this.finishCommand('粘贴为纯文本');
          return result;
        },

        setFontSize(pixelSize) {
          if (!this.prepareCommand()) return;
          document.execCommand('fontSize', false, '7');
          document.querySelectorAll('font[size="7"]').forEach((font) => {
            font.removeAttribute('size');
            font.style.fontSize = String(pixelSize) + 'px';
          });
          this.finishCommand('修改字号');
        },

        insertTable(rows, columns) {
          if (!this.prepareCommand()) return;
          const rowCount = Math.max(1, Math.min(20, Number(rows) || 2));
          const columnCount = Math.max(1, Math.min(12, Number(columns) || 2));
          const cell = '<td style="border:1px solid #cbd5e1;padding:8px;min-width:48px"><br></td>';
          let tableRows = '';
          for (let r = 0; r < rowCount; r += 1) {
            tableRows += '<tr>' + cell.repeat(columnCount) + '</tr>';
          }
          const holder = document.createElement('div');
          holder.innerHTML = '<table style="border-collapse:collapse;width:100%;margin:1em 0"><tbody>' +
            tableRows + '</tbody></table>';
          const table = holder.firstElementChild;
          const trailingParagraph = document.createElement('p');
          trailingParagraph.innerHTML = '<br>';

          const selection = window.getSelection();
          let node = selection?.anchorNode || this.body();
          if (node.nodeType === Node.TEXT_NODE) node = node.parentElement;
          const anchor = node.closest?.(
            'table,p,h1,h2,h3,h4,h5,h6,blockquote,pre,ul,ol,section,article'
          );
          if (!anchor || anchor === this.body()) {
            this.body().append(table, trailingParagraph);
          } else {
            anchor.after(table, trailingParagraph);
          }

          const firstCell = table.querySelector('td,th');
          if (firstCell) {
            const range = document.createRange();
            range.selectNodeContents(firstCell);
            range.collapse(true);
            const newSelection = window.getSelection();
            newSelection.removeAllRanges();
            newSelection.addRange(range);
            this.savedRange = range.cloneRange();
          }
          this.finishCommand(`插入 ${rowCount} × ${columnCount} 表格`);
        },

        currentCell() {
          this.restoreSelection();
          const selection = window.getSelection();
          if (!selection || selection.rangeCount === 0) return null;
          let node = selection.anchorNode;
          if (node?.nodeType === Node.TEXT_NODE) node = node.parentElement;
          return node?.closest?.('td,th') || null;
        },

        emptyCellLike(cell) {
          const replacement = document.createElement(cell.tagName.toLowerCase());
          for (const attribute of cell.attributes) {
            replacement.setAttribute(attribute.name, attribute.value);
          }
          replacement.innerHTML = '<br>';
          return replacement;
        },

        tableAction(action) {
          if (!this.prepareCommand()) return false;
          const cell = this.currentCell();
          const row = cell?.closest('tr');
          const table = cell?.closest('table');
          if (!cell || !row || !table) {
            post({ type: 'status', value: '请先把光标放入表格单元格' });
            return false;
          }

          const names = {
            addRowBefore: '在上方添加表格行',
            addRowAfter: '在下方添加表格行',
            addColumnBefore: '在左侧添加表格列',
            addColumnAfter: '在右侧添加表格列',
            deleteRow: '删除表格行',
            deleteColumn: '删除表格列',
            toggleHeader: '切换表头',
            deleteTable: '删除表格'
          };
          const cellIndex = Array.from(row.cells).indexOf(cell);
          if (action === 'addRowBefore' || action === 'addRowAfter') {
            const newRow = document.createElement('tr');
            Array.from(row.cells).forEach((sourceCell) => {
              newRow.appendChild(this.emptyCellLike(sourceCell));
            });
            row.parentNode.insertBefore(
              newRow,
              action === 'addRowBefore' ? row : row.nextSibling
            );
          } else if (action === 'addColumnBefore' || action === 'addColumnAfter') {
            const insertionOffset = action === 'addColumnAfter' ? 1 : 0;
            Array.from(table.rows).forEach((targetRow) => {
              const reference = targetRow.cells[Math.min(cellIndex, targetRow.cells.length - 1)];
              const newCell = this.emptyCellLike(reference || cell);
              const insertionIndex = Math.min(cellIndex + insertionOffset, targetRow.cells.length);
              if (insertionIndex >= targetRow.cells.length) {
                targetRow.appendChild(newCell);
              } else {
                targetRow.insertBefore(newCell, targetRow.cells[insertionIndex]);
              }
            });
          } else if (action === 'deleteRow') {
            row.remove();
            if (table.rows.length === 0) table.remove();
          } else if (action === 'deleteColumn') {
            Array.from(table.rows).forEach((targetRow) => {
              targetRow.cells[cellIndex]?.remove();
            });
            if (table.rows.length === 0 || table.rows[0].cells.length === 0) {
              table.remove();
            }
          } else if (action === 'toggleHeader') {
            const firstRow = table.rows[0];
            const makeHeader = Array.from(firstRow.cells).some((item) => item.tagName !== 'TH');
            Array.from(firstRow.cells).forEach((oldCell) => {
              const newCell = document.createElement(makeHeader ? 'th' : 'td');
              for (const attribute of oldCell.attributes) {
                newCell.setAttribute(attribute.name, attribute.value);
              }
              newCell.innerHTML = oldCell.innerHTML;
              oldCell.replaceWith(newCell);
            });
          } else if (action === 'deleteTable') {
            table.remove();
          } else {
            return false;
          }

          this.finishCommand(names[action] || '修改表格');
          return true;
        },

        pageElements() {
          return Array.from(document.querySelectorAll(this.pageSelector)).filter((page) => {
            const parentPage = page.parentElement?.closest?.(this.pageSelector);
            return !parentPage;
          });
        },

        ensurePageStructure() {
          const existing = this.pageElements();
          if (existing.length) return existing;

          const section = document.createElement('section');
          section.className = 'html-studio-page';
          section.dataset.page = '1';
          const nodes = Array.from(this.body().childNodes).filter((node) => {
            return !(node.nodeType === Node.ELEMENT_NODE &&
              ['SCRIPT', 'STYLE'].includes(node.tagName));
          });
          nodes.forEach((node) => section.appendChild(node));
          this.body().insertBefore(section, this.body().firstChild);
          return [section];
        },

        markActivePage(node) {
          let element = node;
          if (element?.nodeType === Node.TEXT_NODE) element = element.parentElement;
          const pages = this.pageElements();
          const page = element?.closest?.(this.pageSelector) || this.activePage || pages[0];
          if (!page || !page.isConnected) return null;
          document.querySelectorAll('[data-html-studio-active-page]').forEach((item) => {
            item.removeAttribute('data-html-studio-active-page');
          });
          page.setAttribute('data-html-studio-active-page', 'true');
          this.activePage = page;
          return page;
        },

        currentPage() {
          let pages = this.pageElements();
          if (!pages.length) pages = this.ensurePageStructure();
          const selection = window.getSelection();
          const fromSelection = selection?.rangeCount
            ? this.markActivePage(selection.getRangeAt(0).startContainer)
            : null;
          return fromSelection || this.markActivePage(this.activePage) || pages[0] || null;
        },

        sanitizeClonedIDs(clone) {
          const suffix = '-copy-' + Date.now().toString(36);
          [clone, ...clone.querySelectorAll('[id]')].forEach((node) => {
            if (!node.id) return;
            node.id += suffix;
          });
          clone.querySelectorAll('[data-html-studio-active-page]').forEach((node) => {
            node.removeAttribute('data-html-studio-active-page');
          });
        },

        renumberPages() {
          const pages = this.pageElements();
          pages.forEach((page, index) => {
            const number = index + 1;
            if (page.hasAttribute('data-slide')) page.dataset.slide = String(number);
            if (page.hasAttribute('data-page-number')) {
              page.dataset.pageNumber = String(number);
            }
            if (page.hasAttribute('data-page') &&
                /^\d*$/.test(page.getAttribute('data-page') || '')) {
              page.dataset.page = String(number);
            }
            if (/^(slide|page)-\d+(?:-copy-[a-z0-9]+)?$/i.test(page.id)) {
              page.id = 'slide-' + number;
            }
            const label = page.querySelector(
              '.slide-no, .page-no, .page-number, [data-page-label]'
            );
            if (label && /^第\s*\d+\s*页$/.test(label.textContent.trim())) {
              label.textContent = `第${number}页`;
            }
          });

          const toc = document.querySelector('#toc');
          if (toc && pages.every((page) => page.id)) {
            toc.replaceChildren(...pages.map((page, index) => {
              const link = document.createElement('a');
              const title = page.querySelector('h1,h2,h3')?.textContent?.trim() || '未命名页面';
              link.href = '#' + page.id;
              link.textContent = `${index + 1}｜${title}`;
              return link;
            }));
          }
          return pages;
        },

        duplicateCurrentPage() {
          if (!this.editable) return false;
          const page = this.currentPage();
          if (!page) {
            post({ type: 'status', value: '未找到可复制的页面' });
            return false;
          }
          const clone = page.cloneNode(true);
          this.sanitizeClonedIDs(clone);
          page.after(clone);
          const pages = this.renumberPages();
          const number = pages.indexOf(clone) + 1;
          this.markActivePage(clone);
          clone.scrollIntoView({ behavior: 'smooth', block: 'start' });
          this.placeCaretAtEnd(clone);
          this.notifyChange(`复制页面并新增第 ${number} 页`, true);
          post({ type: 'status', value: `已复制为第 ${number} 页，可直接修改内容` });
          return true;
        },

        insertBlankPage() {
          if (!this.editable) return false;
          const page = this.currentPage();
          if (!page) return false;

          const blank = document.createElement(page.tagName.toLowerCase());
          for (const attribute of page.attributes) {
            if (attribute.name === 'id' ||
                attribute.name === 'data-html-studio-active-page') continue;
            blank.setAttribute(attribute.name, attribute.value);
          }

          if (page.matches('.slide, [data-slide]')) {
            blank.innerHTML = `
              <div class="slide-head">
                <span class="slide-no">第0页</span>
                <span class="time"></span>
              </div>
              <h2>新页面</h2>
              <div class="script"><p><br></p></div>
            `;
          } else {
            blank.innerHTML = '<h2>新页面</h2><p><br></p>';
          }

          page.after(blank);
          const pages = this.renumberPages();
          const number = pages.indexOf(blank) + 1;
          this.markActivePage(blank);
          blank.scrollIntoView({ behavior: 'smooth', block: 'start' });
          const editableBlock = blank.querySelector('h1,h2,h3,p') || blank;
          const range = document.createRange();
          range.selectNodeContents(editableBlock);
          const selection = window.getSelection();
          selection.removeAllRanges();
          selection.addRange(range);
          this.savedRange = range.cloneRange();
          this.notifyChange(`新增空白第 ${number} 页`, true);
          post({ type: 'status', value: `已新增第 ${number} 页` });
          return true;
        },

        pageAction(action) {
          if (action === 'duplicateCurrent') return this.duplicateCurrentPage();
          if (action === 'insertBlankAfter') return this.insertBlankPage();
          return false;
        },

        findKey(query, matchCase) {
          return (matchCase ? '1:' : '0:') + String(query ?? '');
        },

        searchableTextNodes() {
          const nodes = [];
          const walker = document.createTreeWalker(
            this.body(),
            NodeFilter.SHOW_TEXT,
            {
              acceptNode: (node) => {
                if (!node.nodeValue || !node.nodeValue.length) {
                  return NodeFilter.FILTER_REJECT;
                }
                const parent = node.parentElement;
                if (!parent || parent.closest(
                  'script,style,noscript,textarea,[data-html-studio-ui]'
                )) {
                  return NodeFilter.FILTER_REJECT;
                }
                const style = window.getComputedStyle(parent);
                if (style.display === 'none' || style.visibility === 'hidden') {
                  return NodeFilter.FILTER_REJECT;
                }
                return NodeFilter.FILTER_ACCEPT;
              }
            }
          );
          let node = walker.nextNode();
          while (node) {
            nodes.push(node);
            node = walker.nextNode();
          }
          return nodes;
        },

        buildFindMatches(query, matchCase) {
          const needle = String(query ?? '');
          if (!needle) return [];
          const comparableNeedle = matchCase ? needle : needle.toLocaleLowerCase();
          const matches = [];
          this.searchableTextNodes().forEach((node) => {
            const source = matchCase ? node.nodeValue : node.nodeValue.toLocaleLowerCase();
            let offset = 0;
            while (offset <= source.length - comparableNeedle.length) {
              const index = source.indexOf(comparableNeedle, offset);
              if (index < 0) break;
              matches.push({ node, start: index, end: index + needle.length });
              offset = index + Math.max(1, comparableNeedle.length);
            }
          });
          return matches;
        },

        selectFindMatch(index) {
          const match = this.findState.matches[index];
          if (!match?.node?.isConnected) return false;
          const range = document.createRange();
          range.setStart(match.node, match.start);
          range.setEnd(match.node, match.end);
          const selection = window.getSelection();
          selection.removeAllRanges();
          selection.addRange(range);
          this.savedRange = range.cloneRange();
          this.markActivePage(match.node);
          match.node.parentElement?.scrollIntoView({
            behavior: 'smooth',
            block: 'center',
            inline: 'nearest'
          });
          return true;
        },

        find(query, matchCase, backwards = false, reset = false) {
          const needle = String(query ?? '');
          if (!needle) {
            this.clearFind();
            return { current: 0, total: 0, replaced: 0 };
          }
          const key = this.findKey(needle, !!matchCase);
          const sameSearch = key === this.findState.key;
          const previousIndex = this.findState.currentIndex;
          const matches = this.buildFindMatches(needle, !!matchCase);
          this.findState = { key, matches, currentIndex: -1 };
          if (!matches.length) return { current: 0, total: 0, replaced: 0 };

          let index;
          if (!reset && sameSearch && previousIndex >= 0) {
            index = backwards
              ? (previousIndex - 1 + matches.length) % matches.length
              : (previousIndex + 1) % matches.length;
          } else {
            index = backwards ? matches.length - 1 : 0;
          }
          this.findState.currentIndex = index;
          this.selectFindMatch(index);
          return { current: index + 1, total: matches.length, replaced: 0 };
        },

        replaceCurrent(query, replacement, matchCase) {
          if (!this.editable || this.isComposing) {
            return { current: 0, total: 0, replaced: 0 };
          }
          const needle = String(query ?? '');
          if (!needle) return { current: 0, total: 0, replaced: 0 };
          const key = this.findKey(needle, !!matchCase);
          const previousIndex = key === this.findState.key
            ? this.findState.currentIndex
            : 0;
          const matches = this.buildFindMatches(needle, !!matchCase);
          if (!matches.length) {
            this.findState = { key, matches: [], currentIndex: -1 };
            return { current: 0, total: 0, replaced: 0 };
          }
          const index = Math.max(0, Math.min(previousIndex, matches.length - 1));
          const match = matches[index];
          const value = String(replacement ?? '');
          match.node.replaceData(match.start, match.end - match.start, value);
          const range = document.createRange();
          range.setStart(match.node, match.start + value.length);
          range.collapse(true);
          const selection = window.getSelection();
          selection.removeAllRanges();
          selection.addRange(range);
          this.savedRange = range.cloneRange();

          const remaining = this.buildFindMatches(needle, !!matchCase);
          this.findState = { key, matches: remaining, currentIndex: -1 };
          if (remaining.length) {
            this.findState.currentIndex = Math.min(index, remaining.length - 1);
            this.selectFindMatch(this.findState.currentIndex);
          }
          this.notifyChange('替换页面文字', false);
          return {
            current: this.findState.currentIndex + 1,
            total: remaining.length,
            replaced: 1
          };
        },

        replaceAll(query, replacement, matchCase) {
          if (!this.editable || this.isComposing) {
            return { current: 0, total: 0, replaced: 0 };
          }
          const needle = String(query ?? '');
          if (!needle) return { current: 0, total: 0, replaced: 0 };
          const matches = this.buildFindMatches(needle, !!matchCase);
          if (!matches.length) {
            this.findState = {
              key: this.findKey(needle, !!matchCase),
              matches: [],
              currentIndex: -1
            };
            return { current: 0, total: 0, replaced: 0 };
          }
          const value = String(replacement ?? '');
          [...matches].reverse().forEach((match) => {
            match.node.replaceData(match.start, match.end - match.start, value);
          });
          const remaining = this.buildFindMatches(needle, !!matchCase);
          this.findState = {
            key: this.findKey(needle, !!matchCase),
            matches: remaining,
            currentIndex: -1
          };
          this.notifyChange(`全部替换页面文字（${matches.length} 处）`, false);
          return { current: 0, total: remaining.length, replaced: matches.length };
        },

        clearFind() {
          this.findState = { key: '', matches: [], currentIndex: -1 };
          return true;
        }
      };

      document.addEventListener('selectionchange', () => editor.saveSelection());
      document.addEventListener('compositionstart', () => {
        editor.isComposing = true;
        editor.compositionAction = editor.pendingAction || '输入组合文字';
        clearTimeout(editor.changeTimer);
        editor.changeTimer = null;
      }, true);
      document.addEventListener('compositionupdate', () => {
        editor.isComposing = true;
      }, true);
      document.addEventListener('compositionend', () => {
        const action = editor.compositionAction || '输入组合文字';
        editor.isComposing = false;
        editor.compositionAction = null;
        editor.pendingAction = null;
        requestAnimationFrame(() => {
          editor.repairSelection();
          editor.notifyChange(action, false);
        });
      }, true);
      document.addEventListener('beforeinput', (event) => {
        editor.pendingAction = inputNames[event.inputType] ||
          (event.inputType?.startsWith('delete') ? '删除内容' : '编辑页面文字');
      }, true);
      document.addEventListener('input', (event) => {
        const action = editor.pendingAction || inputNames[event.inputType] || '编辑页面文字';
        if (event.isComposing ||
            editor.isComposing ||
            event.inputType === 'insertCompositionText') {
          editor.compositionAction = action || editor.compositionAction || '输入组合文字';
          return;
        }
        editor.pendingAction = null;
        requestAnimationFrame(() => {
          editor.repairSelection();
          editor.notifyChange(action, false);
        });
      }, true);
      document.addEventListener('cut', () => {
        editor.pendingAction = '剪切内容';
        editor.savedRange = null;
        requestAnimationFrame(() => editor.repairSelection());
      }, true);
      document.addEventListener('paste', () => {
        editor.pendingAction = '粘贴内容';
      }, true);
      document.addEventListener('contextmenu', (event) => {
        editor.saveSelection();
        event.preventDefault();
        event.stopPropagation();
        post({
          type: 'showContextMenu',
          x: event.clientX,
          y: event.clientY
        });
      }, true);
      document.addEventListener('pointerdown', (event) => {
        post({ type: 'focus' });
        editor.markActivePage(event.target);
      }, true);
      document.addEventListener('focusin', () => {
        post({ type: 'focus' });
      }, true);
      document.addEventListener('blur', () => editor.saveSelection(), true);
      document.addEventListener('click', (event) => {
        if (editor.editable && event.target.closest?.('a')) {
          event.preventDefault();
        }
      }, true);

      window.__HTMLStudioEditor = editor;
      editor.setEditable(true);
      post({ type: 'ready' });
    })();
    """#
}
