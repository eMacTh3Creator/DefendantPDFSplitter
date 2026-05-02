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
    @Published var pdfFilename: String = ""
    @Published var assignments: [PageAssignment] = []
    @Published var groups: [DefendantGroup] = []
    @Published var showExportSummary = false
    @Published var outputFolderURL: URL?
    @Published var zipFileURL: URL?
    @Published var exportMessage: String = ""
    @Published var warningMessage: String = ""

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
        pdfFilename = url.lastPathComponent

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

    // MARK: - Auto-detect names

    func autoDetectNames() {
        guard let document = pdfDocument else { return }

        let pageTexts = PDFTextExtractor.extractAllPages(from: document)
        var detectedCount = 0

        for i in 0..<assignments.count {
            guard let text = pageTexts[i] else { continue }
            if let name = DefendantNameDetector.detectName(from: text) {
                assignments[i].suggestedName = name
                if !assignments[i].isEdited {
                    assignments[i].defendantName = name
                }
                detectedCount += 1
            }
        }

        if detectedCount == 0 {
            warningMessage = "No defendant names could be auto-detected. This PDF may be scanned/image-based. Please enter names manually."
        } else {
            let total = assignments.count
            warningMessage = "Detected names on \(detectedCount) of \(total) pages. Review and edit as needed."
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

        state = .exporting

        do {
            let result = try PDFExporter.export(
                document: document,
                groups: groups,
                originalFilename: pdfFilename
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
        pdfFilename = ""
        assignments = []
        groups = []
        showExportSummary = false
        outputFolderURL = nil
        zipFileURL = nil
        exportMessage = ""
        warningMessage = ""
    }

    // MARK: - Thumbnail

    func thumbnail(for pageIndex: Int, size: CGSize) -> NSImage? {
        guard let page = pdfDocument?.page(at: pageIndex) else { return nil }
        return page.thumbnail(of: size, for: .mediaBox)
    }
}
