import Foundation

nonisolated enum NotificationType: String, Codable, Sendable {
    case packageShared = "package_shared"
    case packageApproved = "package_approved"
    case packageDeclined = "package_declined"
    case roleAssigned = "role_assigned"
    case requestSubmitted = "request_submitted"
    case requestResponse = "request_response"
    case buildUpdate = "build_update"
    case newMessage = "new_message"

    var icon: String {
        switch self {
        case .packageShared: "square.and.arrow.up.fill"
        case .packageApproved: "checkmark.circle.fill"
        case .packageDeclined: "xmark.circle.fill"
        case .roleAssigned: "person.badge.key.fill"
        case .requestSubmitted: "bubble.left.fill"
        case .requestResponse: "arrowshape.turn.up.left.fill"
        case .buildUpdate: "hammer.fill"
        case .newMessage: "message.fill"
        }
    }

    var color: String {
        switch self {
        case .packageShared: "teal"
        case .packageApproved: "success"
        case .packageDeclined: "destructive"
        case .roleAssigned: "teal"
        case .requestSubmitted: "warning"
        case .requestResponse: "teal"
        case .buildUpdate: "teal"
        case .newMessage: "teal"
        }
    }
}

nonisolated struct AppNotification: Identifiable, Sendable, Hashable {
    let id: String
    let recipientId: String
    let senderId: String?
    let senderName: String
    let type: NotificationType
    let title: String
    let message: String
    let referenceId: String?
    let createdAt: Date
    var isRead: Bool

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    nonisolated static func == (lhs: AppNotification, rhs: AppNotification) -> Bool {
        lhs.id == rhs.id && lhs.isRead == rhs.isRead
    }

    static let samples: [AppNotification] = []
}
