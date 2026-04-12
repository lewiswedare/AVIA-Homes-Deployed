import Foundation
import UIKit

nonisolated enum RequestStatus: String, CaseIterable, Sendable {
    case open = "Open"
    case inProgress = "In Progress"
    case resolved = "Resolved"
}

nonisolated enum RequestCategory: String, CaseIterable, Sendable {
    case general = "General"
    case defect = "Defect"
    case variation = "Variation"
    case maintenance = "Maintenance"

    var icon: String {
        switch self {
        case .general: "bubble.left.fill"
        case .defect: "exclamationmark.triangle.fill"
        case .variation: "arrow.triangle.branch"
        case .maintenance: "wrench.and.screwdriver.fill"
        }
    }
}

nonisolated struct RequestResponse: Identifiable, Sendable {
    let id: String
    let author: String
    let message: String
    let date: Date
    let isFromClient: Bool
}

nonisolated struct ServiceRequest: Identifiable, Sendable {
    let id: String
    let title: String
    let description: String
    let category: RequestCategory
    let status: RequestStatus
    let dateCreated: Date
    let lastUpdated: Date
    let responses: [RequestResponse]
    let attachedPhotos: [Data]

    static let samples: [ServiceRequest] = []
}
