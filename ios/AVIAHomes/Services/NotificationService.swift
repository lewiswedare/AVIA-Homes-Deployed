import Foundation
import Supabase

@Observable
class NotificationService {
    var notifications: [AppNotification] = []
    var isLoading = false

    /// The user whose notifications are currently loaded. Used so that
    /// locally-created notifications only appear in the in-app list when
    /// they actually belong to the signed-in user.
    private(set) var activeRecipientId: String?

    private let supabase = SupabaseService.shared

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    func loadNotifications(for userId: String) async {
        guard supabase.isConfigured, !userId.isEmpty else { return }
        activeRecipientId = userId.lowercased()
        isLoading = true
        defer { isLoading = false }
        do {
            let rows: [NotificationRow] = try await supabase.client
                .from("notifications")
                .select()
                .eq("recipient_id", value: userId.lowercased())
                .order("created_at", ascending: false)
                .limit(100)
                .execute()
                .value
            notifications = rows.map { $0.toAppNotification() }
        } catch {
            print("[NotificationService] loadNotifications FAILED: \(error)")
        }
    }

    /// Clears all local state on sign-out.
    func reset() {
        notifications = []
        activeRecipientId = nil
    }

    func markAsRead(_ notificationId: String) async {
        guard let idx = notifications.firstIndex(where: { $0.id == notificationId }) else { return }
        notifications[idx].isRead = true
        guard supabase.isConfigured else { return }
        _ = try? await supabase.client
            .from("notifications")
            .update(["is_read": true])
            .eq("id", value: notificationId)
            .execute()
    }

    func markAllAsRead(for userId: String) async {
        for i in notifications.indices {
            notifications[i].isRead = true
        }
        guard supabase.isConfigured else { return }
        _ = try? await supabase.client
            .from("notifications")
            .update(["is_read": true])
            .eq("recipient_id", value: userId)
            .eq("is_read", value: false)
            .execute()
    }

    func createNotification(
        recipientId: String,
        senderId: String?,
        senderName: String,
        type: NotificationType,
        title: String,
        message: String,
        referenceId: String? = nil,
        referenceType: String? = nil
    ) async {
        guard !recipientId.isEmpty else { return }
        let notification = AppNotification(
            id: UUID().uuidString,
            recipientId: recipientId.lowercased(),
            senderId: senderId?.lowercased(),
            senderName: senderName,
            type: type,
            title: title,
            message: message,
            referenceId: referenceId,
            referenceType: referenceType,
            createdAt: .now,
            isRead: false
        )

        // Only mirror into the local list if this notification is addressed
        // to the signed-in user (e.g. self-notifications), never someone else's.
        if notification.recipientId == activeRecipientId {
            notifications.insert(notification, at: 0)
        }

        guard supabase.isConfigured else { return }
        let row = NotificationRow(from: notification)
        do {
            try await supabase.client
                .from("notifications")
                .insert(row)
                .execute()
        } catch {
            print("[NotificationService] createNotification FAILED for type=\(type.rawValue): \(error)")
        }
    }

    /// Fan-out helper: creates the same notification for many recipients in a
    /// SINGLE bulk insert instead of one request per recipient (the old N+1
    /// pattern made a 20-staff fan-out take 20 round-trips and often dropped
    /// some on flaky connections).
    func createNotifications(
        recipientIds: [String],
        senderId: String?,
        senderName: String,
        type: NotificationType,
        title: String,
        message: String,
        referenceId: String? = nil,
        referenceType: String? = nil
    ) async {
        let uniqueIds = Array(Set(recipientIds.map { $0.lowercased() })).filter { !$0.isEmpty }
        guard !uniqueIds.isEmpty else { return }

        let items: [AppNotification] = uniqueIds.map { recipientId in
            AppNotification(
                id: UUID().uuidString,
                recipientId: recipientId,
                senderId: senderId?.lowercased(),
                senderName: senderName,
                type: type,
                title: title,
                message: message,
                referenceId: referenceId,
                referenceType: referenceType,
                createdAt: .now,
                isRead: false
            )
        }

        if let mine = items.first(where: { $0.recipientId == activeRecipientId }) {
            notifications.insert(mine, at: 0)
        }

        guard supabase.isConfigured else { return }
        let rows = items.map { NotificationRow(from: $0) }
        do {
            try await supabase.client
                .from("notifications")
                .insert(rows)
                .execute()
        } catch {
            print("[NotificationService] createNotifications FAILED for type=\(type.rawValue) count=\(rows.count): \(error)")
        }
    }

    var onNotificationReceived: ((AppNotification) -> Void)?

    func subscribeToNotifications(for userId: String) {
        guard supabase.isConfigured, !userId.isEmpty else { return }
        let normalizedId = userId.lowercased()
        activeRecipientId = normalizedId
        // makeChannel() dedupes by topic so repeated calls (foreground cycles,
        // multiple tab roots) never stack duplicate subscriptions.
        guard let channel = supabase.makeChannel("notifications:\(normalizedId)") else { return }
        let changes = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "notifications",
            filter: .eq("recipient_id", value: normalizedId)
        )
        Task {
            try? await channel.subscribeWithError()
            for await change in changes {
                if let row = try? change.decodeRecord(as: NotificationRow.self, decoder: JSONDecoder()) {
                    let notif = row.toAppNotification()
                    await MainActor.run {
                        if !self.notifications.contains(where: { $0.id == notif.id }) {
                            self.notifications.insert(notif, at: 0)
                            self.onNotificationReceived?(notif)
                        }
                    }
                }
            }
        }
    }
}

nonisolated struct NotificationRow: Codable, Sendable {
    let id: String
    let recipient_id: String
    let sender_id: String?
    let sender_name: String
    let type: String
    let title: String
    let message: String
    let reference_id: String?
    let reference_type: String?
    let created_at: String
    let is_read: Bool

    init(from n: AppNotification) {
        id = n.id
        recipient_id = n.recipientId
        sender_id = n.senderId
        sender_name = n.senderName
        type = n.type.rawValue
        title = n.title
        message = n.message
        reference_id = n.referenceId
        reference_type = n.referenceType
        created_at = SupabaseDate.string(from: n.createdAt)
        is_read = n.isRead
    }

    func toAppNotification() -> AppNotification {
        AppNotification(
            id: id,
            recipientId: recipient_id.lowercased(),
            senderId: sender_id?.lowercased(),
            senderName: sender_name,
            type: NotificationType(rawValue: type) ?? .newMessage,
            title: title,
            message: message,
            referenceId: reference_id,
            referenceType: reference_type,
            createdAt: SupabaseDate.parse(created_at, default: .now),
            isRead: is_read
        )
    }
}
