import Foundation

nonisolated enum RangeUpgradeStatus: String, Codable, Sendable {
    case pendingClient = "pending_client"
    case clientAccepted = "client_accepted"
    case clientDeclined = "client_declined"
    case adminApproved = "admin_approved"

    var displayLabel: String {
        switch self {
        case .pendingClient: "Awaiting Your Confirmation"
        case .clientAccepted: "Awaiting Admin Approval"
        case .clientDeclined: "Declined"
        case .adminApproved: "Approved"
        }
    }
}

nonisolated struct BuildRangeUpgradeRequestRow: Codable, Sendable, Identifiable {
    let id: String
    let build_id: String
    let from_tier: String
    let to_tier: String
    let cost: Double
    let status: String
    let client_notes: String?
    let admin_notes: String?
    let created_at: String?
    let updated_at: String?
}

struct BuildRangeUpgradeRequest: Identifiable, Sendable {
    let id: String
    let buildId: String
    let fromTier: String
    let toTier: String
    var cost: Double
    var status: RangeUpgradeStatus
    var clientNotes: String?
    var adminNotes: String?
}

extension BuildRangeUpgradeRequestRow {
    func toModel() -> BuildRangeUpgradeRequest {
        BuildRangeUpgradeRequest(
            id: id,
            buildId: build_id,
            fromTier: from_tier,
            toTier: to_tier,
            cost: cost,
            status: RangeUpgradeStatus(rawValue: status) ?? .pendingClient,
            clientNotes: client_notes,
            adminNotes: admin_notes
        )
    }
}

extension BuildRangeUpgradeRequest {
    func toRow() -> BuildRangeUpgradeRequestRow {
        let iso = ISO8601DateFormatter()
        return BuildRangeUpgradeRequestRow(
            id: id,
            build_id: buildId,
            from_tier: fromTier,
            to_tier: toTier,
            cost: cost,
            status: status.rawValue,
            client_notes: clientNotes,
            admin_notes: adminNotes,
            created_at: nil,
            updated_at: iso.string(from: .now)
        )
    }
}
