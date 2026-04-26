import SwiftUI

struct ContentView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        if appViewModel.authService.isRestoringSession {
            launchScreen
        } else if appViewModel.isAuthenticated {
            if appViewModel.hasCompletedProfile {
                switch appViewModel.currentRole {
                case .pending, .client:
                    if appViewModel.clientHasBuild {
                        ClientTabView()
                    } else {
                        ClientDiscoverTabView()
                    }
                case .staff, .preConstruction, .buildingSupport:
                    StaffTabView()
                case .superAdmin:
                    SuperAdminTabView()
                case .admin, .salesAdmin:
                    AdminTabView()
                case .partner, .salesPartner:
                    PartnerTabView()
                }
            } else {
                ProfileSetupView()
            }
        } else {
            LoginView()
        }
    }

    private var launchScreen: some View {
        VStack {
            Spacer()
            Image("AVIALogo")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 180)
                .foregroundStyle(AVIATheme.timelessBrown)
            Spacer()
            ProgressView()
                .tint(AVIATheme.timelessBrown)
                .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AVIATheme.background)
    }
}

struct NotificationBadgeModifier: ViewModifier {
    let count: Int

    func body(content: Content) -> some View {
        content
            .badge(count > 0 ? count : 0)
    }
}

struct ClientTabView: View {
    @State private var selectedTab = 0
    @Environment(AppViewModel.self) private var viewModel
    @Environment(SpecificationViewModel.self) private var specVM

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(AVIATheme.cardBackground)
        appearance.shadowColor = UIColor(AVIATheme.surfaceBorder)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                DashboardView(selectedTab: $selectedTab)
            }
            Tab("Specs", systemImage: "list.clipboard.fill", value: 1) {
                SpecificationsOverviewView()
            }
            .badge(specVM.upgradeRequests.filter { $0.status == .pending }.count)
            Tab("Colours", systemImage: "paintpalette.fill", value: 2) {
                ClientColourTabView()
            }
            Tab("Progress", systemImage: "chart.bar.fill", value: 3) {
                BuildProgressView()
            }
            Tab("More", systemImage: "ellipsis.circle.fill", value: 4) {
                MoreView()
            }
            .badge(viewModel.notificationService.unreadCount)
        }
        .tint(AVIATheme.timelessBrown)
        .task { await viewModel.loadUserData() }
    }
}

struct StaffTabView: View {
    @State private var selectedTab = 0
    @Environment(AppViewModel.self) private var viewModel

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(AVIATheme.cardBackground)
        appearance.shadowColor = UIColor(AVIATheme.surfaceBorder)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Builds", systemImage: "building.2.fill", value: 0) {
                StaffDashboardView()
            }
            Tab("Packages", systemImage: "square.grid.2x2.fill", value: 1) {
                NavigationStack {
                    ScrollView {
                        PackagesContentView()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    .background(AVIATheme.background)
                    .navigationTitle("Packages")
                    .navigationBarTitleDisplayMode(.large)
                    .navigationDestination(for: HouseLandPackage.self) { pkg in
                        PackageDetailView(package: pkg)
                    }
                    .navigationDestination(for: HomeDesign.self) { design in
                        HomeDesignDetailView(design: design)
                    }
                    .navigationDestination(for: LandEstate.self) { estate in
                        EstateDetailView(estate: estate)
                    }
                    .navigationDestination(for: SpecTier.self) { tier in
                        SpecRangeDetailView(tier: tier)
                    }
                    .navigationDestination(for: Facade.self) { facade in
                        FacadeDetailView(facade: facade)
                    }
                }
            }
            Tab("Messages", systemImage: "message.fill", value: 2) {
                NavigationStack {
                    ConversationsView()
                }
            }
            .badge(viewModel.messagingService.totalUnreadCount)
            Tab("Alerts", systemImage: "bell.fill", value: 3) {
                NavigationStack {
                    NotificationsView()
                }
            }
            .badge(viewModel.notificationService.unreadCount)
            Tab("More", systemImage: "ellipsis.circle.fill", value: 4) {
                MoreView()
            }
        }
        .tint(AVIATheme.timelessBrown)
        .task { await viewModel.loadUserData() }
    }
}

