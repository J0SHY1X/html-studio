import AppKit
import Foundation

@main
@MainActor
struct PDFExportHarness {
    private static var exportError: Error?

    static func main() {
        guard CommandLine.arguments.count == 3 else {
            FileHandle.standardError.write(
                Data("Usage: PDFExportHarness INPUT.html OUTPUT.pdf\n".utf8)
            )
            exit(64)
        }

        let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

        do {
            let html = try String(contentsOf: inputURL, encoding: .utf8)
            NSApplication.shared.setActivationPolicy(.prohibited)
            PDFExportService.shared.export(
                html: html,
                baseURL: inputURL.deletingLastPathComponent(),
                to: outputURL
            ) { result in
                if case let .failure(error) = result {
                    exportError = error
                }
                NSApplication.shared.stop(nil)
            }
            NSApplication.shared.run()
        } catch {
            exportError = error
        }

        if let exportError {
            FileHandle.standardError.write(Data("PDF export failed: \(exportError)\n".utf8))
            exit(1)
        }
    }
}
