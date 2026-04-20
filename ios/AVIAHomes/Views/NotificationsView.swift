import SwiftUI

struct NotificationsView: View {
    @Environment(AppViewModel.self) private var viewModel

    private var groupedNotifications: [(String, [AppNotification])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: viewModel.notificationService.notifications) { notification -> String in
            if calendar.isDateInToday(notification.createdAt) {
                return "Today"
            } else if calendar.isDateInYesterday(notification.createdAt) {
                return "Yesterday"
            } else {
                return "Earlier"
            }
        }
        let order = ["Today", "Yesterday", "Earlier"]
        return order.compactMap { key in
            guard let items = grouped[key], !items.isEmpty else { return nil }
            return (key, items)
        }
    }

    var body: some View {
        ScrollView {
            if viewModel.notificationService.notifications.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(groupedNotifications, id: \.0) { section, items in
                        sectionHeader(section)
                        ForEach(items) { notification in
                            notificationRow(notification)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .background(AVIATheme.background)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.notificationService.unreadCount > 0 {
                    Button("Read All") {
                        Task {
                            await viewModel.notificationService.markAllAsRead(for: viewModel.currentUser.id)
                            viewModel.pushManager.updateBadgeCount(0)
                        }
                    }
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.timelessBrown)
                }
            }
        }
        .hapticRefresh {
            await viewModel.notificationService.loadNotifications(for: viewModel.currentUser.id)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func notificationRow(_ notification: AppNotification) -> some View {
        if hasDestination(notification) {
            NavigationLink {
                notificationDestination(notification)
            } label: {
                notificationRowContent(notification)
            }
            .buttonStyle(.pressable(.subtle))
            .simultaneousGesture(TapGesture().onEnded {
                markAsRead(notification)
            })
        } else {
            Button {
                markAsRead(notification)
            } label: {
                notificationRowContent(notification)
            }
            .buttonStyle(.pressable(.subtle))
        }
    }

    private func markAsRead(_ notification: AppNotification) {
        Task {
            await viewModel.notificationService.markAsRead(notification.id)
            viewModel.pushManager.updateBadgeCount(viewModel.notificationService.unreadCount)
        }
    }

    private func hasDestination(_ notification: AppNotification) -> Bool {
        switch notification.type {
        case .newMessage:
            guard let refId = notification.referenceId else { return false }
            return viewModel.messagingService.conversations.contains { $0.id == refId }
        case .specTierChanged, .upgradeQuoted:
            return true
        case .colourSelectionSubmitted:
            return resolveBuildId(for: notification) != nil
        case .requestSubmitted, .requestResponse:
            return true
        case .packageShared, .packageApproved, .packageDeclined, .packageAccepted:
            return true
        case .depositInvoice, .depositReceived:
            return true
        case .buildUpdate, .handoverTriggered:
            return true
        case .documentAdded:
            return true
        case .eoiSubmitted, .eoiApproved, .eoiChangesRequested:
            return true
        case .contractUploaded, .contractSigned, .contractRaised:
            return true
        case .invoiceRaised, .invoicePaid:
            return true
        case .roleAssigned:
            return false
        }
    }

    private var isAdminOrStaff: Bool {
        viewModel.currentRole.isAnyStaffRole
    }

    @ViewBuilder
    private func notificationDestination(_ notification: AppNotification) -> some View {
        switch notification.type {
        case .newMessage:
            if let refId = notification.referenceId,
               let conversation = viewModel.messagingService.conversations.first(where: { $0.id == refId }) {
                ChatView(conversation: conversation)
            }
        case .specTierChanged, .upgradeQuoted:
            if isAdminOrStaff {
                AdminBuildManagementView()
            } else {
                SpecificationsOverviewView()
            }
        case .colourSelectionSubmitted:
            if let buildId = resolveBuildId(for: notification) {
                BuildColourSelectionView(buildId: buildId)
            }
        case .requestSubmitted, .requestResponse:
            RequestsView()
        case .packageShared, .packageApproved, .packageDeclined, .packageAccepted:
            if isAdminOrStaff {
                PackageManagementView()
            } else {
                ClientPackageReviewView()
            }
        case .depositInvoice, .depositReceived:
            if isAdminOrStaff {
                PackageManagementView()
            } else {
                ClientPackageReviewView()
            }
        case .buildUpdate, .handoverTriggered:
            if isAdminOrStaff {
                AdminBuildManagementView()
            } else {
                BuildProgressView()
            }
        case .documentAdded:
            DocumentsView()
        case .eoiSubmitted, .eoiApproved, .eoiChangesRequested:
            if isAdminOrStaff {
                AdminEOIReviewView()
            } else {
                ClientPackageReviewView()
            }
        case .contractUploaded, .contractSigned, .contractRaised:
            if isAdminOrStaff {
                AdminEOIReviewView()
            } else {
                ClientPackageReviewView()
            }
        case .invoiceRaised, .invoicePaid:
            if isAdminOrStaff {
                AdminEOIReviewView()
            } else {
                ClientPackageReviewView()
            }
        case .roleAssigned:
            EmptyView()
        }
    }

    private func resolveBuildId(for notification: AppNotification) -> String? {
        if let refId = notification.referenceId, !refId.isEmpty {
            return refId
        }
        return viewModel.clientBuildsForCurrentUser.first?.id
    }

    private func notificationRowContent(_ notification: AppNotification) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(notificationColor(notification.type).opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: notification.type.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(notificationColor(notification.type))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(notification.title)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Spacer()
                    Text(timeAgo(notification.createdAt))
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }

                Text(notification.message)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            if !notification.isRead {
                Circle()
                    .fill(AVIATheme.timelessBrown)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(notification.isRead ? Color.clear : AVIATheme.timelessBrown.opacity(0.03))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 44))
                .foregroundStyle(AVIATheme.textTertiary)
            Text("No Notifications")
                .font(.neueCorpMedium(20))
                .foregroundStyle(AVIATheme.textPrimary)
            Text("You'll see updates about your build,\npackages, and messages here.")
                .font(.neueSubheadline)
                .foregroundStyle(AVIATheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func notificationColor(_ type: NotificationType) -> Color {
        switch type.color {
        case "success": AVIATheme.success
        case "destructive": AVIATheme.destructive
        case "warning": AVIATheme.warning
        default: AVIATheme.timelessBrown
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date.now.timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
