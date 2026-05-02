import Foundation
import PDFKit

struct PDFExporter {

    struct ExportResult {
        let outputFolderURL: URL
        let exportedFiles: [String]
        let totalPages: Int
    }

    /// Group consecutive pages with the same defendant name into DefendantGroup objects.
    /// Same defendant on consecutive pages = one group.
    /// Same defendant appearing non-consecutively = separate groups with numbered filenames.
    static func buildGroups(from assignments: [PageAssignment]) -> [DefendantGroup] {
        guard !assignments.isEmpty else { return [] }

        var groups: [DefendantGroup] = []
        var currentName = assignments[0].defendantName.trimmingCharacters(in: .whitespaces)
        var currentPages = [assignments[0].pageIndex]

        for i in 1..<assignments.count {
            let name = assignments[i].defendantName.trimmingCharacters(in: .whitespaces)
            if name == currentName {
                currentPages.append(assignments[i].pageIndex)
            } else {
                groups.append(DefendantGroup(
                    defendantName: currentName,
                    pageIndices: currentPages,
                    filename: ""
                ))
                currentName = name
                currentPages = [assignments[i].pageIndex]
            }
        }
        groups.append(DefendantGroup(
            defendantName: currentName,
            pageIndices: currentPages,
            filename: ""
        ))

        return assignFilenames(to: groups)
    }

    /// Assign filenames, handling duplicates with " - 2", " - 3", etc.
    private static func assignFilenames(to groups: [DefendantGroup]) -> [DefendantGroup] {
        var nameCount: [String: Int] = [:]
        var result: [DefendantGroup] = []

        for var group in groups {
            let sanitized = sanitizeFilename(group.defendantName)
            nameCount[sanitized, default: 0] += 1
            let count = nameCount[sanitized]!

            if count == 1 {
                group.filename = "\(sanitized).pdf"
            } else {
                group.filename = "\(sanitized) - \(count).pdf"
            }
            result.append(group)
        }

        return result
    }

    /// Export grouped PDFs to an output folder.
    static func export(
        document: PDFDocument,
        groups: [DefendantGroup],
        originalFilename: String
    ) throws -> ExportResult {
        let baseName = (originalFilename as NSString).deletingPathExtension
        let folderName = "split_defendants_\(baseName)"

        let desktopURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
        let outputURL = desktopURL.appendingPathComponent(folderName)

        // Remove existing folder if present
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        var exportedFiles: [String] = []
        var totalPages = 0

        for group in groups {
            let newDoc = PDFDocument()
            for (insertIndex, pageIndex) in group.pageIndices.enumerated() {
                guard let page = document.page(at: pageIndex) else {
                    throw ExportError.pageNotFound(pageIndex)
                }
                newDoc.insert(page, at: insertIndex)
            }

            let fileURL = outputURL.appendingPathComponent(group.filename)
            guard newDoc.write(to: fileURL) else {
                throw ExportError.writeFailed(group.filename)
            }

            exportedFiles.append(group.filename)
            totalPages += group.pageIndices.count
        }

        return ExportResult(
            outputFolderURL: outputURL,
            exportedFiles: exportedFiles,
            totalPages: totalPages
        )
    }

    /// Remove characters that are invalid in filenames.
    static func sanitizeFilename(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let components = name.unicodeScalars.filter { !invalidChars.contains($0) }
        let sanitized = String(String.UnicodeScalarView(components))
            .trimmingCharacters(in: .whitespaces)
        return sanitized.isEmpty ? "Unknown" : sanitized
    }

    enum ExportError: LocalizedError {
        case pageNotFound(Int)
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .pageNotFound(let index):
                return "Could not access page \(index + 1) from the source PDF."
            case .writeFailed(let filename):
                return "Failed to write PDF: \(filename)"
            }
        }
    }
}
