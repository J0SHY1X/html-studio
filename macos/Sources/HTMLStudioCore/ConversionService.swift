import AppKit
import Foundation

public final class ConversionService {
    public static let shared = ConversionService()

    private let fileManager: FileManager
    private let pandocCandidates = [
        "/opt/homebrew/bin/pandoc",
        "/usr/local/bin/pandoc",
        "/usr/bin/pandoc"
    ]

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public var pandocURL: URL? {
        pandocCandidates
            .first(where: { fileManager.isExecutableFile(atPath: $0) })
            .map(URL.init(fileURLWithPath:))
    }

    public var conversionStatus: String {
        pandocURL == nil ? "内置兼容转换" : "Pandoc 高质量转换"
    }

    public func htmlToMarkdown(_ html: String) throws -> String {
        if let pandocURL {
            return try runPandoc(
                executable: pandocURL,
                arguments: ["--from=html", "--to=gfm", "--wrap=none"],
                standardInput: html
            )
        }
        return FallbackHTMLConverter.htmlToMarkdown(html)
    }

    public func markdownToHTML(_ markdown: String) throws -> String {
        if let pandocURL {
            return try runPandoc(
                executable: pandocURL,
                arguments: [
                    "--from=gfm",
                    "--to=html5",
                    "--standalone",
                    "--metadata=title:Imported Markdown"
                ],
                standardInput: markdown
            )
        }
        return FallbackHTMLConverter.markdownToHTML(markdown)
    }

    public func htmlToDOCX(_ html: String, destination: URL) throws {
        if let pandocURL {
            let temporaryHTML = fileManager.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("html")
            defer { try? fileManager.removeItem(at: temporaryHTML) }

            guard let data = html.data(using: .utf8) else {
                throw StudioError.textEncoding
            }
            try data.write(to: temporaryHTML, options: .atomic)

            _ = try runProcess(
                executable: pandocURL,
                arguments: [
                    temporaryHTML.path,
                    "--from=html",
                    "--to=docx",
                    "--output=\(destination.path)"
                ]
            )
            return
        }

        try SimpleDOCXWriter(fileManager: fileManager).write(
            html: html,
            destination: destination
        )
    }

    public func docxToHTML(_ url: URL) throws -> String {
        guard let pandocURL else {
            throw StudioError.toolUnavailable(
                "打开 DOCX 需要 Pandoc；仍可将 HTML 导出为基础 Word 文档。"
            )
        }

        return try runPandoc(
            executable: pandocURL,
            arguments: [
                url.path,
                "--from=docx",
                "--to=html5",
                "--standalone",
                "--embed-resources",
                "--metadata=title:\(url.deletingPathExtension().lastPathComponent)"
            ]
        )
    }

    @discardableResult
    private func runPandoc(
        executable: URL,
        arguments: [String],
        standardInput: String? = nil
    ) throws -> String {
        try runProcess(
            executable: executable,
            arguments: arguments,
            standardInput: standardInput
        )
    }

    @discardableResult
    private func runProcess(
        executable: URL,
        arguments: [String],
        standardInput: String? = nil,
        currentDirectory: URL? = nil
    ) throws -> String {
        let process = Process()
        let captureDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("HTMLStudio-Process-\(UUID().uuidString)", isDirectory: true)
        let outputURL = captureDirectory.appendingPathComponent("stdout")
        let errorURL = captureDirectory.appendingPathComponent("stderr")
        let inputURL = captureDirectory.appendingPathComponent("stdin")
        try fileManager.createDirectory(at: captureDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: captureDirectory) }

        fileManager.createFile(atPath: outputURL.path, contents: nil)
        fileManager.createFile(atPath: errorURL.path, contents: nil)
        let outputHandle = try FileHandle(forWritingTo: outputURL)
        let errorHandle = try FileHandle(forWritingTo: errorURL)
        defer {
            try? outputHandle.close()
            try? errorHandle.close()
        }

        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = outputHandle
        process.standardError = errorHandle
        process.currentDirectoryURL = currentDirectory

        if let standardInput {
            try Data(standardInput.utf8).write(to: inputURL)
            process.standardInput = try FileHandle(forReadingFrom: inputURL)
        }

