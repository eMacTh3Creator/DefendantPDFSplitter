import Foundation

struct DefendantGroup: Identifiable {
    let id = UUID()
    let defendantName: String
    let pageIndices: [Int]
    var filename: String

    var pageRange: String {
        if pageIndices.count == 1 {
            return "Page \(pageIndices[0] + 1)"
        }
        let numbers = pageIndices.map { $0 + 1 }
        return "Pages \(numbers.map(String.init).joined(separator: ", "))"
    }

    var pageCount: Int { pageIndices.count }
}
