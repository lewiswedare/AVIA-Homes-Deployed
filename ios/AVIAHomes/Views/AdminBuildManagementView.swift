import SwiftUI

struct AdminBuildManagementView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var searchText = ""
    @State private var selectedFilter: AdminBuildFilter = .all
    @State private var showingAddBuild = false
    @State private var selectedBuildForEdit: ClientBuild?

    enum AdminBuildFilter: String, CaseIterable {
        case all = "All"
        case unassigned = "Unassigned"
        case active = "Active"
        case earlyStage = "Early"
        case lateStage = "Late"
    }

    private var filteredBuilds: [ClientBuild] {
        var builds = viewModel.allClientBuilds
        if !searchText.isEmpty {
            builds = builds.filter {
                $0.clientDisplayName.localizedStandardContains(searchText) ||
                $0.homeDesign.localizedStandardContains(searchText) ||
                $0.lotNumber.localizedStandardContains(searchText) ||
                $0.estate.localizedStandardContains(searchText)
            }
        }
        switch selectedFilter {
        case .all: break
        case .unassigned:
            builds = builds.filter { $0.client.id.isEmpty || $0.assignedStaffId.isEmpty }
        case .active:
            builds = builds.filter { $0.currentStage != nil }
        case .earlyStage:
            builds = builds.filter { $0.overallProgress < 0.3 }
        case .lateStage:
            builds = builds.filter { $0.overallProgress >= 0.6 }
        }
        return builds
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryCards
                filterBar
                buildsList
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .navigationTitle("Build Management")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search builds")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddBuild = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }
        }
        .hapticRefresh {
            await viewModel.refreshBuildsAndAssignments()
        }
        .sheet(isPresented: $showingAddBuild) {
            AddBuildSheet()
        }
        .sheet(item: $selectedBuildForEdit) { build in
            AdminBuildEditSheet(build: build)
        }
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            adminStatCard(
                value: "\(viewModel.allClientBuilds.count)",
                label: "Total Builds",
                icon: "building.2.fill",
                color: AVIATheme.timelessBrown
            )
            adminStatCard(
                value: "\(viewModel.allClientBuilds.filter { $0.currentStage != nil }.count)",
                label: "Active",
                icon: "hammer.fill",
                color: AVIATheme.warning
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func adminStatCard(value: String, label: String, icon: String, color: Color) -> some View {
        BentoCard(cornerRadius: 13) {
            VStack(alignment: .leading, spacing: 8) {
                BentoIconCircle(icon: icon, color: color)
                Text(value)
                    .font(.neueCorpMedium(32))
                    .foregroundStyle(AVIATheme.textPrimary)
                Text(label)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(AdminBuildFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.neueCaptionMedium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(selectedFilter == filter ? AVIATheme.aviaWhite : AVIATheme.textSecondary)
                            .background(selectedFilter == filter ? AVIATheme.timelessBrown : AVIATheme.cardBackground)
                            .clipShape(Capsule())
                            .overlay {
                                if selectedFilter != filter {
                                    Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                                }
                            }
                    }
                }
            }
        }
        .contentMargins(.horizontal, 0)
        .scrollIndicators(.hidden)
    }

    private var buildsList: some View {
        VStack(spacing: 10) {
            if filteredBuilds.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "building.2")
                        .font(.system(size: 36))
                        .foregroundStyle(AVIATheme.textTertiary)
                    Text("No builds found")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                ForEach(filteredBuilds) { build in
                    let badge = BuildReviewBadgeResolver.resolve(for: build.id, viewModel: viewModel)
                    Button {
                        selectedBuildForEdit = build
                    } label: {
                        AdminBuildRow(build: build, specReviewStatus: badge)
                    }
                    .buttonStyle(.pressable(.subtle))
                }
            }
        }
    }
}

struct AdminBuildRow: View {
    let build: ClientBuild
    var specReviewStatus: BuildSpecReviewBadge = .none

