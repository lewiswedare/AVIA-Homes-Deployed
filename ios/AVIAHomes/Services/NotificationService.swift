import Foundation
import Supabase

@Observable
class NotificationService {
    var notifications: [AppNotification] = []
    var isLoading = false

    private let supabase = SupabaseService.shared

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    func loadNotifications(for userId: String) async {
        guard supabase.isConfigured else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let rows: [NotificationRow] = try await supabase.client
                .from("notifications")
                .select()
                .eq("recipient_id", value: userId)
                .order("created_at", ascending: false)
                .limit(100)
                .execute()
                .value
            notifications = rows.map { $0.toAppNotification() }
        } catch {
            print("[NotificationService] loadNotifications FAILED: \(error)")
        }
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
        let notification = AppNotification(
            id: UUID().uuidString,
            recipientId: recipientId,
            senderId: senderId,
            senderName: senderName,
            type: type,
            title: title,
            message: message,
            referenceId: referenceId,
            referenceType: referenceType,
            createdAt: .now,
            isRead: false
        )

        if recipientId == notifications.first?.recipientId {
            notifications.insert(notification, at: 0)
        }

        guard supabase.isConfigured else { return }
        let row = NotificationRow(from: notification)
        _ = try? await supabase.client
            .from("notifications")
            .insert(row)
            .execute()
    }

    var onNotificationReceived: ((AppNotification) -> Void)?

    func subscribeToNotifications(for userId: String) {
        guard supabase.isConfigured else { return }
        let channel = supabase.client.realtimeV2.channel("notifications:\(userId)")
        supabase.realtimeChannels.append(channel)
        let changes = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "notifications",
            filter: .eq("recipient_id", value: userId)
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
        created_at = ISO8601DateFormatter().string(from: n.createdAt)
        is_read = n.isRead
    }

    func toAppNotification() -> AppNotification {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: created_at) ?? .now
        return AppNotification(
            id: id,
            recipientId: recipient_id,
            senderId: sender_id,
            senderName: sender_name,
            type: NotificationType(rawValue: type) ?? .newMessage,
            title: title,
            message: message,
            referenceId: reference_id,
            referenceType: reference_type,
            createdAt: date,
            isRead: is_read
        )
    }
}
