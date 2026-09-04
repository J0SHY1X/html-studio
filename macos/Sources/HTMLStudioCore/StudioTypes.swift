import Foundation

public enum StudioError: LocalizedError {
    case unsupportedFormat(String)
    case textEncoding
    case saveLocationRequired
    case conversionFailed(String)
    case toolUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            return "暂不支持 .\(ext) 文件。"
        case .textEncoding:
            return "无法识别或写入此文件的文本编码。"
        case .saveLocationRequired:
            return "请先选择 HTML 文件的保存位置。"
        case .conversionFailed(let detail):
            return "格式转换失败：\(detail)"
        case .toolUnavailable(let detail):
            return detail
        }
    }
}

public struct OutlineItem: Identifiable {
    public let id = UUID()
    public let level: Int
    public let title: String

    public init(level: Int, title: String) {
        self.level = level
        self.title = title
    }
}

public enum OutlineParser {
    public static func items(from html: String) -> [OutlineItem] {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?is)<h([1-6])[^>]*>(.*?)</h\1>"#
        ) else {
            return []
        }

        let source = html as NSString
        return regex.matches(
            in: html,
            range: NSRange(location: 0, length: source.length)
        ).compactMap { match in
            guard
                match.numberOfRanges == 3,
                let level = Int(source.substring(with: match.range(at: 1)))
            else {
                return nil
            }
            let rawTitle = source.substring(with: match.range(at: 2))
            let title = rawTitle
                .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? nil : OutlineItem(level: level, title: title)
        }
    }
}
