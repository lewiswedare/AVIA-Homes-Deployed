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

    private var currentUserId: String = ""

    func loadConversations(for userId: String) async {
        currentUserId = userId
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
            var result: [Conversation] = []
            for row in rows {
                var conv = row.toConversation()
                let unread = await fetchUnreadCount(conversationId: conv.id, userId: userId)
                conv.unreadCount = unread
                result.append(conv)
            }
            conversations = result
        } catch {
            print("[MessagingService] loadConversations FAILED: \(error)")
        }
    }

    private func fetchUnreadCount(conversationId: String, userId: String) async -> Int {
        guard supabase.isConfigured else { return 0 }
        do {
            let rows: [ChatMessageRow] = try await supabase.client
                .from("messages")
                .select()
                .eq("conversation_id", value: conversationId)
                .eq("is_read", value: false)
                .neq("sender_id", value: userId)
                .execute()
                .value
            return rows.count
        } catch {
            return 0
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

    func sendMessage(conversationId: String, senderId: String, content: String, attachmentUrl: String? = nil, attachmentType: String? = nil) async {
        let msg = ChatMessage(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: senderId,
            content: content,
            createdAt: .now,
            isRead: false,
            attachmentUrl: attachmentUrl,
            attachmentType: attachmentType
        )
        currentMessages.append(msg)

        let previewText: String = {
            if !content.isEmpty { return content }
            if let type = attachmentType, type.hasPrefix("image") { return "\u{1F4F7} Photo" }
            if attachmentUrl != nil { return "\u{1F4CE} Attachment" }
            return ""
        }()

        if let idx = conversations.firstIndex(where: { $0.id == conversationId }) {
            let old = conversations[idx]
            conversations[idx] = Conversation(
                id: old.id,
                participantIds: old.participantIds,
                lastMessage: previewText,
                lastMessageDate: .now,
                lastSenderId: senderId,
                unreadCount: old.unreadCount,
                createdAt: old.createdAt,
                conversationType: old.conversationType
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
            .update(["last_message": previewText, "last_message_date": ISO8601DateFormatter().string(from: .now), "last_sender_id": senderId])
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
            createdAt: .now,
            conversationType: "direct"
        )
        conversations.insert(newConv, at: 0)

        guard supabase.isConfigured else { return newConv.id }
        let row = ConversationInsertRow(from: newConv)
        _ = try? await supabase.client
            .from("conversations")
            .insert(row)
            .execute()

        return newConv.id
    }

    func getOrCreateGeneralConversation(currentUserId: String) async -> String {
        if let existing = conversations.first(where: {
            $0.conversationType == "general" && $0.participantIds.contains(currentUserId)
        }) {
            return existing.id
        }

        let newConv = Conversation(
            id: UUID().uuidString,
            participantIds: [currentUserId],
            lastMessage: "",
            lastMessageDate: .now,
            lastSenderId: "",
            unreadCount: 0,
            createdAt: .now,
            conversationType: "general"
        )
        conversations.insert(newConv, at: 0)

        guard supabase.isConfigured else { return newConv.id }
        let row = ConversationInsertRow(from: newConv)
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
                createdAt: old.createdAt,
                conversationType: old.conversationType
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
        supabase.realtimeChannels.append(channel)
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
    let last_message: String?
    let last_message_date: String
    let last_sender_id: String?
    let unread_count: Int?
    let created_at: String
    let conversation_type: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case id, participant_ids, last_message, last_message_date
        case last_sender_id, unread_count, created_at, conversation_type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        participant_ids = (try? container.decode([String].self, forKey: .participant_ids)) ?? []
        last_message = try? container.decode(String.self, forKey: .last_message)
        last_message_date = (try? container.decode(String.self, forKey: .last_message_date)) ?? ""
        last_sender_id = try? container.decode(String.self, forKey: .last_sender_id)
        unread_count = try? container.decode(Int.self, forKey: .unread_count)
        created_at = (try? container.decode(String.self, forKey: .created_at)) ?? ""
        conversation_type = try? container.decode(String.self, forKey: .conversation_type)
    }

    func toConversation() -> Conversation {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return Conversation(
            id: id,
            participantIds: participant_ids,
            lastMessage: last_message ?? "",
            lastMessageDate: formatter.date(from: last_message_date) ?? .now,
            lastSenderId: last_sender_id ?? "",
            unreadCount: unread_count ?? 0,
            createdAt: formatter.date(from: created_at) ?? .now,
            conversationType: conversation_type ?? "direct"
        )
    }
}

nonisolated struct ConversationInsertRow: Encodable, Sendable {
    let id: String
    let participant_ids: [String]
    let last_message: String
    let last_message_date: String
    let last_sender_id: String
    let unread_count: Int
    let conversation_type: String

    init(from c: Conversation) {
        id = c.id
        participant_ids = c.participantIds
        last_message = c.lastMessage
        last_message_date = ISO8601DateFormatter().string(from: c.lastMessageDate)
        last_sender_id = c.lastSenderId
        unread_count = c.unreadCount
        conversation_type = c.conversationType
    }
}

nonisolated struct ChatMessageRow: Codable, Sendable {
    let id: String
    let conversation_id: String
    let sender_id: String
    let content: String
    let created_at: String
    let is_read: Bool
    let attachment_url: String?
    let attachment_type: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case id, conversation_id, sender_id, content, created_at, is_read, attachment_url, attachment_type
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        conversation_id = try c.decode(String.self, forKey: .conversation_id)
        sender_id = try c.decode(String.self, forKey: .sender_id)
        content = (try? c.decode(String.self, forKey: .content)) ?? ""
        created_at = (try? c.decode(String.self, forKey: .created_at)) ?? ""
        is_read = (try? c.decode(Bool.self, forKey: .is_read)) ?? false
        attachment_url = try? c.decode(String.self, forKey: .attachment_url)
        attachment_type = try? c.decode(String.self, forKey: .attachment_type)
    }

    init(from m: ChatMessage) {
        id = m.id
        conversation_id = m.conversationId
        sender_id = m.senderId
        content = m.content
        created_at = ISO8601DateFormatter().string(from: m.createdAt)
        is_read = m.isRead
        attachment_url = m.attachmentUrl
        attachment_type = m.attachmentType
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
            isRead: is_read,
            attachmentUrl: attachment_url,
            attachmentType: attachment_type
        )
    }
}
