import SwiftUI

struct ClientDiscoverDashboardView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var showDesignDirectory: Bool = false
    @State private var showAllNews: Bool = false
    @State private var showSpecComparison: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroImage

                    VStack(spacing: 32) {
                        headerRow
                        sharedPackagesBanner
                        latestNewsSection
                        ourDesignsSection
                        specRangesSlider
                        facadesSlider
                        socialFollowBlock
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)

                    brandFooter
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(AVIATheme.background)
            .navigationDestination(for: HomeDesign.self) { design in
                HomeDesignDetailView(design: design)
            }
            .navigationDestination(for: HouseLandPackage.self) { pkg in
                PackageDetailView(package: pkg)
            }
            .navigationDestination(for: LandEstate.self) { estate in
                EstateDetailView(estate: estate)
            }
            .fullScreenCover(isPresented: $showDesignDirectory) {
                HomeDesignDirectoryView()
            }
            .navigationDestination(isPresented: $showAllNews) {
                AllNewsView()
            }
            .navigationDestination(for: BlogPost.self) { post in
                NewsArticleDetailView(post: post)
            }
            .navigationDestination(for: SpecTier.self) { tier in
                SpecRangeDetailView(tier: tier)
            }
            .navigationDestination(for: AllFacadesRoute.self) { _ in
                AllFacadesView()
            }
            .navigationDestination(for: Facade.self) { facade in
                FacadeDetailView(facade: facade)
            }
            .navigationDestination(isPresented: $showSpecComparison) {
                SpecRangeComparisonOverviewView()
            }
        }
    }

    private var heroImage: some View {
        Color(AVIATheme.surfaceElevated)
            .frame(height: 360)
            .overlay {
                Image("hero_facade")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0.0),
                        .init(color: AVIATheme.timelessBrown.opacity(0.10), location: 0.20),
                        .init(color: AVIATheme.background.opacity(0.4), location: 0.45),
                        .init(color: AVIATheme.background.opacity(0.7), location: 0.65),
                        .init(color: AVIATheme.background.opacity(0.9), location: 0.8),
                        .init(color: AVIATheme.background, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 220)
            }
            .clipped()
    }

    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image("AVIALogo")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 24)
                    .foregroundStyle(AVIATheme.timelessBrown)
                Spacer()
                UserAvatarView(user: viewModel.currentUser, size: 36)
            }

            Text(viewModel.currentUser.firstName.isEmpty ? "Welcome Home" : "Welcome Home, \(viewModel.currentUser.firstName)")
                .font(.neueCorpMedium(34))
                .foregroundStyle(AVIATheme.timelessBrown)
        }
    }

    private var welcomeBanner: some View {
        BentoCard(cornerRadius: 16) {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Explore AVIA Homes")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text("Browse our designs, packages, and find your perfect home.")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    if let phoneURL = URL(string: "tel:0756545123") {
                        Link(destination: phoneURL) {
                            HStack(spacing: 6) {
                                Image(systemName: "phone.fill")
                                    .font(.neueCorp(12))
                                Text("Contact Us")
                                    .font(.neueCaptionMedium)
                            }
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(AVIATheme.brownGradient)
                            .clipShape(.rect(cornerRadius: 10))
                        }
                    }

                    if let webURL = URL(string: "https://www.aviahomes.com.au") {
                        Link(destination: webURL) {
                            HStack(spacing: 6) {
                                Image(systemName: "safari.fill")
                                    .font(.neueCorp(12))
                                Text("Website")
                                    .font(.neueCaptionMedium)
                            }
                            .foregroundStyle(AVIATheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(AVIATheme.surfaceElevated)
                            .clipShape(.rect(cornerRadius: 10))
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var latestNewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Latest News")
                    .font(.neueCorpMedium(24))
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
                Button {
                    showAllNews = true
                } label: {
                    Text("See All")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }

            if let featuredPost = viewModel.allBlogPosts.first {
                NavigationLink(value: featuredPost) {
                    featuredBlogCard(post: featuredPost)
                }
                .buttonStyle(.plain)
            }

            ForEach(viewModel.allBlogPosts.dropFirst().prefix(2)) { post in
                NavigationLink(value: post) {
                    compactBlogRow(post: post)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func featuredBlogCard(post: BlogPost) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color(AVIATheme.surfaceElevated)
                .frame(height: 180)
                .overlay {
                    AsyncImage(url: URL(string: post.imageURL)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadii: .init(topLeading: 16, topTrailing: 16)))
                .overlay(alignment: .topLeading) {
                    Text(post.category.uppercased())
                        .font(.neueCaption2Medium)
                        .kerning(0.8)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AVIATheme.aviaBlack.opacity(0.7))
                        .clipShape(Capsule())
                        .padding(12)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(post.title)
                    .font(.neueHeadline)
                    .foregroundStyle(AVIATheme.textPrimary)
                    .lineLimit(2)

                Text(post.subtitle)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Label(post.readTime, systemImage: "clock")
                    Label(post.date.formatted(.dateTime.month(.abbreviated).day()), systemImage: "calendar")
                }
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }

    private func compactBlogRow(post: BlogPost) -> some View {
        BentoCard(cornerRadius: 16) {
            HStack(spacing: 12) {
                Color(AVIATheme.surfaceElevated)
                    .frame(width: 72, height: 72)
                    .overlay {
                        AsyncImage(url: URL(string: post.imageURL)) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(post.category.uppercased())
                        .font(.neueCorpMedium(9))
                        .kerning(0.6)
                        .foregroundStyle(AVIATheme.timelessBrown)

                    Text(post.title)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(post.readTime)
                        Text("·")
                        Text(post.date.formatted(.dateTime.month(.abbreviated).day()))
                    }
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(12)
        }
    }

    private var ourDesignsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Our Designs")
                    .font(.neueCorpMedium(24))
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
                Button {
                    showDesignDirectory = true
                } label: {
                    Text("See All")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(viewModel.allHomeDesigns.prefix(6)) { design in
                        NavigationLink(value: design) {
                            designCard(design: design)
                        }
                    }

                    Button {
                        showDesignDirectory = true
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.neueCorpMedium(28))
                                .foregroundStyle(AVIATheme.timelessBrown)
                            Text("View All\n\(viewModel.allHomeDesigns.count) Designs")
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(width: 260, height: 325)
                        .background(AVIATheme.cardBackground)
                        .clipShape(.rect(cornerRadius: 16))
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
    }

    private func designCard(design: HomeDesign) -> some View {
        Color(AVIATheme.surfaceElevated)
            .frame(width: 260, height: 325)
            .overlay {
                AsyncImage(url: URL(string: design.imageURL)) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else if phase.error != nil {
                        Image(systemName: "house.fill")
                            .font(.neueCorpMedium(24))
                            .foregroundStyle(AVIATheme.timelessBrown.opacity(0.25))
                    } else {
                        ProgressView()
                    }
                }
                .allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) {
                if design.storeys == 2 {
                    Text("2 STOREY")
                        .font(.neueCorpMedium(7))
                        .kerning(0.4)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AVIATheme.timelessBrown)
                        .clipShape(Capsule())
                        .padding(8)
                }
            }
            .overlay(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(design.name)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)

                    Text("\(design.bedrooms) Bed · \(design.bathrooms) Bath · \(design.garages) Car · \(String(format: "%.0fm²", design.squareMeters))")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial)
                .clipShape(.rect(cornerRadii: .init(bottomLeading: 16, bottomTrailing: 16)))
            }
            .clipShape(.rect(cornerRadius: 16))
    }

    private var houseLandSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "House & Land", icon: "map.fill")

            ForEach(viewModel.allPackages.prefix(5)) { pkg in
                NavigationLink(value: pkg) {
                    houseLandCard(package: pkg)
                }
            }
        }
    }

    private func houseLandCard(package: HouseLandPackage) -> some View {
        BentoCard(cornerRadius: 16) {
            HStack(spacing: 12) {
                Color(AVIATheme.surfaceElevated)
                    .frame(width: 90, height: 90)
                    .overlay {
                        AsyncImage(url: URL(string: package.imageURL)) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay(alignment: .topLeading) {
                        if package.isNew {
                            Text("NEW")
                                .font(.neueCorpMedium(8))
                                .foregroundStyle(AVIATheme.aviaWhite)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(AVIATheme.timelessBrown)
                                .clipShape(Capsule())
                                .padding(4)
                        }
                    }

                VStack(alignment: .leading, spacing: 5) {
                    Text(package.title)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.neueCorp(10))
                            .foregroundStyle(AVIATheme.timelessBrown)
                        Text(package.location)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 12) {
                        Label(package.lotSize, systemImage: "ruler")
                        Label(package.homeDesign, systemImage: "house")
                    }
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                    .lineLimit(1)

                    Text(package.price)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
        }
    }

    private var specRangesSlider: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Our Spec Ranges")
                    .font(.neueCorpMedium(24))
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
                Button {
                    showSpecComparison = true
                } label: {
                    Text("Compare")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }

            VStack(spacing: 14) {
                ForEach(Array(SpecTier.allCases.enumerated()), id: \.element) { index, tier in
                    NavigationLink(value: tier) {
                        specRangeCard(tier: tier, index: index)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func specRangeCard(tier: SpecTier, index: Int) -> some View {
        Color(AVIATheme.surfaceElevated)
            .frame(height: 320)
            .overlay {
                AsyncImage(url: URL(string: specRangeImageURL(for: tier))) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else if phase.error != nil {
                        Text(tier.displayName)
                            .font(.neueCorpMedium(16))
                            .foregroundStyle(AVIATheme.timelessBrown.opacity(0.25))
                    } else {
                        ProgressView()
                    }
                }
                .allowsHitTesting(false)
            }
            .overlay {
                LinearGradient(
                    colors: [
                        AVIATheme.aviaBlack.opacity(0.15),
                        AVIATheme.aviaBlack.opacity(0.35),
                        AVIATheme.aviaBlack.opacity(0.85)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .topLeading) {
                Text(specRangeBadge(for: tier))
                    .font(.neueCorpMedium(10))
                    .kerning(1.2)
                    .foregroundStyle(AVIATheme.aviaWhite.opacity(0.9))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .environment(\.colorScheme, .dark)
                    .padding(16)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tier.displayName)
                        .font(.neueCorpMedium(28))
                        .foregroundStyle(AVIATheme.aviaWhite)
                    Text(tier.tagline)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.aviaWhite.opacity(0.9))

                    HStack(spacing: 6) {
                        Text("Explore \(tier.displayName)")
                            .font(.neueCaptionMedium)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .environment(\.colorScheme, .dark)
                    .padding(.top, 4)
                }
                .padding(18)
            }
            .clipShape(.rect(cornerRadius: 20))
            .shadow(color: AVIATheme.aviaBlack.opacity(0.12), radius: 14, x: 0, y: 6)
    }

    private func specRangeImageURL(for tier: SpecTier) -> String {
        let editedURL = CatalogDataManager.shared.specRangeData(for: tier).heroImageURL
        if !editedURL.isEmpty {
            return editedURL
        }
        switch tier {
        case .volos: return "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/2m8uxjn7nelckolf349xo.jpg"
        case .messina: return "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/sxfdai5efw1uz7s7qqgmo.jpeg"
        case .portobello: return "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/j4n8xaj2jlxo0wjxvkhr8.jpeg"
        }
    }

    private func specRangeDescription(for tier: SpecTier) -> String {
        switch tier {
        case .volos: "Quality foundations for smart living"
        case .messina: "Step up to elevated comfort & style"
        case .portobello: "The ultimate in premium finishes"
        }
    }

    private func specRangeBadge(for tier: SpecTier) -> String {
        switch tier {
        case .volos: "INCLUDED"
        case .messina: "UPGRADE"
        case .portobello: "UPGRADE"
        }
    }

    private var facadesSlider: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Our Facades")
                    .font(.neueCorpMedium(24))
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
                NavigationLink(value: AllFacadesRoute.all) {
                    Text("See All")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(viewModel.allFacades) { facade in
                        NavigationLink(value: facade) {
                            facadeShowcaseCard(facade: facade)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
    }

    private func facadeShowcaseCard(facade: Facade) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color(AVIATheme.surfaceElevated)
                .frame(width: 320, height: 240)
                .overlay {
                    AsyncImage(url: URL(string: facade.heroImageURL)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else if phase.error != nil {
                            Image(systemName: "photo")
                                .font(.neueCorpMedium(24))
                                .foregroundStyle(AVIATheme.timelessBrown.opacity(0.25))
                        } else {
                            ProgressView()
                        }
                    }
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    Text(facade.pricing.isIncluded ? "INCLUDED" : "UPGRADE")
                        .font(.neueCorpMedium(9))
                        .kerning(0.8)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(facade.pricing.isIncluded ? AVIATheme.success.opacity(0.85) : AVIATheme.warning.opacity(0.85))
                        .clipShape(Capsule())
                        .padding(10)
                }
                .clipShape(.rect(cornerRadii: .init(topLeading: 16, topTrailing: 16)))

            VStack(alignment: .leading, spacing: 4) {
                Text(facade.name)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Text(facade.style)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(14)
        }
        .frame(width: 320)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }

    private var socialFollowBlock: some View {
        Link(destination: URL(string: "https://www.instagram.com/aviahomes")!) {
            Color(AVIATheme.timelessBrown)
                .aspectRatio(4.0/5.0, contentMode: .fit)
                .overlay {
                    AsyncImage(url: URL(string: "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/t8j7r8vibjqzvubxzcnbg.jpeg")) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill).opacity(0.35)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .overlay {
                    LinearGradient(
                        colors: [
                            AVIATheme.aviaBlack.opacity(0.25),
                            AVIATheme.aviaBlack.opacity(0.65)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .overlay {
                    VStack(spacing: 14) {
                        Spacer()
                        Image("AVIALogo")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 28)
                            .foregroundStyle(AVIATheme.aviaWhite)
                        Text("FOLLOW OUR JOURNEY")
                            .font(.neueCorpMedium(12))
                            .kerning(1.4)
                            .foregroundStyle(AVIATheme.aviaWhite.opacity(0.85))
                        Text("Follow Us on Social")
                            .font(.neueCorpMedium(30))
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .multilineTextAlignment(.center)
                        Text("Get the latest home inspiration, build progress and design tips from the AVIA team.")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.aviaWhite.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        Spacer()
                        HStack(spacing: 14) {
                            socialIcon("camera.fill", label: "Instagram")
                            socialIcon("play.rectangle.fill", label: "TikTok")
                            socialIcon("person.2.fill", label: "Facebook")
                        }
                        .padding(.bottom, 24)
                    }
                }
                .clipShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private func socialIcon(_ symbol: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AVIATheme.aviaWhite)
                .frame(width: 48, height: 48)
                .background(AVIATheme.aviaWhite.opacity(0.18))
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(AVIATheme.aviaWhite.opacity(0.3), lineWidth: 1)
                }
            Text(label)
                .font(.neueCaption2Medium)
                .foregroundStyle(AVIATheme.aviaWhite.opacity(0.9))
        }
    }

    private var brandFooter: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                stops: [
                    .init(color: AVIATheme.background, location: 0.0),
                    .init(color: AVIATheme.timelessBrown.opacity(0.4), location: 0.35),
                    .init(color: AVIATheme.timelessBrown.opacity(0.85), location: 0.65),
                    .init(color: AVIATheme.timelessBrown, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 320)

            Image("AVIALogo")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(AVIATheme.aviaWhite)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
        }
    }

    private var companyHighlightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why AVIA")
                .font(.neueCorpMedium(24))
                .foregroundStyle(AVIATheme.textPrimary)

            HStack(spacing: 12) {
                highlightCard(icon: "shield.checkerboard", title: "Quality\nAssured", description: "HIA member with full structural warranty")
                highlightCard(icon: "person.2.fill", title: "Personal\nService", description: "Dedicated build coordinator for your project")
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                highlightCard(icon: "leaf.fill", title: "Sustainable\nDesign", description: "Energy efficient homes as standard")
                highlightCard(icon: "star.fill", title: "Award\nWinning", description: "Multi-award winning Queensland builder")
            }
            .fixedSize(horizontal: false, vertical: true)

            contactBanner
        }
    }

    private func highlightCard(icon: String, title: String, description: String) -> some View {
        BentoCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .lineLimit(2)
                Text(description)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                    .lineLimit(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var contactBanner: some View {
        VStack(spacing: 0) {
            Color(AVIATheme.timelessBrown)
                .frame(height: 140)
                .overlay {
                    AsyncImage(url: URL(string: "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/t8j7r8vibjqzvubxzcnbg.jpeg")) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill).opacity(0.3)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadii: .init(topLeading: 16, topTrailing: 16)))
                .overlay {
                    VStack(spacing: 8) {
                        Image("AVIALogo")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 22)
                            .foregroundStyle(AVIATheme.aviaWhite)

                        Text("We Build Homes Worth Living In")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.aviaWhite.opacity(0.7))
                    }
                }

            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    if let phoneURL = URL(string: "tel:0756545123") {
                        Link(destination: phoneURL) {
                            HStack(spacing: 6) {
                                Image(systemName: "phone.fill").font(.neueCaption2)
                                Text("Call Us").font(.neueCaptionMedium)
                            }
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(AVIATheme.brownGradient)
                            .clipShape(.rect(cornerRadius: 10))
                        }
                    }

                    if let webURL = URL(string: "https://www.aviahomes.com.au") {
                        Link(destination: webURL) {
                            HStack(spacing: 6) {
                                Image(systemName: "safari.fill").font(.neueCaption2)
                                Text("Website").font(.neueCaptionMedium)
                            }
                            .foregroundStyle(AVIATheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(AVIATheme.surfaceElevated)
                            .clipShape(.rect(cornerRadius: 10))
                        }
                    }
                }

                HStack(spacing: 16) {
                    Label("Queensland", systemImage: "mappin.and.ellipse")
                    Spacer()
                    Label("Mon–Fri 8am–4pm", systemImage: "clock")
                }
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(14)
        }
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }

    private var sharedPackagesBanner: some View {
        Group {
            let sharedPackages = viewModel.clientSharedPackages
            if !sharedPackages.isEmpty {
                let pendingCount = sharedPackages.filter { pkg in
                    let response = viewModel.clientResponseForPackage(pkg.id, clientId: viewModel.currentUser.id)
                    return response == nil || response?.status == .pending
                }.count

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text("Shared With You")
                            .font(.neueCorpMedium(24))
                            .foregroundStyle(AVIATheme.textPrimary)
                        Spacer()
                        if pendingCount > 0 {
                            Text("\(pendingCount) new")
                                .font(.neueCaption2Medium)
                                .foregroundStyle(AVIATheme.aviaWhite)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(AVIATheme.timelessBrown)
                                .clipShape(Capsule())
                        }
                    }

                    ForEach(sharedPackages.prefix(3)) { pkg in
                        NavigationLink(value: pkg) {
                            sharedPackageMiniCard(package: pkg)
                        }
                        .buttonStyle(.plain)
                    }

                    if sharedPackages.count > 3 {
                        HStack {
                            Spacer()
                            Text("View all \(sharedPackages.count) packages")
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.timelessBrown)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AVIATheme.timelessBrown)
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }

    private func sharedPackageMiniCard(package: HouseLandPackage) -> some View {
        let response = viewModel.clientResponseForPackage(package.id, clientId: viewModel.currentUser.id)
        let isPending = response == nil || response?.status == .pending

        return BentoCard(cornerRadius: 16) {
            HStack(spacing: 12) {
                Color(AVIATheme.surfaceElevated)
                    .frame(width: 72, height: 72)
                    .overlay {
                        AsyncImage(url: URL(string: package.imageURL)) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(package.title)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.neueCorp(10))
                            .foregroundStyle(AVIATheme.timelessBrown)
                        Text(package.location)
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .lineLimit(1)
                    }

                    Text(package.price)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                }

                Spacer(minLength: 0)

                VStack(spacing: 6) {
                    if isPending {
                        Text("NEW")
                            .font(.neueCorpMedium(8))
                            .kerning(0.5)
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AVIATheme.timelessBrown)
                            .clipShape(Capsule())
                    } else {
                        Image(systemName: response?.status.icon ?? "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(response?.status == .accepted ? AVIATheme.success : AVIATheme.destructive)
                    }
                    Image(systemName: "chevron.right")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
            }
            .padding(12)
        }
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.neueCorpMedium(24))
                .foregroundStyle(AVIATheme.textPrimary)
            Spacer()
        }
    }
}
