import SwiftUI

struct StaffDashboardView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var searchText = ""
    @State private var selectedFilter: BuildFilter = .all

    enum BuildFilter: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case preConstruction = "Pre-Con"
        case completed = "Completed"
    }

    private var filteredBuilds: [ClientBuild] {
        var builds = viewModel.clientBuildsForCurrentUser
        if !searchText.isEmpty {
            builds = builds.filter {
                $0.client.fullName.localizedStandardContains(searchText) ||
                $0.homeDesign.localizedStandardContains(searchText) ||
                $0.lotNumber.localizedStandardContains(searchText) ||
                $0.estate.localizedStandardContains(searchText)
            }
        }
        switch selectedFilter {
        case .all: break
        case .active:
            builds = builds.filter { $0.currentStage != nil && $0.currentStage?.name != "Pre-Construction" }
        case .preConstruction:
            builds = builds.filter { $0.currentStage?.name == "Pre-Construction" || $0.buildStages.allSatisfy { $0.status == .upcoming } }
        case .completed:
            builds = builds.filter { $0.buildStages.allSatisfy { $0.status == .completed } }
        }
        return builds
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroHeader
                    statsRow
                    filterPicker
                    clientBuildsList
                }
                .padding(.bottom, 40)
            }
            .background(AVIATheme.background)
            .navigationTitle("My Builds")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search clients or builds")
            .navigationDestination(for: ClientBuild.self) { build in
                ClientBuildDetailView(build: build)
            }
        }
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Text(viewModel.currentUser.initials)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(width: 44, height: 44)
                    .background(AVIATheme.brownGradient)
                    .clipShape(Circle())

                Spacer()

                Image("AVIALogo")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 20)
                    .foregroundStyle(AVIATheme.timelessBrown)
            }

            Text(viewModel.currentUser.firstName.isEmpty ? "Welcome Home" : "Welcome Home, \(viewModel.currentUser.firstName)")
                .font(.neueCorpMedium(30))
                .foregroundStyle(AVIATheme.timelessBrown)

            Text("Pre-Site Coordinator")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AVIATheme.warmAccent)
        .clipShape(.rect(cornerRadius: 20))
        .padding(.horizontal, 16)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            ImmersiveStatCard(value: "\(viewModel.clientBuildsForCurrentUser.count)", label: "Assigned Builds", useFrosted: true)
            ImmersiveStatCard(value: "\(viewModel.totalBuildsInProgress)", label: "In Progress")
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 16)
    }

    private var filterPicker: some View {
        HStack(spacing: 8) {
            ForEach(BuildFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedFilter = filter
                    }
                } label: {
                    Text(filter.rawValue)
                        .font(.neueCaptionMedium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .foregroundStyle(selectedFilter == filter ? AVIATheme.textPrimary : AVIATheme.textSecondary)
                        .background(selectedFilter == filter ? AVIATheme.cardBackgroundAlt : AVIATheme.cardBackground)
                        .clipShape(Capsule())
                        .overlay {
                            if selectedFilter == filter {
                                Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                            }
                        }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private var clientBuildsList: some View {
        VStack(spacing: 12) {
            if filteredBuilds.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
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
                    NavigationLink(value: build) {
                        ClientBuildCardView(build: build)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}
