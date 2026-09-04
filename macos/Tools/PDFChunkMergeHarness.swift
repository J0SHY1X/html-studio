import AppKit
import Foundation

@main
@MainActor
struct PDFChunkMergeHarness {
    private static let sourceWidth: CGFloat = 794
    private static let sourcePageHeight: CGFloat = 794 * 841.89 / 595.28

    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            throw NSError(
                domain: "PDFChunkMergeHarness",
                code: 64,
                userInfo: [NSLocalizedDescriptionKey: "Usage: PDFChunkMergeHarness OUTPUT.pdf"]
            )
        }

        let destinationURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let firstChunk = try makeChunk(startingAt: 1, pageCount: 8)
        let secondChunk = try makeChunk(startingAt: 9, pageCount: 4)
        try PDFExportService.writeA4PDF(
            [firstChunk, secondChunk],
            to: destinationURL
        )
    }

    private static func makeChunk(startingAt firstPage: Int, pageCount: Int) throws -> Data {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
            throw PDFExportError.captureFailed
        }
        var mediaBox = CGRect(
            x: 0,
            y: 0,
            width: sourceWidth,
            height: sourcePageHeight * CGFloat(pageCount)
        )
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw PDFExportError.captureFailed
        }

        context.beginPDFPage(nil)
        for offset in 0..<pageCount {
            let pageNumber = firstPage + offset
            let bandY = mediaBox.maxY - (CGFloat(offset + 1) * sourcePageHeight)
            let hue = CGFloat(pageNumber - 1) / 12
            let color = NSColor(
                calibratedHue: hue,
                saturation: 0.68,
                brightness: 0.88,
                alpha: 1
            ).cgColor
            context.setFillColor(color)
            context.fill(
                CGRect(
                    x: 0,
                    y: bandY,
                    width: sourceWidth,
                    height: sourcePageHeight
                )
            )
        }
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }
}
