import Foundation

nonisolated struct ContractRow: Identifiable, Codable, Sendable {
    let id: String
    var eoi_id: String?
    var package_assignment_id: String?
    var build_id: String?
    var client_id: String
    var admin_id: String?
    var contract_url: String?
    var signed_contract_url: String?
    var status: String
    var sent_at: String?
    var signed_at: String?
    var notes: String?
    let created_at: String?
    let updated_at: String?

    var statusEnum: ContractStatus {
        ContractStatus(rawValue: status) ?? .draft
    }

    var displayStatus: String {
        statusEnum.displayLabel
    }
}

nonisolated enum ContractStatus: String, Codable, Sendable, CaseIterable {
    case draft
    case sent
    case signed
    case cancelled

    var displayLabel: String {
        switch self {
        case .draft: "Draft"
        case .sent: "Sent"
        case .signed: "Signed"
        case .cancelled: "Cancelled"
        }
    }

    var icon: String {
        switch self {
        case .draft: "doc.text.fill"
        case .sent: "paperplane.fill"
        case .signed: "checkmark.seal.fill"
        case .cancelled: "xmark.circle.fill"
        }
    }
}
