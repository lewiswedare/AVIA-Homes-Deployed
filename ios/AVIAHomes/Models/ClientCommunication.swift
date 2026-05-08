import Foundation

nonisolated enum CommunicationKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case call
    case email
    case meeting
    case sms
    case note

    nonisolated var id: String { rawValue }

    var label: String {
        switch self {
        case .call: return "Call"
        case .email: return "Email"
        case .meeting: return "Meeting"
        case .sms: return "SMS"
        case .note: return "Log"
        }
    }

    var icon: String {
        switch self {
        case .call: return "phone.fill"
        case .email: return "envelope.fill"
        case .meeting: return "person.2.fill"
        case .sms: return "message.fill"
        case .note: return "doc.text.fill"
        }
    }
}

struct ClientCommunication: Identifiable, Hashable {
    let id: String
    let clientId: String
    var authorId: String?
    var kind: CommunicationKind
    var summary: String
    var occurredAt: Date
    var createdAt: Date
}

nonisolated struct ClientCommunicationRow: Codable, Sendable {
    let id: String
    let client_id: String
    let author_id: String?
    let kind: String
    let summary: String
    let occurred_at: String?
    let created_at: String?

    init(comm: ClientCommunication) {
        let iso = ISO8601DateFormatter()
        self.id = comm.id
        self.client_id = comm.clientId
        self.author_id = comm.authorId
        self.kind = comm.kind.rawValue
        self.summary = comm.summary
        self.occurred_at = iso.string(from: comm.occurredAt)
        self.created_at = iso.string(from: comm.createdAt)
    }

    func toComm() -> ClientCommunication {
        ClientCommunication(
            id: id,
            clientId: client_id,
            authorId: author_id,
            kind: CommunicationKind(rawValue: kind) ?? .note,
            summary: summary,
            occurredAt: ClientCRMProfileRow.parse(occurred_at) ?? .now,
            createdAt: ClientCRMProfileRow.parse(created_at) ?? .now
        )
    }
}
