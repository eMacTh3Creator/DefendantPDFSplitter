import Foundation

struct ZipService {

    /// Create a ZIP archive of a folder.
    /// Uses /usr/bin/zip which is available on all macOS installations.
    static func zipFolder(at folderURL: URL, originalPDFName: String) throws -> URL {
        let baseName = (originalPDFName as NSString).deletingPathExtension
        let zipName = "\(baseName)_split_by_defendant.zip"
        let parentDir = folderURL.deletingLastPathComponent()
        let zipURL = parentDir.appendingPathComponent(zipName)

        // Remove existing zip if present
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try FileManager.default.removeItem(at: zipURL)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", "-j", zipURL.path, folderURL.path]
        process.currentDirectoryURL = parentDir

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ZipError.zipFailed(output)
        }

        return zipURL
    }

    enum ZipError: LocalizedError {
        case zipFailed(String)

        var errorDescription: String? {
            switch self {
            case .zipFailed(let output):
                return "ZIP creation failed: \(output)"
            }
        }
    }
}
