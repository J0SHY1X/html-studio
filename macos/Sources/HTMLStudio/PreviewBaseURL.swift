import Foundation

enum PreviewBaseURL {
    /// Grant WebKit file access only when the document actually resolves local
    /// resources. Issuing an unnecessary sandbox extension for a restored cloud
    /// or privacy-protected directory can block loadHTMLString on the UI thread.
    static func effectiveURL(for html: String, proposed: URL?) -> URL? {
        guard let proposed, proposed.isFileURL else { return proposed }
        // Dynamic resource loading and srcset need their original base context.
        if html.range(of: #"<script\b|\bsrcset\s*=|\bon[a-z]+\s*="#,
                      options: [.regularExpression, .caseInsensitive]) != nil {
            return proposed
        }
        let patterns = [
            #"\b(?:src|href|poster|action|data)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))"#,
            #"url\(\s*(?:"([^"]*)"|'([^']*)'|([^\s)]+))\s*\)"#,
            #"@import\s*(?:"([^"]*)"|'([^']*)')"#
        ]
        let text = html as NSString
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            for match in regex.matches(in: html, range: NSRange(location: 0, length: text.length)) {
                for index in 1..<match.numberOfRanges where match.range(at: index).location != NSNotFound {
                    let value = text.substring(with: match.range(at: index)).trimmingCharacters(in: .whitespacesAndNewlines)
                    if value.isEmpty || value.hasPrefix("#") { continue }
                    if value.hasPrefix("//") { return proposed }
                    if value.range(of: #"^[a-z][a-z\d+.-]*:"#, options: [.regularExpression, .caseInsensitive]) == nil {
                        return proposed
                    }
                    if value.lowercased().hasPrefix("file:") || value.lowercased().hasPrefix("javascript:") {
                        return proposed
                    }
                }
            }
        }
        return nil
    }
}