struct AdminTabView: View {
    @State private var selectedTab = 0
    @Environment(AppViewModel.self) private var viewModel

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(AVIATheme.cardBackground)
        appearance.shadowColor = UIColor(AVIATheme.surfaceBorder)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Dashboard", systemImage: "square.grid.2x2.fill", value: 0) {
                AdminDashboardView()
            }
            Tab("Packages", systemImage: "house.and.flag.fill", value: 1) {
                NavigationStack {
                    ScrollView {
                        PackagesContentView()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    .background(AVIATheme.background)
                    .navigationTitle("Packages")
                    .navigationBarTitleDisplayMode(.large)
                    .navigationDestination(for: HouseLandPackage.self) { pkg in
                        PackageDetailView(package: pkg)
                    }
                    .navigationDestination(for: HomeDesign.self) { design in
                        HomeDesignDetailView(design: design)
                    }
                    .navigationDestination(for: LandEstate.self) { estate in
                        EstateDetailView(estate: estate)
                    }
                    .navigationDestination(for: SpecTier.self) { tier in
                        SpecRangeDetailView(tier: tier)
                    }
                    .navigationDestination(for: Facade.self) { facade in
                        FacadeDetailView(facade: facade)
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            NavigationLink {
                                PackageManagementView()
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.neueSubheadline)
                            }
                        }
                    }
                }
            }
            Tab("Stocklist", systemImage: "list.clipboard", value: 2) {
                StocklistView()
            }
            Tab("Messages", systemImage: "message.fill", value: 3) {
                NavigationStack {
                    ConversationsView()
                }
            }
            .badge(viewModel.messagingService.totalUnreadCount)
            Tab("Alerts", systemImage: "bell.fill", value: 4) {
                NavigationStack {
                    NotificationsView()
                }
            }
            .badge(viewModel.notificationService.unreadCount)
            Tab("More", systemImage: "ellipsis.circle.fill", value: 5) {
                MoreView()
            }
        }
        .tint(AVIATheme.timelessBrown)
        .task { await viewModel.loadUserData() }
    }
}

struct PartnerTabView: View {
    @State private var selectedTab = 0
    @Environment(AppViewModel.self) private var viewModel

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(AVIATheme.cardBackground)
        appearance.shadowColor = UIColor(AVIATheme.surfaceBorder)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Clients", systemImage: "person.2.fill", value: 0) {
                PartnerDashboardView()
            }
            Tab("Packages", systemImage: "house.and.flag.fill", value: 1) {
                PartnerPackagesTab()
            }
            Tab("Stocklist", systemImage: "list.clipboard", value: 2) {
                StocklistView()
            }
            Tab("Messages", systemImage: "message.fill", value: 3) {
                NavigationStack {
                    ConversationsView()
                }
            }
            .badge(viewModel.messagingService.totalUnreadCount)
            Tab("Alerts", systemImage: "bell.fill", value: 4) {
                NavigationStack {
                    NotificationsView()
                }
            }
            .badge(viewModel.notificationService.unreadCount)
            Tab("More", systemImage: "ellipsis.circle.fill", value: 5) {
                MoreView()
            }
        }
        .tint(AVIATheme.timelessBrown)
        .task { await viewModel.loadUserData() }
    }
}

struct ClientDiscoverTabView: View {
    @State private var selectedTab = 0
    @Environment(AppViewModel.self) private var viewModel

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(AVIATheme.cardBackground)
        appearance.shadowColor = UIColor(AVIATheme.surfaceBorder)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Discover", systemImage: "house.fill", value: 0) {
                ClientDiscoverDashboardView()
            }
            Tab("Packages", systemImage: "square.grid.2x2.fill", value: 1) {
                NavigationStack {
                    ClientPackageReviewView()
                        .navigationDestination(for: HouseLandPackage.self) { pkg in
                            PackageDetailView(package: pkg)
                        }
                        .navigationDestination(for: HomeDesign.self) { design in
                            HomeDesignDetailView(design: design)
                        }
                        .navigationDestination(for: LandEstate.self) { estate in
                            EstateDetailView(estate: estate)
                        }
                        .navigationDestination(for: SpecTier.self) { tier in
                            SpecRangeDetailView(tier: tier)
                        }
                        .navigationDestination(for: Facade.self) { facade in
                            FacadeDetailView(facade: facade)
                        }
                }
            }
            Tab("Messages", systemImage: "message.fill", value: 2) {
                NavigationStack {
                    ConversationsView()
                }
            }
            .badge(viewModel.messagingService.totalUnreadCount)
            Tab("Alerts", systemImage: "bell.fill", value: 3) {
                NavigationStack {
                    NotificationsView()
                }
            }
            .badge(viewModel.notificationService.unreadCount)
            Tab("More", systemImage: "ellipsis.circle.fill", value: 4) {
                MoreView()
            }
        }
        .tint(AVIATheme.timelessBrown)
        .task { await viewModel.loadUserData() }
    }
}

