import SwiftUI

struct AdminDashboardView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var searchText = ""
    @State private var selectedSection: AdminSection = .overview
    @State private var showingAddBuild = false
    @State private var selectedBuildForEdit: ClientBuild?
    @State private var selectedUserForEdit: ClientUser?
    @State private var selectedRequest: ServiceRequest?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    adminWelcomeHeader
                    adminSectionPicker
                    adminSectionContent
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .background(AVIATheme.background)
            .navigationTitle("Admin")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: adminSearchPrompt)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { showingAddBuild = true } label: {
                            Label("New Build", systemImage: "plus.circle")
                        }
                        NavigationLink { AdminCatalogHubView() } label: {
                            Label("Catalog Management", systemImage: "list.clipboard.fill")
                        }
                        NavigationLink { UserManagementView() } label: {
                            Label("Manage Users", systemImage: "person.badge.key.fill")
                        }
                        NavigationLink { PackageManagementView() } label: {
                            Label("Manage Packages", systemImage: "house.and.flag.fill")
                        }
                        NavigationLink { AdminBuildManagementView() } label: {
                            Label("Build Management", systemImage: "slider.horizontal.3")
                        }
                        NavigationLink { AdminEOIReviewView() } label: {
                            Label("EOI Reviews", systemImage: "doc.text.magnifyingglass")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundStyle(AVIATheme.teal)
                    }
                }
            }
            .sheet(isPresented: $showingAddBuild) { AddBuildSheet() }
            .sheet(item: $selectedBuildForEdit) { build in AdminBuildEditSheet(build: build) }
            .sheet(item: $selectedUserForEdit) { user in UserRoleAssignmentSheet(user: user) }
            .sheet(item: $selectedRequest) { req in AdminRequestDetailSheet(request: req) }
            .navigationDestination(for: ClientBuild.self) { build in ClientBuildDetailView(build: build) }
        }
    }

    private var adminSearchPrompt: String {
        switch selectedSection {
        case .overview: "Search builds, clients, staff..."
        case .builds: "Search builds"
        case .clients: "Search clients"
        case .staff: "Search staff"
        case .requests: "Search requests"
        case .activity: "Search activity"
        }
    }

    private var adminWelcomeHeader: some View {
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
                HStack(spacing: 4) {
                    Image(systemName: "person.badge.shield.checkmark.fill")
                        .font(.neueCorp(11))
                        .foregroundStyle(AVIATheme.teal)
                    Text("Admin")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
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

    private var adminSectionPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(AdminSection.allCases, id: \.self) { section in
                    Button {
                        withAnimation(.spring(response: 0.3)) { selectedSection = section }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: section.icon)
                                .font(.neueCorp(10))
                            Text(section.rawValue)
                                .font(.neueCaptionMedium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(selectedSection == section ? .white : AVIATheme.textSecondary)
                        .background(selectedSection == section ? AVIATheme.teal : AVIATheme.cardBackground)
                        .clipShape(Capsule())
                        .overlay {
                            if selectedSection != section {
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

    @ViewBuilder
    private var adminSectionContent: some View {
        switch selectedSection {
        case .overview:
            AdminOverviewSection(
                searchText: searchText,
                showingAddBuild: $showingAddBuild,
                selectedBuildForEdit: $selectedBuildForEdit,
                selectedSection: $selectedSection
            )
        case .builds:
            AdminBuildsSection(searchText: searchText, selectedBuildForEdit: $selectedBuildForEdit)
        case .clients:
            AdminClientsSection(searchText: searchText)
        case .staff:
            AdminStaffSection(searchText: searchText, selectedUserForEdit: $selectedUserForEdit)
        case .requests:
            AdminRequestsSection(searchText: searchText, selectedRequest: $selectedRequest)
        case .activity:
            AdminActivitySection()
        }
    }
}

enum AdminSection: String, CaseIterable {
    case overview = "Overview"
    case builds = "Builds"
    case clients = "Clients"
    case staff = "Staff"
    case requests = "Requests"
    case activity = "Activity"

    var icon: String {
        switch self {
        case .overview: "square.grid.2x2.fill"
        case .builds: "building.2.fill"
        case .clients: "person.2.fill"
        case .staff: "person.badge.shield.checkmark.fill"
        case .requests: "bubble.left.and.bubble.right.fill"
        case .activity: "clock.arrow.circlepath"
        }
    }
}

struct ActivityItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
    let date: Date
    let color: Color
}
