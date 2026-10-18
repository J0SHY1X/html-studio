import Foundation

enum HTMLComponentKind: String, CaseIterable, Identifiable {
    case link, button, image, text, heading, card, columns, quote, divider, details, input, list
    var id: String { rawValue }
    var name: String {
        switch self {
        case .link: return "链接"
        case .button: return "按钮"
        case .image: return "图片"
        case .text: return "文本区块"
        case .heading: return "标题"
        case .card: return "卡片"
        case .columns: return "两栏布局"
        case .quote: return "提示 / 引用"
        case .divider: return "分隔线"
        case .details: return "折叠详情"
        case .input: return "输入框"
        case .list: return "项目列表"
        }
    }
    var defaultTitle: String {
        switch self {
        case .link: return "链接文字"
        case .button: return "按钮文字"
        case .image: return "图片说明"
        case .heading: return "二级标题"
        case .card: return "卡片标题"
        case .quote: return "提示"
        case .details: return "点击展开详情"
        case .input: return "字段名称"
        default: return ""
        }
    }
    var defaultContent: String {
        switch self {
        case .text: return "在这里输入正文内容。"
        case .card: return "在这里输入卡片内容。"
        case .columns: return "左栏内容。\n右栏内容。"
        case .quote: return "在这里输入提示或引用内容。"
        case .details: return "在这里输入详情内容。"
        case .input: return "请输入内容"
        case .list: return "第一项\n第二项\n第三项"
        default: return ""
        }
    }
    var hasTitle: Bool { !defaultTitle.isEmpty }
    var hasAddress: Bool { [.link, .button, .image].contains(self) }
    var hasContent: Bool { [.image, .text, .card, .columns, .quote, .details, .input, .list].contains(self) }
}

struct HTMLComponent {
    let kind: HTMLComponentKind
    var title = ""
    var address = ""
    var content = ""
    var newWindow = false

    struct InvalidAddress: LocalizedError {
        let errorDescription: String?
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func validatedAddress() throws -> String {
        let value = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = kind == .image ? "请填写图片地址、相对路径，或选择本地图片。" : "请填写网页地址、邮件地址、电话或相对路径。"
        guard !value.isEmpty, !value.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) else {
            throw InvalidAddress(errorDescription: message)
        }
        if let range = value.range(of: #"^[a-z][a-z\d+.-]*:"#, options: [.regularExpression, .caseInsensitive]) {
            let scheme = String(value[range].dropLast()).lowercased()
            let allowed = kind == .image ? ["https", "http", "file"] : ["https", "http", "file", "mailto", "tel"]
            guard allowed.contains(scheme) || (kind == .image && value.lowercased().hasPrefix("data:image/")) else {
                throw InvalidAddress(errorDescription: message)
            }
        }
        return Self.escape(value)
    }

    func render() throws -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = Self.escape(trimmedTitle.isEmpty ? kind.defaultTitle : trimmedTitle)
        let body = Self.escape(content).replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\n", with: "<br>")
        let marker = #"data-html-studio-component="\#(kind.rawValue)""#
        let target = newWindow ? #" target="_blank" rel="noopener noreferrer""# : ""
        let buttonStyle = "display:inline-block;padding:10px 20px;border:0;border-radius:8px;background:#2563eb;color:#fff;text-decoration:none;font:inherit;cursor:pointer"
        switch kind {
        case .link:
            return #"<a \#(marker) href="\#(try validatedAddress())"\#(target)>\#(title)</a>"#
        case .button:
            if !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return #"<a \#(marker) role="button" href="\#(try validatedAddress())"\#(target) style="\#(buttonStyle)">\#(title)</a>"#
            }
            return #"<button \#(marker) type="button" style="\#(buttonStyle)">\#(title)</button>"#
        case .image:
            let caption = content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : #"<figcaption style="font-size:14px;color:#64748b;margin-top:8px">\#(body)</figcaption>"#
            return #"<figure style="margin:16px 0"><img \#(marker) src="\#(try validatedAddress())" alt="\#(title)" style="max-width:100%;height:auto;border-radius:8px">\#(caption)</figure>"#
        case .text: return #"<p \#(marker)>\#(body)</p>"#
        case .heading: return #"<h2 \#(marker)>\#(title)</h2>"#
        case .card: return #"<section \#(marker) style="box-sizing:border-box;margin:16px 0;padding:24px;border:1px solid #cbd5e1;border-radius:12px;background:#f8fafc;color:#172033"><h3 style="margin:0 0 12px">\#(title)</h3><p style="margin:0">\#(body)</p></section>"#
        case .columns:
            let parts = content.components(separatedBy: .newlines)
            let left = Self.escape(parts.first.flatMap { $0.isEmpty ? nil : $0 } ?? "左栏内容。")
            let right = Self.escape(parts.dropFirst().joined(separator: "\n").isEmpty ? "右栏内容。" : parts.dropFirst().joined(separator: "\n")).replacingOccurrences(of: "\n", with: "<br>")
            return #"<section \#(marker) style="display:flex;flex-wrap:wrap;gap:20px;margin:16px 0"><div style="flex:1 1 220px;min-width:0"><p>\#(left)</p></div><div style="flex:1 1 220px;min-width:0"><p>\#(right)</p></div></section>"#
        case .quote: return #"<blockquote \#(marker) style="margin:16px 0;padding:16px 20px;border-left:4px solid #2563eb;background:#eff6ff;color:#172033"><strong>\#(title)</strong><p style="margin:8px 0 0">\#(body)</p></blockquote>"#
        case .divider: return #"<hr \#(marker) style="border:0;border-top:1px solid #cbd5e1;margin:24px 0">"#
        case .details: return #"<details \#(marker) open style="margin:16px 0;padding:16px;border:1px solid #cbd5e1;border-radius:8px"><summary style="cursor:pointer;font-weight:600">\#(title)</summary><p>\#(body)</p></details>"#
        case .input: return #"<label \#(marker) style="display:block;margin:16px 0"><span style="display:block;margin-bottom:8px">\#(title)</span><input type="text" placeholder="\#(Self.escape(content))" style="box-sizing:border-box;width:100%;padding:10px 12px;border:1px solid #94a3b8;border-radius:6px;font:inherit"></label>"#
        case .list:
            let items = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.map { "<li>\(Self.escape($0))</li>" }.joined()
            return "<ul \(marker)>\(items)</ul>"
        }
    }
}
