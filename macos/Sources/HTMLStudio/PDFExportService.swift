import AppKit
import Foundation
import WebKit

enum PDFExportError: LocalizedError {
    case exportInProgress
    case captureFailed
    case pageTooLarge
    case outputMissing
    case timedOut(String)
    case webContentProcessTerminated

    var errorDescription: String? {
        switch self {
        case .exportInProgress:
            return "已有 PDF 正在导出，请稍后再试。"
        case .captureFailed:
            return "WebKit 未能生成 PDF。"
        case .pageTooLarge:
            return "页面高度超过 PDF 导出的安全上限，请拆分文档后重试。"
        case .outputMissing:
            return "PDF 导出完成，但没有找到输出文件。"
        case .timedOut(let stage):
            return "PDF 导出在“\(stage)”阶段超时，请重试或查看 PDF 导出日志。"
        case .webContentProcessTerminated:
            return "PDF 渲染进程意外终止，请重试或简化页面中的超大图片。"
        }
    }
}

@MainActor
final class PDFExportService: NSObject, WKNavigationDelegate {
    static let shared = PDFExportService()
    private static let captureWidth: CGFloat = 794
    private static let capturePageHeight: CGFloat = 794 * 841.89 / 595.28
    private static let capturePagesPerChunk = 8

    private var webView: WKWebView?
    private var destinationURL: URL?
    private var completion: ((Result<Void, Error>) -> Void)?
    private var capturedChunkData: [Data] = []
    private var timeoutWorkItem: DispatchWorkItem?

