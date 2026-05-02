import Foundation
import PDFKit
import SwiftUI

@MainActor
final class PDFSplitterViewModel: ObservableObject {

    enum AppState: Equatable {
        case idle
        case loaded
        case exporting
        case exported
        case error(String)
    }

    @Published var state: AppState = .idle
    @Published var pdfDocument: PDFDocument?
    @Published var pdfURL: URL?
    @Published var pdfFilename: String = ""
    @Published var assignments: [PageAssignment] = []
    @Published var groups: [DefendantGroup] = []
    @Published var showExportSummary = false
    @Published var outputFolderURL: URL?
    @Published var zipFileURL: URL?
    @Published var exportMessage: String = ""
    @Published var warningMessage: String = ""

    /// Where the split_defendants_<name>/ folder will be written.
    /// Defaults to the input PDF's parent directory; user can override via `chooseSaveLocation()`.
    @Published var saveDestinationURL: URL?

    // OCR progress
    @Published var isDetecting: Bool = false
    @Published var detectProgress: Double = 0.0   // 0.0 ... 1.0
    @Published var detectStatusText: String = ""

    var pageCount: Int { pdfDocument?.pageCount ?? 0 }

    var unassignedPages: [Int] {
        assignments.filter { !$0.hasName }.map { $0.pageNumber }
    }

    // MARK: - Load PDF

    func loadPDF(from url: URL) {
        guard let document = PDFDocument(url: url) else {
            state = .error("Failed to open PDF file.")
            return
        }

        pdfDocument = document
        pdfURL = url
        pdfFilename = url.lastPathComponent
        // Default save destination to the PDF's containing folder.
        saveDestinationURL = url.deletingLastPathComponent()

        assignments = (0..<document.pageCount).map { index in
            PageAssignment(pageIndex: index, suggestedName: "", defendantName: "")
        }

        state = .loaded
        warningMessage = ""
        exportMessage = ""
        outputFolderURL = nil
        zipFileURL = nil
        groups = []
    }

    // MARK: - Save location

    /// Show an NSOpenPanel to let the user pick a different save destination.
    /// Returns true if the user picked a folder.
    @discardableResult
    func chooseSaveLocation() -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Choose where to save the split defendant PDFs"
        if let current = saveDestinationURL {
            panel.directoryURL = current
        }

