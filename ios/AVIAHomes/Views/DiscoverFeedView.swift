import SwiftUI

struct DiscoverFeedView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var showDesignDirectory: Bool = false
    @State private var showAllNews: Bool = false
    @State private var showSpecComparison: Bool = false

    var body: some View {
        VStack(spacing: 32) {
            sharedPackagesBanner
            latestNewsSection
            ourDesignsSection
            specRangesSlider
            facadesSlider
            socialFollowBlock
        }
        .fullScreenCover(isPresented: $showDesignDirectory) {
            HomeDesignDirectoryView()
        }
        .navigationDestination(isPresented: $showAllNews) {
            AllNewsView()
        }
        .navigationDestination(isPresented: $showSpecComparison) {
            SpecRangeComparisonOverviewView()
        }
        .navigationDestination(for: BlogPost.self) { post in
            NewsArticleDetailView(post: post)
        }
        .navigationDestination(for: AllFacadesRoute.self) { _ in
            AllFacadesView()
        }
    }

    // MARK: - Shared Packages Banner

    @ViewBuilder
    private var sharedPackagesBanner: some View {
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
                    .buttonStyle(.pressable(.subtle))
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

    private func sharedPackageMiniCard(package: HouseLandPackage) -> some View {
        let response = viewModel.clientResponseForPackage(package.id, clientId: viewModel.currentUser.id)
        let isPending = response == nil || response?.status == .pending

        return BentoCard(cornerRadius: 13) {
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
                    .clipShape(.rect(cornerRadius: 8))

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

    // MARK: - Latest News

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
                .buttonStyle(.pressable(.subtle))
            }

            ForEach(viewModel.allBlogPosts.dropFirst().prefix(2)) { post in
                NavigationLink(value: post) {
                    compactBlogRow(post: post)
                }
                .buttonStyle(.pressable(.subtle))
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
                    AVIAChip(post.category.uppercased(), onLight: false)
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
        .clipShape(.rect(cornerRadius: 13))
    }

    private func compactBlogRow(post: BlogPost) -> some View {
        BentoCard(cornerRadius: 13) {
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
                    .clipShape(.rect(cornerRadius: 8))

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

    // MARK: - Our Designs

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
                        .clipShape(.rect(cornerRadius: 13))
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
    }

    private func designCard(design: HomeDesign) -> some View {
        Color(hex: "f5f5f5")
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
                .background(Color(hex: "f5f5f5"))
                .clipShape(.rect(cornerRadii: .init(bottomLeading: 16, bottomTrailing: 16)))
            }
            .clipShape(.rect(cornerRadius: 13))
    }

    // MARK: - Spec Ranges

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
                    .buttonStyle(.pressable(.subtle))
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
            .overlay(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tier.displayName)
                        .font(.neueCorpMedium(28))
                        .foregroundStyle(AVIATheme.aviaWhite)

                    HStack(alignment: .center, spacing: 12) {
                        Text(tier.tagline)
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.aviaWhite.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 8)

                        AVIAPill("Explore \(tier.displayName)", style: .onImage)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
            }
            .clipShape(.rect(cornerRadius: 16))
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

    // MARK: - Facades

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
                        .buttonStyle(.pressable(.subtle))
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
                    AVIAPill(facade.pricing.isIncluded ? "Included" : "Upgrade", style: .onImage)
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
        .clipShape(.rect(cornerRadius: 13))
    }

    // MARK: - Social

    private var socialFollowBlock: some View {
        Color(AVIATheme.cardBackground)
            .aspectRatio(4.0/5.0, contentMode: .fit)
            .overlay {
                Image("SocialInstagram")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .allowsHitTesting(false)
            }
            .clipShape(.rect(cornerRadius: 16))
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .bottom) {
                    Text("Stay Social")
                        .font(.neueCorpMedium(28))
                        .foregroundStyle(AVIATheme.aviaWhite)
                    Spacer()
                    Link(destination: URL(string: "https://www.instagram.com/aviahomes")!) {
                        AVIAPill("Instagram", icon: "arrow.up.right", style: .onImage)
                    }
                    .buttonStyle(.pressable(.subtle))
                }
                .padding(20)
            }
    }
}