    func export(
        html: String,
        baseURL: URL?,
        to destinationURL: URL,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard self.completion == nil else {
            completion(.failure(PDFExportError.exportInProgress))
            return
        }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = false
        configuration.defaultWebpagePreferences = preferences

        let webView = WKWebView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: Self.captureWidth,
                height: Self.capturePageHeight
            ),
            configuration: configuration
        )
        webView.navigationDelegate = self

        self.webView = webView
        self.destinationURL = destinationURL
        self.completion = completion
        Self.log("start destination=\(destinationURL.path) htmlCharacters=\(html.count)")
        scheduleTimeout(after: 15, stage: "加载页面")
        webView.loadHTMLString(Self.preparedHTML(html), baseURL: baseURL)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        clearTimeout()
        Self.log("navigation finished")

        // Calling callAsyncJavaScript while page JavaScript is disabled can leave
        // WebKit without invoking its completion handler on some macOS releases.
        // A short deterministic layout delay keeps untrusted page scripts disabled
        // and, unlike the previous readiness Promise, can never stall the export.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, self.completion != nil else { return }
            self.captureLoadedPage()
        }
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        finish(.failure(error))
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        finish(.failure(error))
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        Self.log("web content process terminated")
        finish(.failure(PDFExportError.webContentProcessTerminated))
    }

    private func captureLoadedPage() {
        guard let webView, let destinationURL else {
            finish(.failure(PDFExportError.captureFailed))
            return
        }

        let script = """
        (() => {
          const pageHeight = \(Self.capturePageHeight);
          const epsilon = 2;
          const pageContentInset = 4;
          const forcedBreaks = new Set(["page", "always", "left", "right", "recto", "verso"]);
          const invalidSpacerParents = new Set([
            "TABLE", "THEAD", "TBODY", "TFOOT", "TR", "COLGROUP",
            "UL", "OL", "MENU", "SELECT", "OPTGROUP"
          ]);

          const documentY = (rectValue) => rectValue + window.scrollY;
          for (const image of Array.from(document.images || [])) {
            image.loading = "eager";
          }
          const remainder = (value) => ((value % pageHeight) + pageHeight) % pageHeight;
          const gapToNextPage = (value) => {
            const rest = remainder(value);
            if (rest <= epsilon || pageHeight - rest <= epsilon) return 0;
            return pageHeight - rest;
          };

          const makeSpacer = (gap) => {
            const spacer = document.createElement("div");
            spacer.dataset.htmlStudioPDFSpacer = "1";
            spacer.setAttribute("aria-hidden", "true");
            spacer.style.cssText = [
              "display:block!important",
              `height:${gap}px!important`,
              `min-height:${gap}px!important`,
              "width:100%!important",
              "margin:0!important",
              "padding:0!important",
              "border:0!important",
              "visibility:hidden!important",
              "pointer-events:none!important",
              "overflow:hidden!important",
              "box-sizing:border-box!important",
              "clear:both!important"
            ].join(";");
            return spacer;
          };

          const addInternalGap = (element, side, gap) => {
            const style = getComputedStyle(element);
            element.style.boxSizing = "border-box";
            if (side === "before") {
              element.style.paddingTop = `${(parseFloat(style.paddingTop) || 0) + gap}px`;
            } else {
              element.style.paddingBottom = `${(parseFloat(style.paddingBottom) || 0) + gap}px`;
            }
          };

          const addTableRowSpacer = (row, gap) => {
            const spacerRow = document.createElement("tr");
            spacerRow.dataset.htmlStudioPDFSpacer = "1";
            spacerRow.setAttribute("aria-hidden", "true");
            const cell = document.createElement("td");
            cell.colSpan = Math.max(1, row.cells ? row.cells.length : 1);
            cell.style.cssText = [
              `height:${gap}px!important`,
              `min-height:${gap}px!important`,
              "padding:0!important",
              "margin:0!important",
              "border:0!important",
              "background:transparent!important",
              "visibility:hidden!important"
            ].join(";");
            spacerRow.appendChild(cell);
            row.parentNode.insertBefore(spacerRow, row);
          };

          const addGap = (element, side, gap) => {
            if (!Number.isFinite(gap) || gap <= epsilon || !element.parentNode) return;

            if (side === "before" && element.tagName === "TR") {
              addTableRowSpacer(element, gap);
              return;
            }

            const parent = element.parentElement;
            const parentDisplay = parent ? getComputedStyle(parent).display : "";
            const needsInternalGap = !parent ||
              invalidSpacerParents.has(parent.tagName) ||
              parentDisplay === "flex" || parentDisplay === "inline-flex" ||
              parentDisplay === "grid" || parentDisplay === "inline-grid";

            if (needsInternalGap) {
              addInternalGap(element, side, gap);
              return;
            }

            const spacer = makeSpacer(gap);
            if (side === "before") {
              element.parentNode.insertBefore(spacer, element);
            } else {
              element.parentNode.insertBefore(spacer, element.nextSibling);
            }
          };

          const elements = Array.from(document.body ? document.body.querySelectorAll("*") : []);
          for (const element of elements) {
            if (element.dataset.htmlStudioPDFBreak === "1" || element.dataset.htmlStudioPDFSpacer === "1") continue;
            const style = getComputedStyle(element);
            const breakBefore = forcedBreaks.has(style.breakBefore) || style.pageBreakBefore === "always";
            if (breakBefore) {
              const top = documentY(element.getBoundingClientRect().top);
              addGap(element, "before", gapToNextPage(top));
            }
            const breakAfter = forcedBreaks.has(style.breakAfter) || style.pageBreakAfter === "always";
            if (breakAfter) {
              const bottom = documentY(element.getBoundingClientRect().bottom);
              addGap(element, "after", gapToNextPage(bottom));
            }
            if (breakBefore || breakAfter) element.dataset.htmlStudioPDFBreak = "1";
          }

          const avoidBreakSelector = [
            "h1", "h2", "h3", "h4", "h5", "h6",
            "p", "li", "blockquote", "pre", "figure", "figcaption",
            "table", "tr", "img", "svg", "hr", "details", "summary",
            "[data-page-break-avoid]"
          ].join(",");
          const avoidBreakElements = Array.from(
            document.body ? document.body.querySelectorAll(avoidBreakSelector) : []
          );

          for (const element of avoidBreakElements) {
            if (element.dataset.htmlStudioPDFSpacer === "1") continue;
            const style = getComputedStyle(element);
            if (style.display === "none" || style.visibility === "hidden") continue;
            if (style.position === "fixed" || style.position === "absolute") continue;
            const rect = element.getBoundingClientRect();
            const height = rect.height;
            if (height <= epsilon || height >= pageHeight - (epsilon * 2)) continue;

            const top = documentY(rect.top);
            const bottom = documentY(rect.bottom);
            const topPage = Math.floor((top + epsilon) / pageHeight);
            const bottomPage = Math.floor((bottom - epsilon) / pageHeight);
            if (topPage !== bottomPage) {
              const boundary = (topPage + 1) * pageHeight;
              addGap(element, "before", boundary + pageContentInset - top);
            }
          }

          return Math.ceil(Math.max(
            document.documentElement.scrollHeight,
            document.body ? document.body.scrollHeight : 0,
            pageHeight
          ));
        })()
        """
        scheduleTimeout(after: 20, stage: "计算分页")
        webView.evaluateJavaScript(script) { [weak self] value, error in
            guard let self, self.completion != nil else { return }
            self.clearTimeout()
            if let error {
                Self.log("pagination JavaScript failed: \(error.localizedDescription)")
                self.finish(.failure(error))
                return
            }
            let height = (value as? NSNumber)?.doubleValue ?? Self.capturePageHeight
            guard height <= 200_000 else {
                self.finish(.failure(PDFExportError.pageTooLarge))
                return
            }

            let captureHeight = max(Self.capturePageHeight, height)
            let pageCount = max(
                1,
                Int(ceil(max(0, captureHeight - 1) / Self.capturePageHeight))
            )
            Self.log("layout height=\(height) pages=\(pageCount)")

            // WKWebView truncates a single PDF capture when its media box grows beyond
            // WebKit/Core Graphics' internal maximum dimension (about 14,400 points on
            // current macOS releases). Capture conservative eight-page chunks so a long
            // document can never lose its tail at that boundary.
            webView.setFrameSize(
                NSSize(width: Self.captureWidth, height: Self.capturePageHeight)
            )
            self.capturedChunkData.removeAll(keepingCapacity: true)
            self.captureChunk(
                startingAtPage: 0,
                totalPageCount: pageCount,
                webView: webView,
                destinationURL: destinationURL
            )
        }
    }

    private func captureChunk(
        startingAtPage pageIndex: Int,
        totalPageCount: Int,
        webView: WKWebView,
        destinationURL: URL
    ) {
        guard pageIndex < totalPageCount else {
            do {
                try Self.writeA4PDF(capturedChunkData, to: destinationURL)
                guard FileManager.default.fileExists(atPath: destinationURL.path) else {
                    throw PDFExportError.outputMissing
                }
                finish(.success(()))
            } catch {
                finish(.failure(error))
            }
            return
        }

        let pagesInChunk = min(
            Self.capturePagesPerChunk,
            totalPageCount - pageIndex
        )
        let configuration = WKPDFConfiguration()
        configuration.rect = CGRect(
            x: 0,
            y: CGFloat(pageIndex) * Self.capturePageHeight,
            width: Self.captureWidth,
            height: CGFloat(pagesInChunk) * Self.capturePageHeight
        )
        let chunkNumber = (pageIndex / Self.capturePagesPerChunk) + 1
        Self.log(
            "capture chunk=\(chunkNumber) startPage=\(pageIndex + 1) pages=\(pagesInChunk)"
        )
        scheduleTimeout(after: 30, stage: "生成 PDF 第 \(chunkNumber) 段")
        webView.createPDF(configuration: configuration) { [weak self] result in
            guard let self, self.completion != nil else { return }
            self.clearTimeout()
            do {
                let data = try result.get()
                guard Self.pdfPageCount(in: data) > 0 else {
                    throw PDFExportError.captureFailed
                }
                Self.log("captured chunk=\(chunkNumber) bytes=\(data.count)")
                self.capturedChunkData.append(data)
                self.captureChunk(
                    startingAtPage: pageIndex + pagesInChunk,
                    totalPageCount: totalPageCount,
                    webView: webView,
                    destinationURL: destinationURL
                )
            } catch {
                Self.log("capture chunk=\(chunkNumber) failed: \(error.localizedDescription)")
                self.finish(.failure(error))
            }
        }
    }

    private func finish(_ result: Result<Void, Error>) {
        guard completion != nil else { return }
        clearTimeout()
        switch result {
        case .success:
            Self.log("finished successfully")
        case .failure(let error):
            Self.log("finished with error: \(error.localizedDescription)")
        }
        let completion = completion
        self.completion = nil
        destinationURL = nil
        capturedChunkData.removeAll(keepingCapacity: false)
        webView?.navigationDelegate = nil
        webView = nil
        completion?(result)
    }

    private func scheduleTimeout(after seconds: TimeInterval, stage: String) {
        clearTimeout()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.completion != nil else { return }
            Self.log("timeout stage=\(stage)")
            self.finish(.failure(PDFExportError.timedOut(stage)))
        }
        timeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: workItem)
    }

    private func clearTimeout() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
    }

    private static func preparedHTML(_ html: String) -> String {
        let printStyle = """
        <style data-html-studio-pdf>
          html, body { -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }
          img, svg, table { max-width: 100%; }
          [data-html-studio-pdf-spacer] { break-inside: avoid !important; page-break-inside: avoid !important; }
          @media print {
            html, body { -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }
            img, svg, table { max-width: 100%; }
          }
        </style>
        """

        if let range = html.range(of: "</head>", options: [.caseInsensitive]) {
            var value = html
            value.insert(contentsOf: printStyle, at: range.lowerBound)
            return value
        }
        return "<!doctype html><html><head><meta charset=\"utf-8\">\(printStyle)</head><body>\(html)</body></html>"
    }

    static func writeA4PDF(_ capturedPages: [Data], to destinationURL: URL) throws {
        guard !capturedPages.isEmpty else {
            throw PDFExportError.captureFailed
        }
        try? FileManager.default.removeItem(at: destinationURL)
        var a4Box = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
        guard
            let consumer = CGDataConsumer(url: destinationURL as CFURL),
            let context = CGContext(consumer: consumer, mediaBox: &a4Box, nil)
        else {
            throw PDFExportError.captureFailed
        }

        for data in capturedPages {
            guard
                let provider = CGDataProvider(data: data as CFData),
                let sourceDocument = CGPDFDocument(provider),
                sourceDocument.numberOfPages > 0
            else {
                throw PDFExportError.captureFailed
            }

            for pageIndex in 1...sourceDocument.numberOfPages {
                guard let sourcePage = sourceDocument.page(at: pageIndex) else {
                    throw PDFExportError.captureFailed
                }
                let sourceBox = sourcePage.getBoxRect(.mediaBox)
                guard sourceBox.width > 0, sourceBox.height > 0 else {
                    throw PDFExportError.captureFailed
                }

                let scale = a4Box.width / sourceBox.width
                let sourceHeightPerPage = a4Box.height / scale
                let pageCount = max(
                    1,
                    Int(ceil(max(0, sourceBox.height - 1) / sourceHeightPerPage))
                )

                for index in 0..<pageCount {
                    let upperY = sourceBox.maxY - (CGFloat(index) * sourceHeightPerPage)
                    let lowerY = max(sourceBox.minY, upperY - sourceHeightPerPage)
                    let segmentHeight = upperY - lowerY
                    let topAlignment = sourceHeightPerPage - segmentHeight

                    context.beginPDFPage(nil)
                    context.saveGState()
                    context.scaleBy(x: scale, y: scale)
                    context.translateBy(
                        x: -sourceBox.minX,
                        y: topAlignment - lowerY
                    )
                    context.drawPDFPage(sourcePage)
                    context.restoreGState()
                    context.endPDFPage()
                }
            }
        }
        context.closePDF()
    }

    private static func pdfPageCount(in data: Data) -> Int {
        guard
            let provider = CGDataProvider(data: data as CFData),
            let document = CGPDFDocument(provider)
        else {
            return 0
        }
        return document.numberOfPages
    }

    static var diagnosticLogURL: URL {
        let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return baseURL
            .appendingPathComponent("HTMLStudio", isDirectory: true)
            .appendingPathComponent("pdf-export.log")
    }

    private static func log(_ message: String) {
        let url = diagnosticLogURL
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let formatter = ISO8601DateFormatter()
            let line = "[\(formatter.string(from: Date()))] \(message)\n"
            let data = Data(line.utf8)
            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } else {
                try data.write(to: url, options: .atomic)
            }
        } catch {
            NSLog("HTML Studio PDF log failed: %@", error.localizedDescription)
        }
    }
}
