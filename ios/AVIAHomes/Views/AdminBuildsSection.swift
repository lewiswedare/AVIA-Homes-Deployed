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
                AdminMetricCard(value: "\(viewModel.allClientBuilds.count)", label: "Total", icon: "building.2.fill", color: AVIATheme.timelessBrown)
                AdminMetricCard(value: "\(viewModel.allClientBuilds.filter { $0.currentStage != nil }.count)", label: "Active", icon: "hammer.fill", color: AVIATheme.warning)
            }
            .fixedSize(horizontal: false, vertical: true)

            if filteredBuilds.isEmpty {
                AdminEmptyState(icon: "building.2", title: "No builds found", subtitle: "Try adjusting your search")
            } else {
                ForEach(filteredBuilds) { build in
                    let badge = BuildReviewBadgeResolver.resolve(for: build.id, viewModel: viewModel)
                    Button { selectedBuildForEdit = build } label: {
                        AdminBuildRow(build: build, specReviewStatus: badge)
                    }
                    .buttonStyle(.pressable(.subtle))
                }
            }
        }
    }
}
