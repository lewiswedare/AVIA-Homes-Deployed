import Foundation

nonisolated enum DocumentCategory: String, CaseIterable, Sendable {
    case contracts = "Contracts"
    case plans = "Plans"
    case permits = "Permits"
    case certificates = "Certificates"
    case invoices = "Invoices"

    var icon: String {
        switch self {
        case .contracts: "doc.text.fill"
        case .plans: "ruler.fill"
        case .permits: "checkmark.seal.fill"
        case .certificates: "rosette"
        case .invoices: "dollarsign.circle.fill"
        }
    }
}

nonisolated struct ClientDocument: Identifiable, Sendable {
    let id: String
    let name: String
    let category: DocumentCategory
    let dateAdded: Date
    let fileSize: String
    let isNew: Bool
    let fileURL: String?

    init(id: String, name: String, category: DocumentCategory, dateAdded: Date, fileSize: String, isNew: Bool, fileURL: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.dateAdded = dateAdded
        self.fileSize = fileSize
        self.isNew = isNew
        self.fileURL = fileURL
    }

    static let samples: [ClientDocument] = []
}
