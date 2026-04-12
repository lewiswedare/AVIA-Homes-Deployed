import Foundation
import Supabase

@Observable
class MessagingService {
    var conversations: [Conversation] = []
    var currentMessages: [ChatMessage] = []
    var isLoading = false

    private let supabase = SupabaseService.shared

    var totalUnreadCount: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }

    func loadConversations(for userId: String) async {
        guard supabase.isConfigured else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let rows: [ConversationRow] = try await supabase.client
                .from("conversations")
                .select()
                .contains("participant_ids", value: [userId])
                .order("last_message_date", ascending: false)
                .execute()
                .value
            conversations = rows.map { $0.toConversation() }
        } catch {
            print("[MessagingService] loadConversations FAILED: \(error)")
        }
    }

    func loadMessages(for conversationId: String) async {
        guard supabase.isConfigured else { return }
        do {
            let rows: [ChatMessageRow] = try await supabase.client
                .from("messages")
                .select()
                .eq("conversation_id", value: conversationId)
                .order("created_at", ascending: true)
                .limit(200)
                .execute()
                .value
            currentMessages = rows.map { $0.toChatMessage() }
        } catch {
            print("[MessagingService] loadMessages FAILED: \(error)")
        }
    }

    func sendMessage(conversationId: String, senderId: String, content: String) async {
        let msg = ChatMessage(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: senderId,
            content: content,
            createdAt: .now,
            isRead: false
        )
        currentMessages.append(msg)

        if let idx = conversations.firstIndex(where: { $0.id == conversationId }) {
            let old = conversations[idx]
            conversations[idx] = Conversation(
                id: old.id,
                participantIds: old.participantIds,
                lastMessage: content,
                lastMessageDate: .now,
                lastSenderId: senderId,
                unreadCount: old.unreadCount,
                createdAt: old.createdAt
            )
            conversations.sort { $0.lastMessageDate > $1.lastMessageDate }
        }

        guard supabase.isConfigured else { return }
        let row = ChatMessageRow(from: msg)
        _ = try? await supabase.client
            .from("messages")
            .insert(row)
            .execute()

        _ = try? await supabase.client
            .from("conversations")
            .update(["last_message": content, "last_message_date": ISO8601DateFormatter().string(from: .now), "last_sender_id": senderId])
            .eq("id", value: conversationId)
            .execute()
    }

    func getOrCreateConversation(currentUserId: String, otherUserId: String) async -> String {
        if let existing = conversations.first(where: {
            $0.participantIds.contains(currentUserId) && $0.participantIds.contains(otherUserId)
        }) {
            return existing.id
        }

        let newConv = Conversation(
            id: UUID().uuidString,
            participantIds: [currentUserId, otherUserId],
            lastMessage: "",
            lastMessageDate: .now,
            lastSenderId: "",
            unreadCount: 0,
            createdAt: .now
        )
        conversations.insert(newConv, at: 0)

        guard supabase.isConfigured else { return newConv.id }
        let row = ConversationRow(from: newConv)
        _ = try? await supabase.client
            .from("conversations")
            .insert(row)
            .execute()

        return newConv.id
    }

    func markConversationRead(conversationId: String, userId: String) async {
        if let idx = conversations.firstIndex(where: { $0.id == conversationId }) {
            let old = conversations[idx]
            conversations[idx] = Conversation(
                id: old.id,
                participantIds: old.participantIds,
                lastMessage: old.lastMessage,
                lastMessageDate: old.lastMessageDate,
                lastSenderId: old.lastSenderId,
                unreadCount: 0,
                createdAt: old.createdAt
            )
        }

        for i in currentMessages.indices {
            if currentMessages[i].senderId != userId {
                currentMessages[i].isRead = true
            }
        }

        guard supabase.isConfigured else { return }
        _ = try? await supabase.client
            .from("messages")
            .update(["is_read": true])
            .eq("conversation_id", value: conversationId)
            .neq("sender_id", value: userId)
            .execute()
    }

    func subscribeToMessages(conversationId: String) {
        guard supabase.isConfigured else { return }
        let channel = supabase.client.realtimeV2.channel("messages:\(conversationId)")
        let changes = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: .eq("conversation_id", value: conversationId)
        )
        Task {
            try? await channel.subscribeWithError()
            for await change in changes {
                if let row = try? change.decodeRecord(as: ChatMessageRow.self, decoder: JSONDecoder()) {
                    let msg = row.toChatMessage()
                    await MainActor.run {
                        if !self.currentMessages.contains(where: { $0.id == msg.id }) {
                            self.currentMessages.append(msg)
                        }
                    }
                }
            }
        }
    }
}

nonisolated struct ConversationRow: Codable, Sendable {
    let id: String
    let participant_ids: [String]
    let last_message: String
    let last_message_date: String
    let last_sender_id: String
    let unread_count: Int
    let created_at: String

    init(from c: Conversation) {
        id = c.id
        participant_ids = c.participantIds
        last_message = c.lastMessage
        last_message_date = ISO8601DateFormatter().string(from: c.lastMessageDate)
        last_sender_id = c.lastSenderId
        unread_count = c.unreadCount
        created_at = ISO8601DateFormatter().string(from: c.createdAt)
    }

    func toConversation() -> Conversation {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return Conversation(
            id: id,
            participantIds: participant_ids,
            lastMessage: last_message,
            lastMessageDate: formatter.date(from: last_message_date) ?? .now,
            lastSenderId: last_sender_id,
            unreadCount: unread_count,
            createdAt: formatter.date(from: created_at) ?? .now
        )
    }
}

nonisolated struct ChatMessageRow: Codable, Sendable {
    let id: String
    let conversation_id: String
    let sender_id: String
    let content: String
    let created_at: String
    let is_read: Bool

    init(from m: ChatMessage) {
        id = m.id
        conversation_id = m.conversationId
        sender_id = m.senderId
        content = m.content
        created_at = ISO8601DateFormatter().string(from: m.createdAt)
        is_read = m.isRead
    }

    func toChatMessage() -> ChatMessage {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return ChatMessage(
            id: id,
            conversationId: conversation_id,
            senderId: sender_id,
            content: content,
            createdAt: formatter.date(from: created_at) ?? .now,
            isRead: is_read
        )
    }
}
