import Foundation
import UserNotifications
import UIKit
import Supabase

@Observable
class PushNotificationManager: NSObject {
    var isAuthorized = false
    var deviceToken: String?
    private var pendingUserId: String?

    private let supabase = SupabaseService.shared

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        } catch {
            isAuthorized = false
        }
    }

    func checkPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    func handleDeviceToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = tokenString

        if let userId = pendingUserId, !userId.isEmpty {
            Task {
                await saveTokenToServer(userId: userId)
            }
        }
    }

    func registerUser(_ userId: String) {
        pendingUserId = userId
        if deviceToken != nil {
            Task {
                await saveTokenToServer(userId: userId)
            }
        }
    }

    func saveTokenToServer(userId: String) async {
        guard let token = deviceToken, supabase.isConfigured, !userId.isEmpty else { return }
        let normalizedId = userId.lowercased()
        pendingUserId = normalizedId
        let row: [String: String] = [
            "id": UUID().uuidString,
            "user_id": normalizedId,
            "token": token,
            "platform": "ios",
            "updated_at": SupabaseDate.string(from: .now)
        ]
        do {
            try await supabase.client
                .from("device_tokens")
                .upsert(row, onConflict: "user_id,token")
                .execute()
        } catch {
            print("[PushNotificationManager] saveTokenToServer FAILED: \(error)")
        }
    }

    func removeToken(userId: String) async {
        guard let token = deviceToken, supabase.isConfigured else { return }
        _ = try? await supabase.client
            .from("device_tokens")
            .delete()
            .eq("user_id", value: userId.lowercased())
            .eq("token", value: token)
            .execute()
        pendingUserId = nil
    }

    func scheduleLocalNotification(title: String, body: String, identifier: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier ?? UUID().uuidString,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func updateBadgeCount(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }
}