struct SuperAdminTabView: View {
    @State private var selectedTab = 0
    @Environment(AppViewModel.self) private var viewModel

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(AVIATheme.cardBackground)
        appearance.shadowColor = UIColor(AVIATheme.surfaceBorder)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Overview", systemImage: "chart.bar.doc.horizontal.fill", value: 0) {
                SuperAdminDashboard()
            }
            Tab("Dashboard", systemImage: "square.grid.2x2.fill", value: 1) {
                AdminDashboardView()
            }
            Tab("Packages", systemImage: "house.and.flag.fill", value: 2) {
                NavigationStack {
                    ScrollView {
                        PackagesContentView()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    .background(AVIATheme.background)
                    .navigationTitle("Packages")
                    .navigationBarTitleDisplayMode(.large)
                    .navigationDestination(for: HouseLandPackage.self) { pkg in
                        PackageDetailView(package: pkg)
                    }
                    .navigationDestination(for: HomeDesign.self) { design in
                        HomeDesignDetailView(design: design)
                    }
                    .navigationDestination(for: LandEstate.self) { estate in
                        EstateDetailView(estate: estate)
                    }
                    .navigationDestination(for: SpecTier.self) { tier in
                        SpecRangeDetailView(tier: tier)
                    }
                    .navigationDestination(for: Facade.self) { facade in
                        FacadeDetailView(facade: facade)
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            NavigationLink {
                                PackageManagementView()
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.neueSubheadline)
                            }
                        }
                    }
                }
            }
            Tab("Stocklist", systemImage: "list.clipboard", value: 3) {
                StocklistView()
            }
            Tab("Messages", systemImage: "message.fill", value: 4) {
                NavigationStack {
                    ConversationsView()
                }
            }
            .badge(viewModel.messagingService.totalUnreadCount)
            Tab("More", systemImage: "ellipsis.circle.fill", value: 5) {
                MoreView()
            }
        }
        .tint(AVIATheme.timelessBrown)
        .task { await viewModel.loadUserData() }
    }
}

struct StaffScheduleView: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if viewModel.upcomingScheduleItems.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .font(.system(size: 36))
                                .foregroundStyle(AVIATheme.textTertiary)
                            Text("No upcoming schedule items")
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(AVIATheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                    } else {
                        ForEach(viewModel.upcomingScheduleItems) { item in
                            BentoCard(cornerRadius: 13) {
                                HStack(spacing: 14) {
                                    Image(systemName: item.icon)
                                        .font(.neueCorpMedium(14))
                                        .foregroundStyle(AVIATheme.timelessBrown)
                                        .frame(width: 36, height: 36)
                                        .background(AVIATheme.timelessBrown.opacity(0.12))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.title)
                                            .font(.neueSubheadlineMedium)
                                            .foregroundStyle(AVIATheme.textPrimary)
                                        Text(item.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.neueCaption)
                                            .foregroundStyle(AVIATheme.textSecondary)
                                    }

                                    Spacer()

                                    StatusBadge(title: item.type.rawValue, color: AVIATheme.timelessBrown)
                                }
                                .padding(14)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(AVIATheme.background)
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ClientColourTabView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(SpecificationViewModel.self) private var specVM

    var body: some View {
        if specVM.buildId.isEmpty {
            ColourOverviewView()
        } else {
            BuildColourSelectionView(buildId: specVM.buildId)
        }
    }
}

