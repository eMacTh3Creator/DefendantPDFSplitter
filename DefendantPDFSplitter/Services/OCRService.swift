import Foundation
import PDFKit
import Vision
import AppKit

struct OCRService {

    enum OCRError: LocalizedError {
        case renderFailed(Int)
        case recognitionFailed(String)

        var errorDescription: String? {
            switch self {
            case .renderFailed(let pageIndex):
                return "Failed to render page \(pageIndex + 1) for OCR."
            case .recognitionFailed(let detail):
                return "Text recognition failed: \(detail)"
            }
        }
    }

    /// Render a PDF page to a CGImage at a resolution suitable for OCR.
    /// 200 DPI is the sweet spot — higher gives no accuracy gain but is much slower.
    static func renderPageToImage(_ page: PDFPage, dpi: CGFloat = 200) -> CGImage? {
        let pageRect = page.bounds(for: .mediaBox)
        let scale = dpi / 72.0   // PDF native is 72 DPI
        let pixelWidth = Int(pageRect.width * scale)
        let pixelHeight = Int(pageRect.height * scale)

        guard pixelWidth > 0, pixelHeight > 0 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // White background — many scanned PDFs have transparent pages otherwise
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)

        return context.makeImage()
    }

    /// Run Vision OCR on a CGImage and return the recognized text.
    /// Uses .accurate recognition with US English (extend if needed).
    static func recognizeText(in image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])
        } catch {
            throw OCRError.recognitionFailed(error.localizedDescription)
        }

        guard let observations = request.results else { return "" }

        let lines = observations.compactMap { obs -> String? in
            obs.topCandidates(1).first?.string
        }

        return lines.joined(separator: "\n")
    }

    /// Convenience: OCR a single PDF page end-to-end.
    static func extractText(from page: PDFPage, pageIndex: Int) throws -> String {
        guard let image = renderPageToImage(page) else {
            throw OCRError.renderFailed(pageIndex)
        }
        return try recognizeText(in: image)
    }
}
