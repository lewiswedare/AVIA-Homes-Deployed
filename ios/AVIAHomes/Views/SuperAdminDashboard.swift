import SwiftUI

struct SuperAdminDashboard: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var selectedStaff: ClientUser?
    @State private var showAllBuilds = false

    private var preConstructionStaff: [ClientUser] {
        viewModel.allRegisteredUsers.filter { $0.role == .preConstruction }
    }

    private var buildingSupportStaff: [ClientUser] {
        viewModel.allRegisteredUsers.filter { $0.role == .buildingSupport }
    }

    private var generalStaff: [ClientUser] {
        viewModel.allRegisteredUsers.filter { $0.role == .staff }
    }

    private var salesStaff: [ClientUser] {
        viewModel.allRegisteredUsers.filter { $0.role == .salesPartner || $0.role == .salesAdmin }
    }

    private var activeBuilds: [ClientBuild] {
        viewModel.allClientBuilds.filter { $0.buildStatus == "active" }
    }

    private var buildsAwaitingHandover: [ClientBuild] {
        viewModel.allClientBuilds.filter { $0.handoverTriggeredAt == nil && !$0.buildStages.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    allBuildsSummary
                    staffOverviewSection("Pre-Construction", staff: preConstructionStaff, countType: .builds)
                    staffOverviewSection("Building Support", staff: buildingSupportStaff, countType: .builds)
                    staffOverviewSection("Staff", staff: generalStaff, countType: .packages)
                    staffOverviewSection("Sales", staff: salesStaff, countType: .packages)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(AVIATheme.background)
            .navigationTitle("Super Admin")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.refreshAllData()
            }
            .navigationDestination(for: ClientUser.self) { user in
                SuperAdminStaffDetailView(staffUser: user)
            }
            .navigationDestination(isPresented: $showAllBuilds) {
                SuperAdminBuildListView(builds: viewModel.allClientBuilds)
            }
        }
    }

    private var allBuildsSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ALL BUILDS")
                .font(.neueCaption2Medium)
                .foregroundStyle(AVIATheme.timelessBrown)
                .kerning(0.5)

            HStack(spacing: 12) {
                ImmersiveStatCard(value: "\(activeBuilds.count)", label: "Active Builds", useFrosted: true)
                ImmersiveStatCard(value: "\(viewModel.allClientBuilds.count)", label: "Total Builds")
            }

            if !buildsAwaitingHandover.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.warning)
                    Text("\(buildsAwaitingHandover.count) build\(buildsAwaitingHandover.count == 1 ? "" : "s") awaiting handover")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.warning)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private enum StaffCountType {
        case builds, packages
    }

    private func staffOverviewSection(_ title: String, staff: [ClientUser], countType: StaffCountType) -> some View {
        Group {
            if !staff.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title.uppercased())
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                        .kerning(0.5)

                    ForEach(staff, id: \.id) { user in
                        NavigationLink(value: user) {
                            staffCard(user: user, countType: countType)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func staffCard(user: ClientUser, countType: StaffCountType) -> some View {
        BentoCard(cornerRadius: 14) {
            HStack(spacing: 12) {
                avatarView(user: user)

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.fullName)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    if let title = user.displayTitle, !title.isEmpty {
                        Text(title)
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                }

                Spacer()

                let count = countForStaff(user: user, type: countType)
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(count)")
                        .font(.neueCorpMedium(20))
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text(countType == .builds ? "builds" : "packages")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }

                Image(systemName: "chevron.right")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(14)
        }
    }

    @ViewBuilder
    private func avatarView(user: ClientUser) -> some View {
        if let urlString = user.avatarUrl, !urlString.isEmpty, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                initialsCircle(user: user)
            }
            .frame(width: 42, height: 42)
            .clipShape(Circle())
        } else {
            initialsCircle(user: user)
        }
    }

    private func initialsCircle(user: ClientUser) -> some View {
        Text(user.initials)
            .font(.neueCorpMedium(14))
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(AVIATheme.tealGradient)
            .clipShape(Circle())
    }

    private func countForStaff(user: ClientUser, type: StaffCountType) -> Int {
        switch type {
        case .builds:
            switch user.role {
            case .preConstruction:
                return viewModel.allClientBuilds.filter { $0.preConstructionStaffId == user.id }.count
            case .buildingSupport:
                return viewModel.allClientBuilds.filter { $0.buildingSupportStaffId == user.id }.count
            case .staff:
                return viewModel.allClientBuilds.filter { $0.assignedStaffId == user.id }.count
            default:
                return 0
            }
        case .packages:
            return viewModel.packageAssignments.filter {
                $0.assignedPartnerIds.contains(user.id) || $0.sharedWithClientIds.contains(user.id)
            }.count
        }
    }
}

