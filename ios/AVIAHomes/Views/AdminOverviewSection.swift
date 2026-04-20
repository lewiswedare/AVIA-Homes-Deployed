import SwiftUI

struct AdminOverviewSection: View {
    @Environment(AppViewModel.self) private var viewModel
    let searchText: String
    @Binding var showingAddBuild: Bool
    @Binding var selectedBuildForEdit: ClientBuild?
    @Binding var selectedSection: AdminSection

    var body: some View {
        VStack(spacing: 16) {
            alertsBanner
            metricsGrid
            quickActions
            recentPackageResponses
            recentBuildsPreview
            pendingItemsSummary
        }
    }

    @ViewBuilder
    private var alertsBanner: some View {
        let pendingUsers = viewModel.allRegisteredUsers.filter { $0.role == .pending }.count
        let openRequests = viewModel.requests.filter { $0.status == .open }.count

        // Break spec review pipeline into concrete action buckets so admins
        // see what's actually waiting on them.
        let newSpecSubmissionBuildIds = Set(viewModel.pendingSpecReviews
            .filter { $0.selectionType != .upgradeRequested && $0.selectionType != .upgradeAccepted }
            .map(\.buildId))
        let specSubmissionBuildCount = newSpecSubmissionBuildIds.count
        let specUpgradesToPrice = viewModel.pendingSpecReviews.filter { $0.selectionType == .upgradeRequested }.count
        let specUpgradesToApprove = viewModel.pendingSpecReviews.filter { $0.selectionType == .upgradeAccepted }.count
        let colourUpgradesToApprove = viewModel.pendingColourUpgrades.count

        let recentAccepted = viewModel.packageAssignments.flatMap(\.clientResponses).filter { $0.status == .accepted }.count
        let recentDeclined = viewModel.packageAssignments.flatMap(\.clientResponses).filter { $0.status == .declined }.count
        let pendingPkgResponses = viewModel.packageAssignments.flatMap(\.clientResponses).filter { $0.status == .pending }.count
        let pendingEOIs = viewModel.packageAssignments.filter { $0.eoiStatus == "submitted" || $0.eoiStatus == "resubmitted" }.count
        let totalAlerts = pendingUsers + openRequests + specSubmissionBuildCount + specUpgradesToPrice + specUpgradesToApprove + colourUpgradesToApprove + pendingPkgResponses + pendingEOIs

        if totalAlerts > 0 {
            BentoCard(cornerRadius: 16) {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(AVIATheme.warning)
                        Text("Action Required")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Spacer()
                        Text("\(totalAlerts)")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .frame(width: 24, height: 24)
                            .background(AVIATheme.warning)
                            .clipShape(Circle())
                    }
                    VStack(spacing: 6) {
                        if pendingUsers > 0 {
                            alertNavRow(icon: "person.badge.clock.fill", text: "\(pendingUsers) user\(pendingUsers == 1 ? "" : "s") awaiting role assignment", color: AVIATheme.warning) {
                                UserManagementView()
                            }
                        }
                        if openRequests > 0 {
                            alertNavRow(icon: "bubble.left.fill", text: "\(openRequests) open client request\(openRequests == 1 ? "" : "s")", color: AVIATheme.timelessBrown) {
                                RequestsView()
                            }
                        }
                        if pendingEOIs > 0 {
                            alertNavRow(icon: "doc.text.magnifyingglass", text: "\(pendingEOIs) EOI submission\(pendingEOIs == 1 ? "" : "s") awaiting review", color: AVIATheme.warning) {
                                AdminEOIReviewView()
                            }
                        }
                        if pendingPkgResponses > 0 {
                            alertNavRow(icon: "square.grid.2x2.fill", text: "\(pendingPkgResponses) package response\(pendingPkgResponses == 1 ? "" : "s") pending", color: AVIATheme.success) {
                                PackageManagementView()
                            }
                        }
                        if recentAccepted > 0 || recentDeclined > 0 {
                            let parts = [recentAccepted > 0 ? "\(recentAccepted) accepted" : nil, recentDeclined > 0 ? "\(recentDeclined) declined" : nil].compactMap { $0 }.joined(separator: ", ")
                            alertNavRow(icon: "envelope.open.fill", text: "Package responses: \(parts)", color: recentDeclined > 0 ? AVIATheme.destructive : AVIATheme.success) {
                                PackageManagementView()
                            }
                        }
                        if specSubmissionBuildCount > 0 {
                            alertNavRow(icon: "checklist.checked", text: "\(specSubmissionBuildCount) build\(specSubmissionBuildCount == 1 ? "" : "s") awaiting spec review", color: AVIATheme.warning) {
                                AdminBuildManagementView()
                            }
                        }
                        if specUpgradesToPrice > 0 {
                            alertNavRow(icon: "dollarsign.circle.fill", text: "\(specUpgradesToPrice) upgrade request\(specUpgradesToPrice == 1 ? "" : "s") to price", color: AVIATheme.accent) {
                                AdminBuildManagementView()
                            }
                        }
                        if specUpgradesToApprove > 0 {
                            alertNavRow(icon: "hand.thumbsup.fill", text: "\(specUpgradesToApprove) spec upgrade\(specUpgradesToApprove == 1 ? "" : "s") to approve", color: AVIATheme.heritageBlue) {
                                AdminBuildManagementView()
                            }
                        }
                        if colourUpgradesToApprove > 0 {
                            alertNavRow(icon: "paintpalette.fill", text: "\(colourUpgradesToApprove) colour upgrade\(colourUpgradesToApprove == 1 ? "" : "s") to approve", color: AVIATheme.heritageBlue) {
                                AdminBuildManagementView()
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    private func alertNavRow<Destination: View>(icon: String, text: String, color: Color, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.neueCorp(12))
                    .foregroundStyle(color)
                    .frame(width: 28, height: 28)
                    .background(color.opacity(0.12))
                    .clipShape(Circle())
                Text(text)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.neueCorp(9))
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(10)
            .background(AVIATheme.cardBackgroundAlt)
            .clipShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.pressable(.subtle))
    }

    private var metricsGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                AdminMetricCard(value: "\(viewModel.allClientBuilds.count)", label: "Total Builds", icon: "building.2.fill", color: AVIATheme.timelessBrown)
                AdminMetricCard(value: "\(viewModel.allClientBuilds.filter { $0.currentStage != nil }.count)", label: "Active", icon: "hammer.fill", color: AVIATheme.warning)
            }
            HStack(spacing: 12) {
                AdminMetricCard(value: "\(viewModel.allRegisteredUsers.filter { $0.role == .client }.count + 1)", label: "Clients", icon: "person.2.fill", color: AVIATheme.timelessBrown)
                AdminMetricCard(value: "\(viewModel.allRegisteredUsers.filter { $0.role.isAnyStaffRole }.count + 1)", label: "Staff", icon: "person.badge.shield.checkmark.fill", color: AVIATheme.success)
            }
            portfolioProgress
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var portfolioProgress: some View {
        let builds = viewModel.allClientBuilds
        let avg = builds.isEmpty ? 0.0 : builds.reduce(0.0) { $0 + $1.overallProgress } / Double(builds.count)
        return BentoCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Portfolio Progress")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Spacer()
                    Text("\(Int(avg * 100))% avg")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AVIATheme.timelessBrown.opacity(0.1)).frame(height: 8)
                        Capsule().fill(AVIATheme.primaryGradient).frame(width: max(0, geo.size.width * avg), height: 8)
                    }
                }
                .frame(height: 8)
                HStack(spacing: 16) {
                    AdminProgressLabel(count: builds.filter { $0.overallProgress < 0.3 }.count, label: "Early", color: AVIATheme.warning)
                    AdminProgressLabel(count: builds.filter { $0.overallProgress >= 0.3 && $0.overallProgress < 0.7 }.count, label: "Mid", color: AVIATheme.timelessBrown)
                    AdminProgressLabel(count: builds.filter { $0.overallProgress >= 0.7 }.count, label: "Late", color: AVIATheme.success)
                }
            }
            .padding(16)
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUICK ACTIONS")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                Button { showingAddBuild = true } label: {
                    AdminQuickActionContent(icon: "plus.circle.fill", label: "New Build", color: AVIATheme.timelessBrown)
                }
                NavigationLink { UserManagementView() } label: {
                    AdminQuickActionContent(icon: "person.badge.key.fill", label: "User Roles", color: AVIATheme.warning)
                }
                NavigationLink { PackageManagementView() } label: {
                    AdminQuickActionContent(icon: "house.and.flag.fill", label: "Packages", color: AVIATheme.timelessBrown)
                }
                NavigationLink { AdminEOIReviewView() } label: {
                    AdminQuickActionContent(icon: "doc.text.magnifyingglass", label: "EOI Reviews", color: AVIATheme.warning)
                }
                NavigationLink { AdminBuildManagementView() } label: {
                    AdminQuickActionContent(icon: "slider.horizontal.3", label: "Build Mgmt", color: AVIATheme.success)
                }
            }
        }
    }

    private var recentBuildsPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("RECENT BUILDS")
                    .font(.neueCaption2Medium)
                    .kerning(1.0)
                    .foregroundStyle(AVIATheme.textTertiary)
                Spacer()
                Button { withAnimation { selectedSection = .builds } } label: {
                    Text("View All")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }
            ForEach(Array(viewModel.allClientBuilds.prefix(3))) { build in
                let badge = BuildReviewBadgeResolver.resolve(for: build.id, viewModel: viewModel)
                Button { selectedBuildForEdit = build } label: {
                    AdminBuildRow(build: build, specReviewStatus: badge)
                }
                .buttonStyle(.pressable(.subtle))
            }
        }
    }

    private var recentPackageResponses: some View {
        let allResponses = viewModel.packageAssignments.flatMap { assignment in
            assignment.clientResponses.compactMap { response -> (ClientPackageResponse, String)? in
                guard response.status != .pending else { return nil }
                return (response, assignment.packageId)
            }
        }
        .sorted { ($0.0.respondedDate ?? .distantPast) > ($1.0.respondedDate ?? .distantPast) }
        let recent = Array(allResponses.prefix(5))

        return Group {
            if !recent.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("RECENT PACKAGE RESPONSES")
                            .font(.neueCaption2Medium)
                            .kerning(1.0)
                            .foregroundStyle(AVIATheme.textTertiary)
                        Spacer()
                        NavigationLink { PackageManagementView() } label: {
                            Text("View All")
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.timelessBrown)
                        }
                    }
                    ForEach(Array(recent.enumerated()), id: \.offset) { _, item in
                        let (response, pkgId) = item
                        let client = viewModel.allRegisteredUsers.first { $0.id == response.clientId }
                        let pkg = viewModel.allPackages.first { $0.id == pkgId }
                        BentoCard(cornerRadius: 14) {
                            HStack(spacing: 12) {
                                Image(systemName: response.status.icon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(response.status == .accepted ? AVIATheme.success : AVIATheme.destructive)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(client?.fullName.trimmingCharacters(in: .whitespaces).isEmpty == false ? client!.fullName : (client?.email ?? "Unknown Client"))
                                        .font(.neueSubheadlineMedium)
                                        .foregroundStyle(AVIATheme.textPrimary)
                                    HStack(spacing: 6) {
                                        Text(response.status.rawValue)
                                            .font(.neueCorpMedium(9))
                                            .foregroundStyle(response.status == .accepted ? AVIATheme.success : AVIATheme.destructive)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background((response.status == .accepted ? AVIATheme.success : AVIATheme.destructive).opacity(0.1))
                                            .clipShape(Capsule())
                                        Text(pkg?.title ?? "Package")
                                            .font(.neueCaption2)
                                            .foregroundStyle(AVIATheme.textTertiary)
                                            .lineLimit(1)
                                    }
                                    if let date = response.respondedDate {
                                        Text(date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.neueCaption2)
                                            .foregroundStyle(AVIATheme.textTertiary)
                                    }
                                    if let notes = response.notes, !notes.isEmpty {
                                        Text(notes)
                                            .font(.neueCaption)
                                            .foregroundStyle(AVIATheme.textSecondary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                            }
                            .padding(12)
                        }
                    }
                }
            }
        }
    }

    private var pendingItemsSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PENDING ITEMS")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)
            BentoCard(cornerRadius: 16) {
                VStack(spacing: 0) {
                    AdminPendingRow(icon: "person.badge.clock.fill", label: "Pending Users", count: viewModel.allRegisteredUsers.filter { $0.role == .pending }.count, color: AVIATheme.warning)
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 52)
                    AdminPendingRow(icon: "bubble.left.fill", label: "Open Requests", count: viewModel.requests.filter { $0.status == .open }.count, color: AVIATheme.timelessBrown)
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 52)
                    AdminPendingRow(icon: "clock.fill", label: "In-Progress Requests", count: viewModel.requests.filter { $0.status == .inProgress }.count, color: AVIATheme.timelessBrown)
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 52)
                    AdminPendingRow(icon: "square.grid.2x2.fill", label: "Pending Pkg Responses", count: viewModel.packageAssignments.flatMap(\.clientResponses).filter { $0.status == .pending }.count, color: AVIATheme.success)
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 52)
                    AdminPendingRow(icon: "doc.text.magnifyingglass", label: "EOIs Awaiting Review", count: viewModel.packageAssignments.filter { $0.eoiStatus == "submitted" || $0.eoiStatus == "resubmitted" }.count, color: AVIATheme.warning)
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 52)
                    AdminPendingRow(icon: "checklist.checked", label: "Spec Reviews Pending", count: Set(viewModel.pendingSpecReviews.filter { $0.selectionType != .upgradeRequested && $0.selectionType != .upgradeAccepted }.map(\.buildId)).count, color: AVIATheme.warning)
                    let toPrice = viewModel.pendingSpecReviews.filter { $0.selectionType == .upgradeRequested }.count
                    if toPrice > 0 {
                        Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 52)
                        AdminPendingRow(icon: "dollarsign.circle.fill", label: "Upgrades to Price", count: toPrice, color: AVIATheme.accent)
                    }
                    let toApprove = viewModel.pendingSpecReviews.filter { $0.selectionType == .upgradeAccepted }.count
                    if toApprove > 0 {
                        Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 52)
                        AdminPendingRow(icon: "hand.thumbsup.fill", label: "Spec Upgrades to Approve", count: toApprove, color: AVIATheme.heritageBlue)
                    }
                    if viewModel.pendingColourUpgrades.count > 0 {
                        Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 52)
                        AdminPendingRow(icon: "paintpalette.fill", label: "Colour Upgrades to Approve", count: viewModel.pendingColourUpgrades.count, color: AVIATheme.heritageBlue)
                    }
                }
            }
        }
    }
}
