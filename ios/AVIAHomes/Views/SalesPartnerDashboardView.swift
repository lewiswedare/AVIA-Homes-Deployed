import SwiftUI

struct PartnerDashboardView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var searchText = ""

    private var filteredBuilds: [ClientBuild] {
        var builds = viewModel.clientBuildsForCurrentUser
        if !searchText.isEmpty {
            builds = builds.filter {
                $0.client.fullName.localizedStandardContains(searchText) ||
                $0.homeDesign.localizedStandardContains(searchText) ||
                $0.estate.localizedStandardContains(searchText)
            }
        }
        return builds
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    welcomeHeader
                    portfolioStats
                    clientsList
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .background(AVIATheme.background)
            .navigationTitle("My Clients")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search clients")
            .navigationDestination(for: ClientBuild.self) { build in
                PartnerClientDetailView(build: build)
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

            Text("Partner")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AVIATheme.warmAccent)
        .clipShape(.rect(cornerRadius: 20))
    }

    private var portfolioStats: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.clientBuildsForCurrentUser.count)")
                    .font(.neueCorpMedium(32))
                    .foregroundStyle(AVIATheme.timelessBrown)
                Text("Active Clients")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(.rect(cornerRadius: 16))
            .shadow(color: AVIATheme.aviaBlack.opacity(0.06), radius: 8, y: 2)

            VStack(alignment: .leading, spacing: 4) {
                let avgProgress = viewModel.clientBuildsForCurrentUser.isEmpty ? 0.0 :
                    viewModel.clientBuildsForCurrentUser.reduce(0.0) { $0 + $1.overallProgress } / Double(viewModel.clientBuildsForCurrentUser.count)
                Text("\(Int(avgProgress * 100))%")
                    .font(.neueCorpMedium(32))
                    .foregroundStyle(AVIATheme.textPrimary)
                Text("Avg Progress")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AVIATheme.cardBackground)
            .clipShape(.rect(cornerRadius: 16))
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var clientsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Client Portfolio")
                .font(.neueCorpMedium(20))
                .foregroundStyle(AVIATheme.textPrimary)

            if filteredBuilds.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 36))
                        .foregroundStyle(AVIATheme.textTertiary)
                    Text("No clients found")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                ForEach(filteredBuilds) { build in
                    NavigationLink(value: build) {
                        salesClientCard(build: build)
                    }
                    .buttonStyle(.pressable(.subtle))
                }
            }
        }
    }

    private func salesClientCard(build: ClientBuild) -> some View {
        BentoCard(cornerRadius: 16) {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Text(build.client.initials.isEmpty ? "?" : build.client.initials)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .frame(width: 42, height: 42)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(build.clientDisplayName)
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text(build.homeDesign)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(Int(build.overallProgress * 100))%")
                            .font(.neueCorpMedium(18))
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text(build.statusLabel)
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                .padding(16)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AVIATheme.timelessBrown.opacity(0.1)).frame(height: 3)
                        Capsule().fill(AVIATheme.primaryGradient).frame(width: max(0, geo.size.width * build.overallProgress), height: 3)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
    }
}

struct PartnerClientDetailView: View {
    let build: ClientBuild
    @State private var expandedStage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                clientSummary
                progressTimeline
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .navigationTitle(build.clientDisplayName)
        .navigationBarTitleDisplayMode(.large)
    }

    private var clientSummary: some View {
        BentoCard(cornerRadius: 16) {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    Text(build.client.initials.isEmpty ? "?" : build.client.initials)
                        .font(.neueCorpMedium(20))
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .frame(width: 52, height: 52)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(build.clientDisplayName)
                            .font(.neueCorpMedium(20))
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text(build.homeDesign)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    Spacer()
                }

                Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                VStack(spacing: 8) {
                    summaryRow(label: "Design", value: build.homeDesign)
                    summaryRow(label: "Lot", value: build.lotNumber)
                    summaryRow(label: "Estate", value: build.estate)
                    summaryRow(label: "Contract Date", value: build.contractDate.formatted(date: .abbreviated, time: .omitted))
                    summaryRow(label: "Current Stage", value: build.statusLabel)
                    summaryRow(label: "Overall Progress", value: "\(Int(build.overallProgress * 100))%")
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AVIATheme.timelessBrown.opacity(0.1)).frame(height: 6)
                        Capsule().fill(AVIATheme.primaryGradient).frame(width: max(0, geo.size.width * build.overallProgress), height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding(16)
        }
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textTertiary)
            Spacer()
            Text(value)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.textPrimary)
        }
    }

    private var progressTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Build Progress")
                .font(.neueCorpMedium(20))
                .foregroundStyle(AVIATheme.textPrimary)

            VStack(spacing: 0) {
                ForEach(Array(build.buildStages.enumerated()), id: \.element.id) { index, stage in
                    TimelineStageRow(
                        stage: stage,
                        isFirst: index == 0,
                        isLast: index == build.buildStages.count - 1,
                        isExpanded: expandedStage == stage.id
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            expandedStage = expandedStage == stage.id ? nil : stage.id
                        }
                    }
                }
            }
        }
    }
}
