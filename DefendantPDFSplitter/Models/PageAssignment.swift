import Foundation

struct PageAssignment: Identifiable {
    let id = UUID()
    let pageIndex: Int
    var suggestedName: String
    var defendantName: String
    var isEdited: Bool = false

    var pageNumber: Int { pageIndex + 1 }

    var hasName: Bool {
        !defendantName.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
