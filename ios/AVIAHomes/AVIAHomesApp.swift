import SwiftUI
import UserNotifications

@main
struct AVIAHomesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
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
                        if let firstBuild = appViewModel.clientBuildsForCurrentUser.first {
                            await specViewModel.load(buildId: firstBuild.id)
                        }
                        await appViewModel.pushManager.requestPermission()
                    }
                }
                .onChange(of: specViewModel.currentTier) { _, newTier in
                    colourViewModel.specTier = newTier
                }
                .onChange(of: appViewModel.totalBadgeCount) { _, newCount in
                    appViewModel.pushManager.updateBadgeCount(newCount)
                }
                .onChange(of: appViewModel.activeClientCount) { _, _ in
                    if let first = appViewModel.clientBuildsForCurrentUser.first {
                        Task { await specViewModel.load(buildId: first.id) }
                    }
                }
                // Rebuild realtime + refetch everything when the app returns to the foreground,
                // and tear realtime down cleanly when backgrounded. This is the single biggest
                // fix for the "close-and-reopen to refresh" bug.
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        Task { await appViewModel.handleForeground() }
                    case .background:
                        Task { await appViewModel.handleBackground() }
                    default:
                        break
                    }
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
            // Always refresh the notification list.
            Task {
                await vm.notificationService.loadNotifications(for: userId)
            }
            // Route to the matching data refetch so the user never opens a
            // build/invoice/conversation from a push and sees stale content.
            let type = (userInfo["type"] as? String) ?? ""
            let buildId = userInfo["build_id"] as? String
            switch type {
            case let t where t.hasPrefix("spec_selection") || t.hasPrefix("colour_selection"):
                Task {
                    await vm.loadPendingSpecReviews()
                    await vm.loadBuildsFromSupabase()
                    if let bid = buildId {
                        NotificationCenter.default.post(
                            name: .aviaBuildNeedsRefresh,
                            object: nil,
                            userInfo: ["buildId": bid]
                        )
                    }
                }
            case let t where t.hasPrefix("build_milestone") || t.hasPrefix("build_reminder"):
                Task {
                    await vm.loadMilestonesForCurrentBuilds()
                    await vm.loadRemindersForCurrentUser()
                    await vm.loadBuildsFromSupabase()
                }
            case let t where t.hasPrefix("invoice") || t.hasPrefix("contract") || t.hasPrefix("eoi"):
                Task { await vm.loadBuildsFromSupabase() }
            case let t where t.hasPrefix("message"):
                Task { await vm.messagingService.loadConversations(for: userId) }
            default:
                // Unknown push — do a safe broad refresh.
                Task { await vm.refreshAllData() }
            }
        }
    }
}
