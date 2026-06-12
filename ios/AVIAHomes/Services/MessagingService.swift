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

    /// Loads every conversation the user participates in.
    /// Staff/admin users also see all "general" (Message AVIA) threads, which
    /// only contain the client in `participant_ids` — without this, client
    /// messages to the AVIA team were invisible to every staff member.
    func loadConversations(for userId: String, includeGeneral: Bool = false) async {
        guard !userId.isEmpty else { return }
        let normalizedId = userId.lowercased()
        currentUserId = normalizedId
        guard supabase.isConfigured else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let base = supabase.client.from("conversations").select()
            let filtered = includeGeneral
                ? base.or("participant_ids.cs.{\(normalizedId)},conversation_type.eq.general")
                : base.contains("participant_ids", value: [normalizedId])
            let rows: [ConversationRow] = try await filtered
                .order("last_message_date", ascending: false)
                .execute()
                .value
            var result = rows.map { $0.toConversation() }
            let unreadCounts = await fetchUnreadCounts(
                conversationIds: result.map(\.id),
                userId: normalizedId
            )
            for idx in result.indices {
                result[idx].unreadCount = unreadCounts[result[idx].id] ?? 0
            }
            conversations = result
        } catch {
            print("[MessagingService] loadConversations FAILED: \(error)")
        }
    }

    /// Single batched query for unread counts across all conversations —
    /// replaces the previous one-query-per-conversation pattern that made
    /// the Messages tab progressively slower as conversations grew.
    private func fetchUnreadCounts(conversationIds: [String], userId: String) async -> [String: Int] {
        guard supabase.isConfigured, !conversationIds.isEmpty else { return [:] }
        struct UnreadRow: Decodable { let conversation_id: String }
        do {
            let rows: [UnreadRow] = try await supabase.client
                .from("messages")
                .select("conversation_id")
                .in("conversation_id", values: conversationIds)
                .eq("is_read", value: false)
                .neq("sender_id", value: userId)
                .execute()
                .value
            return rows.reduce(into: [:]) { counts, row in
                counts[row.conversation_id, default: 0] += 1
            }
        } catch {
            print("[MessagingService] fetchUnreadCounts FAILED: \(error)")
            return [:]
        }
    }

    func loadMessages(for conversationId: String) async {
        guard supabase.isConfigured else { return }
        do {
            // Fetch the NEWEST 200 messages (descending), then restore
            // chronological order for display. Previously this loaded the
            // oldest 200, so long threads stopped showing new messages.
            let rows: [ChatMessageRow] = try await supabase.client
                .from("messages")
                .select()
                .eq("conversation_id", value: conversationId)
                .order("created_at", ascending: false)
                .limit(200)
                .execute()
                .value
            currentMessages = rows.map { $0.toChatMessage() }.reversed()
        } catch {
            print("[MessagingService] loadMessages FAILED: \(error)")
        }
    }

    /// Sends a message with optimistic UI. Returns false when the server
    /// insert fails — the optimistic message is rolled back so the user sees
    /// the failure instead of a phantom message that silently never sent.
    @discardableResult
    func sendMessage(conversationId: String, senderId: String, content: String, attachmentUrl: String? = nil, attachmentType: String? = nil) async -> Bool {
        let msg = ChatMessage(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: senderId.lowercased(),
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

        guard supabase.isConfigured else { return false }
        let row = ChatMessageRow(from: msg)
        do {
            try await supabase.client
                .from("messages")
                .insert(row)
                .execute()
        } catch {
            print("[MessagingService] sendMessage insert FAILED: \(error)")
            // Roll back the optimistic append so the UI doesn't show a
            // message that never reached the server.
            currentMessages.removeAll { $0.id == msg.id }
            return false
        }

        do {
            try await supabase.client
                .from("conversations")
                .update(["last_message": previewText, "last_message_date": SupabaseDate.string(from: .now), "last_sender_id": senderId.lowercased()])
                .eq("id", value: conversationId)
                .execute()
        } catch {
            // The message itself was stored; a stale conversation preview is
            // self-healing on the next send or reload.
            print("[MessagingService] sendMessage conversation update FAILED: \(error)")
        }
        return true
    }

    func getOrCreateConversation(currentUserId: String, otherUserId: String) async -> String {
        let meId = currentUserId.lowercased()
        let otherId = otherUserId.lowercased()
        // Only match DIRECT threads — previously a general/group thread that
        // happened to contain both users hijacked the lookup and new messages
        // landed in the wrong conversation.
        if let existing = conversations.first(where: { conv in
            conv.conversationType == "direct" &&
            conv.participantIds.contains(where: { $0.lowercased() == meId }) &&
            conv.participantIds.contains(where: { $0.lowercased() == otherId })
        }) {
            return existing.id
        }

        let newConv = Conversation(
            id: UUID().uuidString,
            participantIds: [meId, otherId],
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
        let meId = currentUserId.lowercased()
        if let existing = conversations.first(where: { conv in
            conv.conversationType == "general" &&
            conv.participantIds.contains(where: { $0.lowercased() == meId })
        }) {
            return existing.id
        }

        let newConv = Conversation(
            id: UUID().uuidString,
            participantIds: [meId],
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
            .neq("sender_id", value: userId.lowercased())
            .execute()
    }

    /// The conversation the user currently has open. Foreground handling
    /// resubscribes it after the OS tears realtime down in the background.
    private(set) var activeConversationId: String?

    /// Rebuilds the per-conversation channel for the open chat after all
    /// realtime channels were removed (background → foreground cycle).
    func resubscribeActiveConversation() {
        guard let id = activeConversationId else { return }
        subscribeToMessages(conversationId: id)
    }

    func subscribeToMessages(conversationId: String) {
        activeConversationId = conversationId
        guard supabase.isConfigured else { return }
        // makeChannel() dedupes by topic — re-opening the same chat no longer
        // stacks an extra realtime channel each time.
        guard let channel = supabase.makeChannel("messages:\(conversationId)") else { return }
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
        Conversation(
            id: id,
            participantIds: participant_ids.map { $0.lowercased() },
            lastMessage: last_message ?? "",
            lastMessageDate: SupabaseDate.parse(last_message_date, default: .distantPast),
            lastSenderId: (last_sender_id ?? "").lowercased(),
            unreadCount: unread_count ?? 0,
            createdAt: SupabaseDate.parse(created_at, default: .distantPast),
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
        participant_ids = c.participantIds.map { $0.lowercased() }
        last_message = c.lastMessage
        last_message_date = SupabaseDate.string(from: c.lastMessageDate)
        last_sender_id = c.lastSenderId.lowercased()
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
        sender_id = m.senderId.lowercased()
        content = m.content
        created_at = SupabaseDate.string(from: m.createdAt)
        is_read = m.isRead
        attachment_url = m.attachmentUrl
        attachment_type = m.attachmentType
    }

    func toChatMessage() -> ChatMessage {
        ChatMessage(
            id: id,
            conversationId: conversation_id,
            senderId: sender_id.lowercased(),
            content: content,
            createdAt: SupabaseDate.parse(created_at, default: .now),
            isRead: is_read,
            attachmentUrl: attachment_url,
            attachmentType: attachment_type
        )
    }
}
