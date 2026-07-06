import Foundation
import PDFKit

struct PDFExporter {

    struct ExportResult {
        let outputFolderURL: URL
        let exportedFiles: [String]
        let totalPages: Int
    }

    /// Group consecutive pages with the same defendant name and compatible case number into DefendantGroup objects.
    /// Same defendant/case on consecutive pages = one group.
    /// Same defendant appearing non-consecutively = separate groups with numbered filenames.
    static func buildGroups(from assignments: [PageAssignment]) -> [DefendantGroup] {
        guard !assignments.isEmpty else { return [] }

        var groups: [DefendantGroup] = []
        var currentName = assignments[0].defendantName.trimmingCharacters(in: .whitespaces)
        var currentCaseNumber = assignments[0].caseNumber.trimmingCharacters(in: .whitespaces)
        var currentPages = [assignments[0].pageIndex]

        for i in 1..<assignments.count {
            let name = assignments[i].defendantName.trimmingCharacters(in: .whitespaces)
            let caseNumber = assignments[i].caseNumber.trimmingCharacters(in: .whitespaces)
            if name == currentName && caseNumbersCanBeGrouped(currentCaseNumber, caseNumber) {
                currentPages.append(assignments[i].pageIndex)
                if currentCaseNumber.isEmpty {
                    currentCaseNumber = caseNumber
                }
            } else {
                groups.append(DefendantGroup(
                    defendantName: currentName,
                    caseNumber: currentCaseNumber,
                    pageIndices: currentPages,
                    filename: ""
                ))
                currentName = name
                currentCaseNumber = caseNumber
                currentPages = [assignments[i].pageIndex]
            }
        }
        groups.append(DefendantGroup(
            defendantName: currentName,
            caseNumber: currentCaseNumber,
            pageIndices: currentPages,
            filename: ""
        ))

        return assignFilenames(to: groups)
    }

    /// Assign filenames, appending case numbers for repeated defendant names when available.
    private static func assignFilenames(to groups: [DefendantGroup]) -> [DefendantGroup] {
        var defendantNameCounts: [String: Int] = [:]
        for group in groups {
            let sanitizedName = sanitizeFilename(group.defendantName)
            defendantNameCounts[sanitizedName, default: 0] += 1
        }

        var filenameCount: [String: Int] = [:]
        var result: [DefendantGroup] = []

        for var group in groups {
            let sanitized = sanitizeFilename(group.defendantName)
            let caseComponent = sanitizeFilenameIdentifier(group.caseNumber)
            let baseName: String
            if defendantNameCounts[sanitized, default: 0] > 1 && !caseComponent.isEmpty {
                baseName = "\(sanitized) - \(caseComponent)"
            } else {
                baseName = sanitized
            }

            filenameCount[baseName, default: 0] += 1
            let count = filenameCount[baseName]!

            if count == 1 {
                group.filename = "\(baseName).pdf"
            } else {
                group.filename = "\(baseName) - \(count).pdf"
            }
            result.append(group)
        }

        return result
    }

    /// Export grouped PDFs to an output folder.
    /// `parentDirectory` is where the `split_defendants_<name>/` folder gets created.
    /// Pass the input PDF's parent directory for the typical workflow.
    static func export(
        document: PDFDocument,
        groups: [DefendantGroup],
        originalFilename: String,
        parentDirectory: URL
    ) throws -> ExportResult {
        let baseName = (originalFilename as NSString).deletingPathExtension
        let folderName = "split_defendants_\(baseName)"

        let outputURL = parentDirectory.appendingPathComponent(folderName)

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

    private static func caseNumbersCanBeGrouped(_ lhs: String, _ rhs: String) -> Bool {
        let left = normalizedCaseNumber(lhs)
        let right = normalizedCaseNumber(rhs)
        return left.isEmpty || right.isEmpty || left == right
    }

    private static func normalizedCaseNumber(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .uppercased()
    }

    private static func sanitizeFilenameIdentifier(_ identifier: String) -> String {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let scalars = trimmed.unicodeScalars.map { scalar -> UnicodeScalar in
            invalidChars.contains(scalar) ? "-" : scalar
        }
        let sanitized = String(String.UnicodeScalarView(scalars))
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "-.")))

        return sanitized
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
