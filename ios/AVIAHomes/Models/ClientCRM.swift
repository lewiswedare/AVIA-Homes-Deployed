import Foundation

// MARK: - Lead Status

nonisolated enum LeadStatus: String, Codable, CaseIterable, Sendable, Identifiable {
    case new
    case contacted
    case qualified
    case proposal
    case negotiation
    case won
    case lost

    nonisolated var id: String { rawValue }

    var label: String {
        switch self {
        case .new: return "New"
        case .contacted: return "Contacted"
        case .qualified: return "Qualified"
        case .proposal: return "Proposal"
        case .negotiation: return "Negotiation"
        case .won: return "Won"
        case .lost: return "Lost"
        }
    }

    var icon: String {
        switch self {
        case .new: return "sparkle"
        case .contacted: return "phone.connection.fill"
        case .qualified: return "checkmark.seal.fill"
        case .proposal: return "doc.text.fill"
        case .negotiation: return "arrow.left.arrow.right"
        case .won: return "trophy.fill"
        case .lost: return "xmark.seal.fill"
        }
    }
}

nonisolated enum LeadTemperature: String, Codable, CaseIterable, Sendable, Identifiable {
    case hot
    case warm
    case cold

    nonisolated var id: String { rawValue }

    var label: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .hot: return "flame.fill"
        case .warm: return "sun.max.fill"
        case .cold: return "snowflake"
        }
    }
}

// MARK: - CRM Profile

struct ClientCRMProfile: Identifiable, Hashable {
    let clientId: String
    var leadStatus: LeadStatus
    var leadTemperature: LeadTemperature
    var tags: [String]
    var ownerId: String?
    var lastContactedAt: Date?
    var nextFollowUpAt: Date?
    var lifetimeValue: Double
    var updatedAt: Date

    var id: String { clientId }

    static func empty(clientId: String) -> ClientCRMProfile {
        ClientCRMProfile(
            clientId: clientId,
            leadStatus: .new,
            leadTemperature: .warm,
            tags: [],
            ownerId: nil,
            lastContactedAt: nil,
            nextFollowUpAt: nil,
            lifetimeValue: 0,
            updatedAt: .now
        )
    }
}

nonisolated struct ClientCRMProfileRow: Codable, Sendable {
    let client_id: String
    let lead_status: String
    let lead_temperature: String
    let tags: [String]?
    let owner_id: String?
    let last_contacted_at: String?
    let next_follow_up_at: String?
    let lifetime_value: Double?
    let updated_at: String?

    init(profile: ClientCRMProfile) {
        let iso = ISO8601DateFormatter()
        self.client_id = profile.clientId
        self.lead_status = profile.leadStatus.rawValue
        self.lead_temperature = profile.leadTemperature.rawValue
        self.tags = profile.tags
        self.owner_id = profile.ownerId
        self.last_contacted_at = profile.lastContactedAt.map { iso.string(from: $0) }
        self.next_follow_up_at = profile.nextFollowUpAt.map { iso.string(from: $0) }
        self.lifetime_value = profile.lifetimeValue
        self.updated_at = iso.string(from: profile.updatedAt)
    }

    func toProfile() -> ClientCRMProfile {
        ClientCRMProfile(
            clientId: client_id,
            leadStatus: LeadStatus(rawValue: lead_status) ?? .new,
            leadTemperature: LeadTemperature(rawValue: lead_temperature) ?? .warm,
            tags: tags ?? [],
            ownerId: owner_id,
            lastContactedAt: ClientCRMProfileRow.parse(last_contacted_at),
            nextFollowUpAt: ClientCRMProfileRow.parse(next_follow_up_at),
            lifetimeValue: lifetime_value ?? 0,
            updatedAt: ClientCRMProfileRow.parse(updated_at) ?? .now
        )
    }

    static func parse(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }
}

// MARK: - Notes

struct ClientNote: Identifiable, Hashable {
    let id: String
    let clientId: String
    var authorId: String?
    var body: String
    var pinned: Bool
    var createdAt: Date
    var updatedAt: Date
}