    var body: some View {
        BentoCard(cornerRadius: 13) {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ZStack(alignment: .topTrailing) {
                        Text(build.client.initials.isEmpty ? "?" : build.client.initials)
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .frame(width: 42, height: 42)
                            .background(AVIATheme.primaryGradient)
                            .clipShape(Circle())

                        if specReviewStatus.totalCount > 0 {
                            Text("\(specReviewStatus.totalCount)")
                                .font(.neueCorpMedium(9))
                                .foregroundStyle(AVIATheme.aviaWhite)
                                .frame(minWidth: 16, minHeight: 16)
                                .padding(.horizontal, 3)
                                .background(specReviewStatus.pillColor)
                                .clipShape(Capsule())
                                .overlay { Capsule().stroke(AVIATheme.cardBackground, lineWidth: 2) }
                                .offset(x: 4, y: -4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(build.clientDisplayName)
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(AVIATheme.textPrimary)

                            if specReviewStatus.totalCount > 0 {
                                Text(specReviewStatus.pillLabel)
                                    .font(.neueCorpMedium(7))
                                    .foregroundStyle(AVIATheme.aviaWhite)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(specReviewStatus.pillColor)
                                    .clipShape(Capsule())
                            }
                        }
                        Text("\(build.homeDesign) · \(build.lotNumber)")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)

                        if let summary = specReviewStatus.summaryLine {
                            Text(summary)
                                .font(.neueCaption2)
                                .foregroundStyle(specReviewStatus.pillColor)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(Int(build.overallProgress * 100))%")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.timelessBrown)
                        Text(build.statusLabel)
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }

                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
                .padding(16)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AVIATheme.timelessBrown.opacity(0.1)).frame(height: 4)
                        Capsule().fill(AVIATheme.primaryGradient).frame(width: max(0, geo.size.width * build.overallProgress), height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
    }
}

/// Rich badge describing what the admin needs to review on a particular build.
/// Aggregates spec submissions, upgrade requests, upgrade responses, and colour
/// upgrade approvals into a single count + label so the build list makes it
/// obvious where attention is needed.
struct BuildSpecReviewBadge: Equatable {
    var newSpecSubmissions: Int = 0     // client has submitted spec items to review
    var newUpgradeRequests: Int = 0     // client asked for an upgrade — admin needs to quote
    var acceptedUpgrades: Int = 0       // client accepted a quoted upgrade — admin final approval
    var colourUpgrades: Int = 0         // colour upgrade accepted by client — admin final approval

    static let none = BuildSpecReviewBadge()

    var totalCount: Int {
        newSpecSubmissions + newUpgradeRequests + acceptedUpgrades + colourUpgrades
    }

    /// Highest-priority action wins the pill label (upgrades + approvals are
    /// always more time-sensitive than a fresh submission).
    var pillLabel: String {
        if newUpgradeRequests > 0 { return "\(newUpgradeRequests) TO PRICE" }
        if acceptedUpgrades + colourUpgrades > 0 {
            return "\(acceptedUpgrades + colourUpgrades) TO APPROVE"
        }
        if newSpecSubmissions > 0 { return "SPEC REVIEW" }
        return ""
    }

    var pillColor: Color {
        if newUpgradeRequests > 0 { return AVIATheme.accent }
        if acceptedUpgrades + colourUpgrades > 0 { return AVIATheme.heritageBlue }
        return AVIATheme.warning
    }

    /// One-line detail of what kinds of items are pending (used under the name).
    var summaryLine: String? {
        var parts: [String] = []
        if newUpgradeRequests > 0 {
            parts.append("\(newUpgradeRequests) new upgrade req\(newUpgradeRequests == 1 ? "" : "s")")
        }
        if acceptedUpgrades > 0 {
            parts.append("\(acceptedUpgrades) spec upgrade\(acceptedUpgrades == 1 ? "" : "s") to approve")
        }
        if colourUpgrades > 0 {
            parts.append("\(colourUpgrades) colour upgrade\(colourUpgrades == 1 ? "" : "s") to approve")
        }
        if newSpecSubmissions > 0 && parts.isEmpty {
            parts.append("\(newSpecSubmissions) spec item\(newSpecSubmissions == 1 ? "" : "s") submitted")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{2022} ")
    }
}

/// Builds a `BuildSpecReviewBadge` from the app-level pending caches for a
/// specific build. Centralised so every surface (build list, overview alerts,
/// spec review banner) uses the same numbers.
enum BuildReviewBadgeResolver {
    static func resolve(for buildId: String, viewModel: AppViewModel) -> BuildSpecReviewBadge {
        let reviews = viewModel.pendingSpecReviews.filter { $0.buildId == buildId }
        let newSubmissions = reviews.filter { $0.selectionType != .upgradeRequested
            && $0.selectionType != .upgradeAccepted
            && $0.selectionType != .upgradeCosted }.count
        let newUpgradeRequests = reviews.filter { $0.selectionType == .upgradeRequested }.count
        let acceptedUpgrades = reviews.filter { $0.selectionType == .upgradeAccepted }.count
        let colourUpgrades = viewModel.pendingColourUpgrades.filter { $0.buildId == buildId }.count
        return BuildSpecReviewBadge(
            newSpecSubmissions: newSubmissions,
            newUpgradeRequests: newUpgradeRequests,
            acceptedUpgrades: acceptedUpgrades,
            colourUpgrades: colourUpgrades
        )
    }
}
