import SwiftUI

struct SalesAdminDashboardView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var searchText = ""
    @State private var selectedFilter: SalesAdminFilter = .all

    enum SalesAdminFilter: String, CaseIterable {
        case all = "All Builds"
        case active = "Active"
        case earlyStage = "Early Stage"
        case lateStage = "Late Stage"
    }

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
        switch selectedFilter {
        case .all: break
        case .active:
            builds = builds.filter { $0.currentStage != nil }
        case .earlyStage:
            builds = builds.filter { $0.overallProgress < 0.4 }
        case .lateStage:
            builds = builds.filter { $0.overallProgress >= 0.4 }
        }
        return builds
    }

    private var averageProgress: Double {
        let builds = viewModel.allClientBuilds
        guard !builds.isEmpty else { return 0 }
        return builds.reduce(0.0) { $0 + $1.overallProgress } / Double(builds.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    welcomeHeader
                    overviewStats
                    filterPicker
                    buildsList
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .background(AVIATheme.background)
            .navigationTitle("All Builds")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search all builds")
            .navigationDestination(for: ClientBuild.self) { build in
                ClientBuildDetailView(build: build)
            }
        }
    }

    private var welcomeHeader: some View {
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

            Text("Staff")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AVIATheme.warmAccent)
        .clipShape(.rect(cornerRadius: 20))
    }

    private var overviewStats: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ImmersiveStatCard(value: "\(viewModel.allClientBuilds.count)", label: "Total Builds", useFrosted: true)
                ImmersiveStatCard(value: "\(viewModel.allClientBuilds.filter { $0.currentStage != nil }.count)", label: "In Progress")
            }

            BentoCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Portfolio Progress")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Spacer()
                        Text("\(Int(averageProgress * 100))% avg")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.timelessBrown)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AVIATheme.timelessBrown.opacity(0.1)).frame(height: 8)
                            Capsule().fill(AVIATheme.primaryGradient).frame(width: max(0, geo.size.width * averageProgress), height: 8)
                        }
                    }
                    .frame(height: 8)

                    HStack(spacing: 16) {
                        progressLabel(count: viewModel.allClientBuilds.filter { $0.overallProgress < 0.3 }.count, label: "Early", color: AVIATheme.warning)
                        progressLabel(count: viewModel.allClientBuilds.filter { $0.overallProgress >= 0.3 && $0.overallProgress < 0.7 }.count, label: "Mid", color: AVIATheme.timelessBrown)
                        progressLabel(count: viewModel.allClientBuilds.filter { $0.overallProgress >= 0.7 }.count, label: "Late", color: AVIATheme.success)
                    }
                }
                .padding(16)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func progressLabel(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(count) \(label)")
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
    }


    private var filterPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(SalesAdminFilter.allCases, id: \.self) { filter in
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
            }
        }
        .contentMargins(.horizontal, 0)
        .scrollIndicators(.hidden)
    }

    private var buildsList: some View {
        VStack(spacing: 12) {
            if filteredBuilds.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(AVIATheme.textTertiary)
                    Text("No builds match your search")
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
