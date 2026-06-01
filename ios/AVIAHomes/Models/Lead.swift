import Foundation

// MARK: - Lead Source

nonisolated enum LeadSource: String, Codable, CaseIterable, Sendable, Identifiable {
    case website
    case social
    case referral
    case walkIn = "walk_in"
    case phone
    case event
    case other

    nonisolated var id: String { rawValue }

    var label: String {
        switch self {
        case .website: return "Website"
        case .social: return "Social Media"
        case .referral: return "Referral"
        case .walkIn: return "Walk-in"
        case .phone: return "Phone"
        case .event: return "Event"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .website: return "globe"
        case .social: return "bubble.left.and.bubble.right.fill"
        case .referral: return "person.2.fill"
        case .walkIn: return "figure.walk"
        case .phone: return "phone.fill"
        case .event: return "calendar.badge.plus"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Lead Kind

/// Where a record sits in the lead → opportunity → client progression.
nonisolated enum LeadKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case lead
    case opportunity
    case client

    nonisolated var id: String { rawValue }

    var label: String {
        switch self {
        case .lead: return "Lead"
        case .opportunity: return "Opportunity"
        case .client: return "Client"
        }
    }

    var icon: String {
        switch self {
        case .lead: return "person.crop.circle.badge.plus"
        case .opportunity: return "chart.line.uptrend.xyaxis"
        case .client: return "checkmark.seal.fill"
        }
    }
}

// MARK: - Lead

struct Lead: Identifiable, Hashable {
    let id: String
    var name: String
    var email: String?
    var phone: String?
    var source: LeadSource
    var message: String?
    var status: LeadStatus
    var temperature: LeadTemperature
    var ownerId: String?
    var notes: String?
    var convertedClientId: String?
    var kind: LeadKind
    var estimatedValue: Double?
    var expectedCloseDate: Date?
    var workflowCompletions: Set<String>
    var convertedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? (parts.last?.prefix(1) ?? "") : ""
        let result = "\(first)\(last)".uppercased()
        return result.isEmpty ? "?" : result
    }

    var isConverted: Bool { kind == .client || convertedClientId != nil }

    static func new(ownerId: String?) -> Lead {
        Lead(
            id: UUID().uuidString,
            name: "",
            email: nil,
            phone: nil,
            source: .website,
            message: nil,
            status: .new,
            temperature: .warm,
            ownerId: ownerId,
            notes: nil,
            convertedClientId: nil,
            kind: .lead,
            estimatedValue: nil,
            expectedCloseDate: nil,
            workflowCompletions: [],
            convertedAt: nil,
            createdAt: .now,
            updatedAt: .now
        )
    }
}

nonisolated struct LeadRow: Codable, Sendable {
    let id: String
    let name: String
    let email: String?
    let phone: String?
    let source: String
    let message: String?
    let status: String
    let temperature: String
    let owner_id: String?
    let notes: String?
    let converted_client_id: String?
    let kind: String?
    let estimated_value: Double?
    let expected_close_date: String?
    let workflow_completions: [String]?
    let converted_at: String?
    let created_at: String?
    let updated_at: String?

    init(lead: Lead) {
        let iso = ISO8601DateFormatter()
        self.id = lead.id
        self.name = lead.name
        self.email = lead.email
        self.phone = lead.phone
        self.source = lead.source.rawValue
        self.message = lead.message
        self.status = lead.status.rawValue
        self.temperature = lead.temperature.rawValue
        self.owner_id = lead.ownerId
        self.notes = lead.notes
        self.converted_client_id = lead.convertedClientId
        self.kind = lead.kind.rawValue
        self.estimated_value = lead.estimatedValue
        self.expected_close_date = lead.expectedCloseDate.map { iso.string(from: $0) }
        self.workflow_completions = Array(lead.workflowCompletions)
        self.converted_at = lead.convertedAt.map { iso.string(from: $0) }
        self.created_at = iso.string(from: lead.createdAt)
        self.updated_at = iso.string(from: lead.updatedAt)
    }

    func toLead() -> Lead {
        Lead(
            id: id,
            name: name,
            email: email,
            phone: phone,
            source: LeadSource(rawValue: source) ?? .other,
            message: message,
            status: LeadStatus(rawValue: status) ?? .new,
            temperature: LeadTemperature(rawValue: temperature) ?? .warm,
            ownerId: owner_id,
            notes: notes,
            convertedClientId: converted_client_id,
            kind: LeadKind(rawValue: kind ?? "lead") ?? .lead,
            estimatedValue: estimated_value,
            expectedCloseDate: ClientCRMProfileRow.parse(expected_close_date),
            workflowCompletions: Set(workflow_completions ?? []),
            convertedAt: ClientCRMProfileRow.parse(converted_at),
            createdAt: ClientCRMProfileRow.parse(created_at) ?? .now,
            updatedAt: ClientCRMProfileRow.parse(updated_at) ?? .now
        )
    }
}
