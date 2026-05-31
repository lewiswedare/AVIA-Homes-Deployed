import Foundation

/// A single email sent from the app via a staff member's Microsoft 365 account,
/// plus its open-tracking status.
struct EmailSend: Identifiable, Hashable {
    let id: String
    let clientId: String
    let senderId: String?
    let senderEmail: String?
    let senderName: String?
    let toEmail: String
    let subject: String
    let bodyPreview: String?
    let documentId: String?
    let documentName: String?
    let documentURL: String?
    let status: String
    let openCount: Int
    let firstOpenedAt: Date?
    let lastOpenedAt: Date?
    let createdAt: Date

    var isOpened: Bool { firstOpenedAt != nil }
    var didFail: Bool { status == "failed" }
}

nonisolated struct EmailSendRow: Codable, Sendable {
    let id: String
    let client_id: String
    let sender_id: String?
    let sender_email: String?
    let sender_name: String?
    let to_email: String
    let subject: String
    let body_preview: String?
    let document_id: String?
    let document_name: String?
    let document_url: String?
    let status: String?
    let open_count: Int?
    let first_opened_at: String?
    let last_opened_at: String?
    let created_at: String?

    func toEmailSend() -> EmailSend {
        EmailSend(
            id: id,
            clientId: client_id,
            senderId: sender_id,
            senderEmail: sender_email,
            senderName: sender_name,
            toEmail: to_email,
            subject: subject,
            bodyPreview: body_preview,
            documentId: document_id,
            documentName: document_name,
            documentURL: document_url,
            status: status ?? "sent",
            openCount: open_count ?? 0,
            firstOpenedAt: EmailSendRow.parse(first_opened_at),
            lastOpenedAt: EmailSendRow.parse(last_opened_at),
            createdAt: EmailSendRow.parse(created_at) ?? .now
        )
    }

    nonisolated static func parse(_ s: String?) -> Date? {
        guard let s else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withFraction.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }
}

/// Non-sensitive connection status the app reads to show "Connected as …".
struct MicrosoftAccount: Identifiable, Hashable, Sendable {
    var id: String { userId }
    let userId: String
    let email: String?
    let displayName: String?
    let connectedAt: Date?
}

nonisolated struct MicrosoftAccountRow: Codable, Sendable {
    let user_id: String
    let email: String?
    let display_name: String?
    let connected_at: String?

    func toAccount() -> MicrosoftAccount {
        MicrosoftAccount(
            userId: user_id,
            email: email,
            displayName: display_name,
            connectedAt: EmailSendRow.parse(connected_at)
        )
    }
}