        if panel.runModal() == .OK, let url = panel.url {
            saveDestinationURL = url
            return true
        }
        return false
    }

    // MARK: - Auto-detect names

    /// Auto-detect defendant names. Tries PDFKit text extraction first; falls back to
    /// Vision OCR for any page with no extractable text (typical for scanned court PDFs).
    func autoDetectNames() {
        guard let document = pdfDocument else { return }

        let total = document.pageCount
        isDetecting = true
        detectProgress = 0.0
        detectStatusText = "Reading PDF text..."
        warningMessage = ""

        // First pass on the main thread: PDFKit text extraction is cheap and synchronous.
        let pageTexts = PDFTextExtractor.extractAllPages(from: document)
        var ocrNeeded: [Int] = []
        var detectedCount = 0

        for i in 0..<assignments.count {
            if let text = pageTexts[i],
               let name = DefendantNameDetector.detectName(from: text) {
                assignments[i].suggestedName = name
                if !assignments[i].isEdited {
                    assignments[i].defendantName = name
                }
                detectedCount += 1
            } else {
                ocrNeeded.append(i)
            }
        }

        // If PDFKit got everything we need, finish synchronously.
        if ocrNeeded.isEmpty {
            isDetecting = false
            detectProgress = 1.0
            detectStatusText = ""
            warningMessage = "Detected names on \(detectedCount) of \(total) pages. Review and edit as needed."
            return
        }

        // Otherwise run OCR off the main thread.
        let initialDetected = detectedCount
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let pagesToOCR: [(Int, PDFPage)] = await MainActor.run {
                ocrNeeded.compactMap { idx in
                    guard let page = document.page(at: idx) else { return nil }
                    return (idx, page)
                }
            }

            var ocrDetected = 0
            for (count, item) in pagesToOCR.enumerated() {
                let (pageIndex, page) = item

                let progress = Double(count) / Double(pagesToOCR.count)
                let statusText = "OCR page \(pageIndex + 1) of \(total)..."
                await MainActor.run {
                    self.detectProgress = progress
                    self.detectStatusText = statusText
                }

                let detected: String? = {
                    do {
                        let text = try OCRService.extractText(from: page, pageIndex: pageIndex)
                        return DefendantNameDetector.detectName(from: text)
                    } catch {
                        return nil
                    }
                }()

                if let name = detected {
                    await MainActor.run {
                        if pageIndex < self.assignments.count {
                            self.assignments[pageIndex].suggestedName = name
                            if !self.assignments[pageIndex].isEdited {
                                self.assignments[pageIndex].defendantName = name
                            }
                        }
                    }
                    ocrDetected += 1
                }
            }

            await MainActor.run {
                self.isDetecting = false
                self.detectProgress = 1.0
                self.detectStatusText = ""
                let totalDetected = initialDetected + ocrDetected
                if totalDetected == 0 {
                    self.warningMessage = "No defendant names could be detected. Please review each page and enter names manually."
                } else {
                    self.warningMessage = "Detected names on \(totalDetected) of \(total) pages (OCR found \(ocrDetected)). Review and edit as needed."
                }
            }
        }
    }

    // MARK: - Update assignment

    func updateDefendantName(for id: UUID, name: String) {
        guard let index = assignments.firstIndex(where: { $0.id == id }) else { return }
        assignments[index].defendantName = name
        assignments[index].isEdited = true
    }

    // MARK: - Apply name to subsequent blank pages

    func applyNameToFollowingBlanks(from index: Int) {
        guard index < assignments.count else { return }
        let name = assignments[index].defendantName
        guard !name.isEmpty else { return }

        for i in (index + 1)..<assignments.count {
            if assignments[i].defendantName.isEmpty {
                assignments[i].defendantName = name
            } else {
                break
            }
        }
    }

    // MARK: - Export

    func prepareExport() {
        let unassigned = unassignedPages
        if !unassigned.isEmpty {
            let pageList = unassigned.prefix(10).map(String.init).joined(separator: ", ")
            let suffix = unassigned.count > 10 ? " and \(unassigned.count - 10) more" : ""
            warningMessage = "Pages without defendant names: \(pageList)\(suffix). All pages must have a name before exporting."
            return
        }

        groups = PDFExporter.buildGroups(from: assignments)
        showExportSummary = true
        warningMessage = ""
    }

    func performExport() {
        guard let document = pdfDocument else { return }
        guard let destination = saveDestinationURL else {
            state = .error("No save location selected.")
            return
        }

        state = .exporting

        do {
            let result = try PDFExporter.export(
                document: document,
                groups: groups,
                originalFilename: pdfFilename,
                parentDirectory: destination
            )

            let zipURL = try ZipService.zipFolder(
                at: result.outputFolderURL,
                originalPDFName: pdfFilename
            )

            outputFolderURL = result.outputFolderURL
            zipFileURL = zipURL
            exportMessage = "Exported \(result.exportedFiles.count) PDFs from \(result.totalPages) pages."
            state = .exported
            showExportSummary = false
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    // MARK: - Open output folder

    func openOutputFolder() {
        guard let url = outputFolderURL else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Reset

    func reset() {
        state = .idle
        pdfDocument = nil
        pdfURL = nil
        pdfFilename = ""
        saveDestinationURL = nil
        assignments = []
        groups = []
        showExportSummary = false
        outputFolderURL = nil
        zipFileURL = nil
        exportMessage = ""
        warningMessage = ""
        isDetecting = false
        detectProgress = 0.0
        detectStatusText = ""
    }

    // MARK: - Thumbnail

    func thumbnail(for pageIndex: Int, size: CGSize) -> NSImage? {
        guard let page = pdfDocument?.page(at: pageIndex) else { return nil }
        return page.thumbnail(of: size, for: .mediaBox)
    }
}
