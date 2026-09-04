import Foundation
import HTMLStudioCore

enum SmokeTestError: Error {
    case failed(String)
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else {
        throw SmokeTestError.failed(message)
    }
}

let html = """
<h1>标题</h1>
<p>这是 <strong>重点</strong> 和 <a href="https://example.com">链接</a>。</p>
<ul><li>第一项</li><li>第二项</li></ul>
"""
let markdown = FallbackHTMLConverter.htmlToMarkdown(html)
try expect(markdown.contains("# 标题"), "HTML 标题未转换为 Markdown")
try expect(markdown.contains("**重点**"), "HTML 粗体未转换为 Markdown")
try expect(markdown.contains("[链接](https://example.com)"), "HTML 链接未转换为 Markdown")
try expect(markdown.contains("- 第一项"), "HTML 列表未转换为 Markdown")

let productionMarkdown = try ConversionService.shared.htmlToMarkdown(html)
try expect(productionMarkdown.contains("标题"), "生产转换引擎未生成 Markdown")

let generatedHTML = FallbackHTMLConverter.markdownToHTML(
    "# 标题\n\n一段 **粗体** 内容。\n\n- A\n- B"
)
try expect(generatedHTML.contains("<h1>标题</h1>"), "Markdown 标题未转换为 HTML")
try expect(generatedHTML.contains("<strong>粗体</strong>"), "Markdown 粗体未转换为 HTML")
try expect(generatedHTML.contains("<li>A</li>"), "Markdown 列表未转换为 HTML")

let outline = OutlineParser.items(
    from: "<h1>首页</h1><section><h2><span>介绍</span></h2></section>"
)
try expect(outline.count == 2, "页面大纲数量不正确")
try expect(outline[0].level == 1 && outline[0].title == "首页", "一级标题解析失败")
try expect(outline[1].level == 2 && outline[1].title == "介绍", "嵌套标题解析失败")

let temporaryDOCX = FileManager.default.temporaryDirectory
    .appendingPathComponent("HTMLStudio-SmokeTest-\(UUID().uuidString).docx")
defer { try? FileManager.default.removeItem(at: temporaryDOCX) }
try ConversionService.shared.htmlToDOCX(html, destination: temporaryDOCX)
try expect(FileManager.default.fileExists(atPath: temporaryDOCX.path), "DOCX 文件未生成")
let attributes = try FileManager.default.attributesOfItem(atPath: temporaryDOCX.path)
let fileSize = attributes[.size] as? NSNumber
try expect((fileSize?.intValue ?? 0) > 500, "DOCX 文件内容异常")

if ConversionService.shared.pandocURL != nil {
    let roundTripHTML = try ConversionService.shared.docxToHTML(temporaryDOCX)
    try expect(roundTripHTML.contains("标题"), "DOCX 往返转换丢失正文")
}

print("HTML Studio smoke tests passed.")