        try process.run()
        process.waitUntilExit()
        try outputHandle.synchronize()
        try errorHandle.synchronize()
        let outputData = try Data(contentsOf: outputURL)
        let errorData = try Data(contentsOf: errorURL)

        guard process.terminationStatus == 0 else {
            let detail = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw StudioError.conversionFailed(
                detail?.isEmpty == false ? detail! : "转换工具返回错误 \(process.terminationStatus)。"
            )
        }

        return String(data: outputData, encoding: .utf8) ?? ""
    }
}

public enum FallbackHTMLConverter {
    public static func htmlToMarkdown(_ html: String) -> String {
        var value = html
        value = replacing(
            #"(?is)<(script|style)[^>]*>.*?</\1>"#,
            in: value,
            with: ""
        )
        value = replacing(
            #"(?is)<pre[^>]*>\s*<code[^>]*>(.*?)</code>\s*</pre>"#,
            in: value,
            with: "\n```\n$1\n```\n"
        )

        for level in 1...6 {
            value = replacing(
                #"(?is)<h\#(level)[^>]*>(.*?)</h\#(level)>"#,
                in: value,
                with: "\n\(String(repeating: "#", count: level)) $1\n"
            )
        }

        value = replacing(#"(?is)<(strong|b)[^>]*>(.*?)</\1>"#, in: value, with: "**$2**")
        value = replacing(#"(?is)<(em|i)[^>]*>(.*?)</\1>"#, in: value, with: "*$2*")
        value = replacing(#"(?is)<del[^>]*>(.*?)</del>"#, in: value, with: "~~$1~~")
        value = replacing(#"(?is)<code[^>]*>(.*?)</code>"#, in: value, with: "`$1`")
        value = replacing(
            #"(?is)<a[^>]*href\s*=\s*["']([^"']+)["'][^>]*>(.*?)</a>"#,
            in: value,
            with: "[$2]($1)"
        )
        value = replacing(
            #"(?is)<img[^>]*src\s*=\s*["']([^"']+)["'][^>]*alt\s*=\s*["']([^"']*)["'][^>]*>"#,
            in: value,
            with: "![$2]($1)"
        )
        value = replacing(#"(?is)<li[^>]*>(.*?)</li>"#, in: value, with: "\n- $1")
        value = replacing(#"(?is)<br\s*/?>"#, in: value, with: "\n")
        value = replacing(#"(?is)</(p|div|section|article|header|footer|ul|ol|blockquote)>"#, in: value, with: "\n\n")
        value = replacing(#"(?is)<[^>]+>"#, in: value, with: "")
        value = decodeEntities(value)
        value = replacing(#"[ \t]+\n"#, in: value, with: "\n")
        value = replacing(#"\n{3,}"#, in: value, with: "\n\n")
        return value.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    public static func markdownToHTML(_ markdown: String) -> String {
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
        var body: [String] = []
        var inList = false
        var inCode = false
        var codeLines: [String] = []

        func closeList() {
            if inList {
                body.append("</ul>")
                inList = false
            }
        }

        for line in lines {
            if line.hasPrefix("```") {
                closeList()
                if inCode {
                    body.append("<pre><code>\(escapeHTML(codeLines.joined(separator: "\n")))</code></pre>")
                    codeLines.removeAll()
                }
                inCode.toggle()
                continue
            }

            if inCode {
                codeLines.append(line)
                continue
            }

            let headingLevel = line.prefix { $0 == "#" }.count
            if (1...6).contains(headingLevel),
               line.dropFirst(headingLevel).hasPrefix(" ") {
                closeList()
                let title = String(line.dropFirst(headingLevel + 1))
                body.append("<h\(headingLevel)>\(inlineMarkdown(title))</h\(headingLevel)>")
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                if !inList {
                    body.append("<ul>")
                    inList = true
                }
                body.append("<li>\(inlineMarkdown(String(line.dropFirst(2))))</li>")
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                closeList()
            } else {
                closeList()
                body.append("<p>\(inlineMarkdown(line))</p>")
            }
        }
        closeList()

        return """
        <!doctype html>
        <html lang="zh-CN">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Imported Markdown</title>
          <style>
            body { max-width: 780px; margin: 48px auto; padding: 0 24px; font: 17px/1.7 -apple-system, BlinkMacSystemFont, sans-serif; }
            pre { padding: 16px; overflow: auto; border-radius: 10px; background: #f3f4f6; }
            img { max-width: 100%; }
          </style>
        </head>
        <body>
        \(body.joined(separator: "\n"))
        </body>
        </html>
        """
    }

    public static func plainText(from html: String) -> String {
        if let data = html.data(using: .utf8),
           let attributed = try? NSAttributedString(
               data: data,
               options: [
                   .documentType: NSAttributedString.DocumentType.html,
                   .characterEncoding: String.Encoding.utf8.rawValue
               ],
               documentAttributes: nil
           ) {
            return attributed.string
        }
        return htmlToMarkdown(html)
            .replacingOccurrences(of: #"(?m)^[#>*\-]+\s*"#, with: "", options: .regularExpression)
    }

    private static func inlineMarkdown(_ value: String) -> String {
        var result = escapeHTML(value)
        result = replacing(#"\*\*(.+?)\*\*"#, in: result, with: "<strong>$1</strong>")
        result = replacing(#"\*(.+?)\*"#, in: result, with: "<em>$1</em>")
        result = replacing(#"`(.+?)`"#, in: result, with: "<code>$1</code>")
        result = replacing(#"\[([^\]]+)\]\(([^)]+)\)"#, in: result, with: #"<a href="$2">$1</a>"#)
        return result
    }

    private static func replacing(
        _ pattern: String,
        in value: String,
        with replacement: String
    ) -> String {
        value.replacingOccurrences(
            of: pattern,
            with: replacement,
            options: .regularExpression
        )
    }

    private static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func decodeEntities(_ value: String) -> String {
        guard let data = value.data(using: .utf8),
              let attributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              )
        else {
            return value
        }
        return attributed.string
    }
}

private struct SimpleDOCXWriter {
    let fileManager: FileManager

    func write(html: String, destination: URL) throws {
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("HTMLStudio-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let rels = root.appendingPathComponent("_rels", isDirectory: true)
        let word = root.appendingPathComponent("word", isDirectory: true)
        let wordRels = word.appendingPathComponent("_rels", isDirectory: true)
        let docProps = root.appendingPathComponent("docProps", isDirectory: true)
        try fileManager.createDirectory(at: rels, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: wordRels, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: docProps, withIntermediateDirectories: true)

        let text = FallbackHTMLConverter.plainText(from: html)
        let paragraphs = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let paragraphXML = paragraphs.map { paragraph in
            "<w:p><w:r><w:t xml:space=\"preserve\">\(escapeXML(paragraph))</w:t></w:r></w:p>"
        }.joined(separator: "\n")

        let files: [(URL, String)] = [
            (
                root.appendingPathComponent("[Content_Types].xml"),
                """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
                  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
                  <Default Extension="xml" ContentType="application/xml"/>
                  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
                  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
                  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
                  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
                </Types>
                """
            ),
            (
                rels.appendingPathComponent(".rels"),
                """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
                  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
                  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
                </Relationships>
                """
            ),
            (
                word.appendingPathComponent("document.xml"),
                """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
                  <w:body>
                    \(paragraphXML)
                    <w:sectPr>
                      <w:pgSz w:w="11906" w:h="16838"/>
                      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
                    </w:sectPr>
                  </w:body>
                </w:document>
                """
            ),
            (
                word.appendingPathComponent("styles.xml"),
                """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
                  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
                    <w:name w:val="Normal"/>
                    <w:rPr><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr>
                  </w:style>
                </w:styles>
                """
            ),
            (
                wordRels.appendingPathComponent("document.xml.rels"),
                """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>
                """
            ),
            (
                docProps.appendingPathComponent("core.xml"),
                """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/">
                  <dc:title>HTML Studio Export</dc:title>
                  <dc:creator>HTML Studio</dc:creator>
                </cp:coreProperties>
                """
            ),
            (
                docProps.appendingPathComponent("app.xml"),
                """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
                  <Application>HTML Studio</Application>
                </Properties>
                """
            )
        ]

        for (url, contents) in files {
            try Data(contents.utf8).write(to: url)
        }

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-q", "-r", destination.path, "."]
        process.currentDirectoryURL = root
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw StudioError.conversionFailed("无法创建 DOCX 压缩包。")
        }
    }

    private func escapeXML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