struct SuperAdminStaffDetailView: View {
    @Environment(AppViewModel.self) private var viewModel
    let staffUser: ClientUser

    private var assignedBuilds: [ClientBuild] {
        switch staffUser.role {
        case .preConstruction:
            return viewModel.allClientBuilds.filter { $0.preConstructionStaffId == staffUser.id }
        case .buildingSupport:
            return viewModel.allClientBuilds.filter { $0.buildingSupportStaffId == staffUser.id }
        case .staff:
            return viewModel.allClientBuilds.filter { $0.assignedStaffId == staffUser.id }
        default:
            return []
        }
    }

    private var assignedPackages: [PackageAssignment] {
        viewModel.packageAssignments.filter {
            $0.assignedPartnerIds.contains(staffUser.id)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StaffContactCard(staffUser: staffUser)

                if !assignedBuilds.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ASSIGNED BUILDS")
                            .font(.neueCaption2Medium)
                            .foregroundStyle(AVIATheme.textTertiary)
                            .kerning(0.5)
                        ForEach(assignedBuilds, id: \.id) { build in
                            BentoCard(cornerRadius: 12) {
                                HStack(spacing: 12) {
                                    BentoIconCircle(icon: "building.2.fill", color: AVIATheme.teal)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(build.clientDisplayName)
                                            .font(.neueSubheadlineMedium)
                                            .foregroundStyle(AVIATheme.textPrimary)
                                        Text("\(build.homeDesign) — Lot \(build.lotNumber)")
                                            .font(.neueCaption)
                                            .foregroundStyle(AVIATheme.textSecondary)
                                    }
                                    Spacer()
                                    StatusBadge(title: build.statusLabel, color: AVIATheme.teal)
                                }
                                .padding(12)
                            }
                        }
                    }
                }

                if !assignedPackages.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PACKAGES IN PIPELINE")
                            .font(.neueCaption2Medium)
                            .foregroundStyle(AVIATheme.textTertiary)
                            .kerning(0.5)
                        ForEach(assignedPackages, id: \.id) { assignment in
                            BentoCard(cornerRadius: 12) {
                                HStack {
                                    BentoIconCircle(icon: "house.and.flag.fill", color: AVIATheme.teal)
                                    Text("Package \(assignment.packageId.prefix(8))")
                                        .font(.neueCaption)
                                        .foregroundStyle(AVIATheme.textPrimary)
                                    Spacer()
                                    StatusBadge(title: assignment.depositStatus.capitalized, color: AVIATheme.textSecondary)
                                }
                                .padding(12)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(AVIATheme.background)
        .navigationTitle(staffUser.fullName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SuperAdminBuildListView: View {
    let builds: [ClientBuild]

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(builds, id: \.id) { build in
                    BentoCard(cornerRadius: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(build.clientDisplayName)
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Spacer()
                                StatusBadge(title: build.buildStatus.capitalized, color: build.buildStatus == "active" ? AVIATheme.success : AVIATheme.textTertiary)
                            }
                            Text("\(build.homeDesign) — Lot \(build.lotNumber), \(build.estate)")
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)
                            HStack(spacing: 12) {
                                if build.handoverTriggeredAt != nil {
                                    StatusBadge(title: "Handed Over", color: AVIATheme.teal)
                                }
                                Text("Stage: \(build.statusLabel)")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                            }
                        }
                        .padding(14)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(AVIATheme.background)
        .navigationTitle("All Builds")
        .navigationBarTitleDisplayMode(.large)
    }
}

extension ClientUser: Hashable {
    nonisolated static func == (lhs: ClientUser, rhs: ClientUser) -> Bool {
        lhs.id == rhs.id
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
