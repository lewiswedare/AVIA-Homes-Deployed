import SwiftUI

struct AdminBuildsSection: View {
    @Environment(AppViewModel.self) private var viewModel
    let searchText: String
    @Binding var selectedBuildForEdit: ClientBuild?

    private var filteredBuilds: [ClientBuild] {
        var builds = viewModel.allClientBuilds
        if !searchText.isEmpty {
            builds = builds.filter {
                $0.client.fullName.localizedStandardContains(searchText) ||
                $0.homeDesign.localizedStandardContains(searchText) ||
                $0.lotNumber.localizedStandardContains(searchText) ||
                $0.estate.localizedStandardContains(searchText)
            }
        }
        return builds
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                AdminMetricCard(value: "\(viewModel.allClientBuilds.count)", label: "Total", icon: "building.2.fill", color: AVIATheme.teal)
                AdminMetricCard(value: "\(viewModel.allClientBuilds.filter { $0.currentStage != nil }.count)", label: "Active", icon: "hammer.fill", color: AVIATheme.warning)
            }
            .fixedSize(horizontal: false, vertical: true)

            let pendingBuildIds = Set(viewModel.pendingSpecReviews.map(\.buildId))
            let upgradeBuildIds = Set(viewModel.pendingSpecReviews.filter { $0.selectionType == .upgradeRequested }.map(\.buildId))

            if filteredBuilds.isEmpty {
                AdminEmptyState(icon: "building.2", title: "No builds found", subtitle: "Try adjusting your search")
            } else {
                ForEach(filteredBuilds) { build in
                    let badge: BuildSpecReviewBadge = upgradeBuildIds.contains(build.id) ? .upgradeRequested : (pendingBuildIds.contains(build.id) ? .awaitingReview : .none)
                    Button { selectedBuildForEdit = build } label: {
                        AdminBuildRow(build: build, specReviewStatus: badge)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