nonisolated struct ClientNoteRow: Codable, Sendable {
    let id: String
    let client_id: String
    let author_id: String?
    let body: String
    let pinned: Bool?
    let created_at: String?
    let updated_at: String?

    init(note: ClientNote) {
        let iso = ISO8601DateFormatter()
        self.id = note.id
        self.client_id = note.clientId
        self.author_id = note.authorId
        self.body = note.body
        self.pinned = note.pinned
        self.created_at = iso.string(from: note.createdAt)
        self.updated_at = iso.string(from: note.updatedAt)
    }

    func toNote() -> ClientNote {
        ClientNote(
            id: id,
            clientId: client_id,
            authorId: author_id,
            body: body,
            pinned: pinned ?? false,
            createdAt: ClientCRMProfileRow.parse(created_at) ?? .now,
            updatedAt: ClientCRMProfileRow.parse(updated_at) ?? .now
        )
    }
}

// MARK: - Tasks

nonisolated enum TaskPriority: String, Codable, CaseIterable, Sendable {
    case low, normal, high

    var label: String { rawValue.capitalized }
}

struct ClientTask: Identifiable, Hashable {
    let id: String
    /// nil for general team to-dos that aren't tied to a specific client.
    let clientId: String?
    var title: String
    var detail: String?
    var dueAt: Date?
    var completedAt: Date?
    var assigneeId: String?
    var createdBy: String?
    var priority: TaskPriority
    var createdAt: Date

    var isCompleted: Bool { completedAt != nil }

    var isOverdue: Bool {
        guard !isCompleted, let due = dueAt else { return false }
        return due < .now
    }
}

nonisolated struct ClientTaskRow: Codable, Sendable {
    let id: String
    let client_id: String?
    let title: String
    let detail: String?
    let due_at: String?
    let completed_at: String?
    let assignee_id: String?
    let created_by: String?
    let priority: String?
    let created_at: String?

    init(task: ClientTask) {
        let iso = ISO8601DateFormatter()
        self.id = task.id
        self.client_id = task.clientId
        self.title = task.title
        self.detail = task.detail
        self.due_at = task.dueAt.map { iso.string(from: $0) }
        self.completed_at = task.completedAt.map { iso.string(from: $0) }
        self.assignee_id = task.assigneeId
        self.created_by = task.createdBy
        self.priority = task.priority.rawValue
        self.created_at = iso.string(from: task.createdAt)
    }

    func toTask() -> ClientTask {
        ClientTask(
            id: id,
            clientId: client_id,
            title: title,
            detail: detail,
            dueAt: ClientCRMProfileRow.parse(due_at),
            completedAt: ClientCRMProfileRow.parse(completed_at),
            assigneeId: assignee_id,
            createdBy: created_by,
            priority: TaskPriority(rawValue: priority ?? "normal") ?? .normal,
            createdAt: ClientCRMProfileRow.parse(created_at) ?? .now
        )
    }
}

// MARK: - Stage Completions (manual completion of automated workflow steps)

/// A manual override marking an automated lifecycle requirement as done for a client.
struct StageCompletion: Identifiable, Hashable {
    let id: String
    let clientId: String
    let requirementId: String
    var leadStatus: String?
    var completedAt: Date
    var completedBy: String?
}

nonisolated struct StageCompletionRow: Codable, Sendable {
    let id: String
    let client_id: String
    let requirement_id: String
    let lead_status: String?
    let completed_at: String?
    let completed_by: String?

    init(completion: StageCompletion) {
        let iso = ISO8601DateFormatter()
        self.id = completion.id
        self.client_id = completion.clientId
        self.requirement_id = completion.requirementId
        self.lead_status = completion.leadStatus
        self.completed_at = iso.string(from: completion.completedAt)
        self.completed_by = completion.completedBy
    }

    func toCompletion() -> StageCompletion {
        StageCompletion(
            id: id,
            clientId: client_id,
            requirementId: requirement_id,
            leadStatus: lead_status,
            completedAt: ClientCRMProfileRow.parse(completed_at) ?? .now,
            completedBy: completed_by
        )
    }
}
