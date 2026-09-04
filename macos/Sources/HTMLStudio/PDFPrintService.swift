import AppKit
import Foundation
import PDFKit

enum PDFPrintError: LocalizedError {
    case invalidDocument
    case operationUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidDocument:
            return "无法读取为打印准备的 PDF 文档。"
        case .operationUnavailable:
            return "系统无法创建打印任务。"
        }
    }
}

@MainActor
enum PDFPrintService {
    static func printPDF(at url: URL, jobName: String) throws {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw PDFPrintError.invalidDocument
        }
        let printInfo = NSPrintInfo.shared.copy() as? NSPrintInfo ?? NSPrintInfo.shared
        guard let operation = pdfDocument.printOperation(
            for: printInfo,
            scalingMode: .pageScaleDownToFit,
            autoRotate: true
        ) else {
            throw PDFPrintError.operationUnavailable
        }

        operation.jobTitle = jobName
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.run()
    }
}
