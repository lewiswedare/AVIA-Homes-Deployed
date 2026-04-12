import Foundation

nonisolated enum PlanStatus: String, Sendable {
    case draft = "Draft"
    case inReview = "In Review"
    case changesRequested = "Changes Requested"
    case approved = "Approved"
    case finalised = "Finalised"

    var icon: String {
        switch self {
        case .draft: "doc.badge.ellipsis"
        case .inReview: "eye.fill"
        case .changesRequested: "exclamationmark.bubble.fill"
        case .approved: "checkmark.seal.fill"
        case .finalised: "flag.checkered"
        }
    }
}

nonisolated enum MessageSender: String, Sendable {
    case client = "Client"
    case avia = "AVIA Homes"
}

nonisolated struct PlanCorrespondence: Identifiable, Sendable {
    let id: String
    let sender: MessageSender
    let senderName: String
    let message: String
    let date: Date
    let attachmentName: String?

    static let samples: [PlanCorrespondence] = []
}

nonisolated struct PlanDocument: Identifiable, Sendable {
    let id: String
    let name: String
    let type: PlanDocumentType
    let dateAdded: Date
    let fileSize: String
    let version: String
    let isFinal: Bool

    static let samples: [PlanDocument] = []
    static let finalSamples: [PlanDocument] = []
}

nonisolated enum PlanDocumentType: String, Sendable {
    case floorPlan = "Floor Plan"
    case elevation = "Elevations"
    case sitePlan = "Site Plan"
    case engineering = "Engineering"
    case electrical = "Electrical"
    case buildPlan = "Build Plans"

    var icon: String {
        switch self {
        case .floorPlan: "rectangle.split.2x2"
        case .elevation: "building.2.fill"
        case .sitePlan: "map.fill"
        case .engineering: "gearshape.2.fill"
        case .electrical: "bolt.fill"
        case .buildPlan: "hammer.fill"
        }
    }
}
