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
                VStack(spacing: 16) {
                    welcomeHeader
                    statsRow
                    filterPicker
                    clientBuildsList
                }
                .padding(.horizontal, 16)
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

    private var welcomeHeader: some View {
        HStack(spacing: 14) {
            Text(viewModel.currentUser.initials)
                .font(.neueCaptionMedium)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(AVIATheme.tealGradient)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome, \(viewModel.currentUser.firstName)")
                    .font(.neueCorpMedium(22))
                    .foregroundStyle(AVIATheme.textPrimary)
                Text("Pre-Site Coordinator")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
            }

            Spacer()

            Image("AVIALogo")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 20)
                .foregroundStyle(AVIATheme.teal)
        }
        .padding(.top, 4)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(value: "\(viewModel.clientBuildsForCurrentUser.count)", label: "Assigned Builds", icon: "building.2.fill", color: AVIATheme.teal)
            statCard(value: "\(viewModel.totalBuildsInProgress)", label: "In Progress", icon: "hammer.fill", color: AVIATheme.warning)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
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
    }
}
