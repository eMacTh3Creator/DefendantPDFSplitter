import Foundation
import PDFKit

struct PDFTextExtractor {

    /// Extract text content from a single PDF page.
    /// Returns nil if the page contains no extractable text (scanned/image-based).
    static func extractText(from page: PDFPage) -> String? {
        guard let text = page.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return text
    }

    /// Extract text from all pages of a PDF document.
    /// Returns an array where each element is the text for the corresponding page index, or nil if no text found.
    static func extractAllPages(from document: PDFDocument) -> [String?] {
        (0..<document.pageCount).map { index in
            guard let page = document.page(at: index) else { return nil }
            return extractText(from: page)
        }
    }
}
