import Foundation

nonisolated struct Conversation: Identifiable, Sendable, Hashable {
    let id: String
    let participantIds: [String]
    let lastMessage: String
    let lastMessageDate: Date
    let lastSenderId: String
    var unreadCount: Int
    let createdAt: Date
    let conversationType: String

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    nonisolated static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        lhs.id == rhs.id
    }

    var isGeneral: Bool {
        conversationType == "general"
    }

    func otherParticipantId(currentUserId: String) -> String {
        participantIds.first { $0 != currentUserId } ?? ""
    }

    static let samples: [Conversation] = []
}

nonisolated struct ChatMessage: Identifiable, Sendable, Hashable {
    let id: String
    let conversationId: String
    let senderId: String
    let content: String
    let createdAt: Date
    var isRead: Bool

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    nonisolated static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }

    static let samples: [ChatMessage] = []
}
