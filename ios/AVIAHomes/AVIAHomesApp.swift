import SwiftUI
import UserNotifications

@main
struct AVIAHomesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appViewModel = AppViewModel()
    @State private var colourViewModel = ColourSelectionViewModel()
    @State private var specViewModel = SpecificationViewModel()
    @State private var journeyViewModel = CustomerJourneyViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appViewModel)
                .environment(colourViewModel)
                .environment(specViewModel)
                .environment(journeyViewModel)
                .preferredColorScheme(.light)
                .onAppear {
                    colourViewModel.specTier = specViewModel.currentTier
                    appDelegate.appViewModel = appViewModel
                    UNUserNotificationCenter.current().delegate = appDelegate
                    Task {
                        await appViewModel.restoreSession()
                        await appViewModel.pushManager.requestPermission()
                    }
                }
                .onChange(of: specViewModel.currentTier) { _, newTier in
                    colourViewModel.specTier = newTier
                }
                .onChange(of: appViewModel.totalBadgeCount) { _, newCount in
                    appViewModel.pushManager.updateBadgeCount(newCount)
                }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var appViewModel: AppViewModel?

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        appViewModel?.pushManager.handleDeviceToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {}

    nonisolated func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        await MainActor.run {
            if let userId = appViewModel?.currentUser.id, !userId.isEmpty {
                Task {
                    await appViewModel?.notificationService.loadNotifications(for: userId)
                }
            }
        }
        return .newData
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .badge, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        await MainActor.run {
            guard let vm = appViewModel else { return }
            let userId = vm.currentUser.id
            guard !userId.isEmpty else { return }
            if let notificationId = userInfo["notification_id"] as? String {
                Task {
                    await vm.notificationService.markAsRead(notificationId)
                }
            }
            Task {
                await vm.notificationService.loadNotifications(for: userId)
            }
        }
    }
}
