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
        .refreshable {
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
        BentoCard(cornerRadius: 16) {
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
                            .foregroundStyle(selectedFilter == filter ? .white : AVIATheme.textSecondary)
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
                let pendingBuildIds = Set(viewModel.pendingSpecReviews.map(\.buildId))
                let upgradeBuildIds = Set(viewModel.pendingSpecReviews.filter { $0.selectionType == .upgradeRequested || $0.selectionType == .upgradeAccepted }.map(\.buildId))
                ForEach(filteredBuilds) { build in
                    let badge: BuildSpecReviewBadge = upgradeBuildIds.contains(build.id) ? .upgradeRequested : (pendingBuildIds.contains(build.id) ? .awaitingReview : .none)
                    Button {
                        selectedBuildForEdit = build
                    } label: {
                        AdminBuildRow(build: build, specReviewStatus: badge)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct AdminBuildRow: View {
    let build: ClientBuild
    var specReviewStatus: BuildSpecReviewBadge = .none

    var body: some View {
        BentoCard(cornerRadius: 16) {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ZStack(alignment: .topTrailing) {
                        Text(build.client.initials.isEmpty ? "?" : build.client.initials)
                            .font(.neueCaptionMedium)
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(AVIATheme.primaryGradient)
                            .clipShape(Circle())

                        if specReviewStatus != .none {
                            Circle()
                                .fill(specReviewStatus == .upgradeRequested ? AVIATheme.warning : AVIATheme.warning)
                                .frame(width: 12, height: 12)
                                .overlay { Circle().stroke(AVIATheme.cardBackground, lineWidth: 2) }
                                .offset(x: 2, y: -2)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(build.clientDisplayName)
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(AVIATheme.textPrimary)

                            if specReviewStatus != .none {
                                Text(specReviewStatus == .upgradeRequested ? "UPGRADE REQ" : "SPEC REVIEW")
                                    .font(.neueCorpMedium(7))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(specReviewStatus == .upgradeRequested ? AVIATheme.warning : AVIATheme.warning)
                                    .clipShape(Capsule())
                            }
                        }
                        Text("\(build.homeDesign) · \(build.lotNumber)")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
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

enum BuildSpecReviewBadge {
    case none
    case awaitingReview
    case upgradeRequested
}