struct MoreView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 12) {
                        BentoCard(cornerRadius: 13) {
                            VStack(spacing: 0) {
                                NavigationLink {
                                    ConversationsView()
                                } label: {
                                    HStack(spacing: 14) {
                                        BentoIconCircle(icon: "message.fill", color: AVIATheme.timelessBrown)
                                        Text("Messages")
                                            .font(.neueSubheadlineMedium)
                                            .foregroundStyle(AVIATheme.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.neueCaption2Medium)
                                            .foregroundStyle(AVIATheme.textTertiary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }

                                Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 66)

                                NavigationLink {
                                    ClientPackageReviewView()
                                } label: {
                                    HStack(spacing: 14) {
                                        BentoIconCircle(icon: "house.and.flag.fill", color: AVIATheme.timelessBrown)
                                        Text("My Package")
                                            .font(.neueSubheadlineMedium)
                                            .foregroundStyle(AVIATheme.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.neueCaption2Medium)
                                            .foregroundStyle(AVIATheme.textTertiary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }

                                Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 66)

                                NavigationLink {
                                    DocumentsView()
                                } label: {
                                    HStack(spacing: 14) {
                                        BentoIconCircle(icon: "doc.text.fill", color: AVIATheme.timelessBrown)
                                        Text("Documents")
                                            .font(.neueSubheadlineMedium)
                                            .foregroundStyle(AVIATheme.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.neueCaption2Medium)
                                            .foregroundStyle(AVIATheme.textTertiary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }

                                Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 66)

                                NavigationLink {
                                    RequestsView()
                                } label: {
                                    HStack(spacing: 14) {
                                        BentoIconCircle(icon: "bubble.left.and.bubble.right.fill", color: AVIATheme.timelessBrown)
                                        Text("Requests & Support")
                                            .font(.neueSubheadlineMedium)
                                            .foregroundStyle(AVIATheme.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.neueCaption2Medium)
                                            .foregroundStyle(AVIATheme.textTertiary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }

                                Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 66)

                                NavigationLink {
                                    ProfileView()
                                } label: {
                                    HStack(spacing: 14) {
                                        BentoIconCircle(icon: "person.fill", color: AVIATheme.timelessBrown)
                                        Text("Profile & Settings")
                                            .font(.neueSubheadlineMedium)
                                            .foregroundStyle(AVIATheme.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.neueCaption2Medium)
                                            .foregroundStyle(AVIATheme.textTertiary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }
                            }
                        }

                        BentoCard(cornerRadius: 13) {
                            VStack(spacing: 0) {
                                if let phoneURL = URL(string: "tel:0756545123") {
                                    Link(destination: phoneURL) {
                                        HStack(spacing: 14) {
                                            BentoIconCircle(icon: "phone.fill", color: AVIATheme.success)
                                            Text("Call Us")
                                                .font(.neueSubheadlineMedium)
                                                .foregroundStyle(AVIATheme.textPrimary)
                                            Spacer()
                                            Image(systemName: "arrow.up.right")
                                                .font(.neueCaption2)
                                                .foregroundStyle(AVIATheme.textTertiary)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                    }
                                }

                                Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 66)

                                if let webURL = URL(string: "https://www.aviahomes.com.au") {
                                    Link(destination: webURL) {
                                        HStack(spacing: 14) {
                                            BentoIconCircle(icon: "safari.fill", color: AVIATheme.timelessBrown)
                                            Text("Website")
                                                .font(.neueSubheadlineMedium)
                                                .foregroundStyle(AVIATheme.textPrimary)
                                            Spacer()
                                            Image(systemName: "arrow.up.right")
                                                .font(.neueCaption2)
                                                .foregroundStyle(AVIATheme.textTertiary)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }

                Spacer(minLength: 0)

                Image("AVIALogo")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(AVIATheme.timelessBrown.opacity(0.4))
                    .padding(.horizontal, 0)
                    .padding(.bottom, 8)
            }
            .background(AVIATheme.background)
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: HouseLandPackage.self) { pkg in
                PackageDetailView(package: pkg)
            }
            .navigationDestination(for: HomeDesign.self) { design in
                HomeDesignDetailView(design: design)
            }
            .navigationDestination(for: LandEstate.self) { estate in
                EstateDetailView(estate: estate)
            }
            .navigationDestination(for: SpecTier.self) { tier in
                SpecRangeDetailView(tier: tier)
            }
            .navigationDestination(for: Facade.self) { facade in
                FacadeDetailView(facade: facade)
            }
        }
    }
}
