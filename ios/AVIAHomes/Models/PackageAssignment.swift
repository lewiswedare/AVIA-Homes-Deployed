import Foundation

nonisolated struct PackageAssignment: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let packageId: String
    var assignedPartnerIds: [String]
    var sharedWithClientIds: [String]
    var clientResponses: [ClientPackageResponse]
    var isExclusive: Bool
    var assignedBy: String?
    var depositStatus: String
    var depositAmount: Double?
    var depositDueDate: String?
    var adminConfirmedBy: String?
    var adminConfirmedAt: String?

    init(id: String = UUID().uuidString, packageId: String, assignedPartnerIds: [String] = [], sharedWithClientIds: [String] = [], clientResponses: [ClientPackageResponse] = [], isExclusive: Bool = false, assignedBy: String? = nil, depositStatus: String = "pending", depositAmount: Double? = nil, depositDueDate: String? = nil, adminConfirmedBy: String? = nil, adminConfirmedAt: String? = nil) {
        self.id = id
        self.packageId = packageId
        self.assignedPartnerIds = assignedPartnerIds
        self.sharedWithClientIds = sharedWithClientIds
        self.clientResponses = clientResponses
        self.isExclusive = isExclusive
        self.assignedBy = assignedBy
        self.depositStatus = depositStatus
        self.depositAmount = depositAmount
        self.depositDueDate = depositDueDate
        self.adminConfirmedBy = adminConfirmedBy
        self.adminConfirmedAt = adminConfirmedAt
    }
}

nonisolated struct ClientPackageResponse: Codable, Sendable, Hashable, Identifiable {
    var id: String { clientId }
    let clientId: String
    let status: PackageResponseStatus
    let respondedDate: Date?
    let notes: String?

    init(clientId: String, status: PackageResponseStatus = .pending, respondedDate: Date? = nil, notes: String? = nil) {
        self.clientId = clientId
        self.status = status
        self.respondedDate = respondedDate
        self.notes = notes
    }
}

extension PackageAssignment {
    static let sampleAssignments: [PackageAssignment] = []
}

nonisolated enum PackageResponseStatus: String, Codable, Sendable, CaseIterable {
    case pending = "Pending Review"
    case accepted = "Accepted"
    case declined = "Declined"

    var icon: String {
        switch self {
        case .pending: "clock.fill"
        case .accepted: "checkmark.circle.fill"
        case .declined: "xmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .pending: "warning"
        case .accepted: "success"
        case .declined: "destructive"
        }
    }
}
