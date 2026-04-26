import SwiftUI

struct AdminCatalogHubView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var specCount: Int = 0
    @State private var colourCount: Int = 0
    @State private var designCount: Int = 0
    @State private var facadeCount: Int = 0
    @State private var newsCount: Int = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard

                VStack(spacing: 10) {
                    NavigationLink {
                        AdminSpecItemsEditorView()
                    } label: {
                        catalogCard(
                            icon: "list.clipboard.fill",
                            title: "Spec Range Items",
                            subtitle: "Manage specification items across Volos, Messina & Portobello tiers",
                            count: specCount,
                            countLabel: "items",
                            color: AVIATheme.timelessBrown
                        )
                    }

                    NavigationLink {
                        AdminColourEditorView()
                    } label: {
                        catalogCard(
                            icon: "paintpalette.fill",
                            title: "Colour Selections",
                            subtitle: "Manage colour categories, options, brands & upgrade flags",
                            count: colourCount,
                            countLabel: "categories",
                            color: AVIATheme.warning
                        )
                    }

                    NavigationLink {
                        AdminHomeDesignsEditorView()
                    } label: {
                        catalogCard(
                            icon: "house.fill",
                            title: "Home Designs",
                            subtitle: "Manage floor plans, dimensions, highlights & inclusions",
                            count: designCount,
                            countLabel: "designs",
                            color: AVIATheme.success
                        )
                    }

                    NavigationLink {
                        AdminFacadeEditorView()
                    } label: {
                        catalogCard(
                            icon: "building.columns.fill",
                            title: "Facades",
                            subtitle: "Manage facade styles, images, pricing & features",
                            count: facadeCount,
                            countLabel: "facades",
                            color: AVIATheme.heritageBlue
                        )
                    }

                    NavigationLink {
                        AdminNewsEditorView()
                    } label: {
                        catalogCard(
                            icon: "newspaper.fill",
                            title: "News Articles",
                            subtitle: "Publish, edit & manage news articles shown in the app",
                            count: newsCount,
                            countLabel: "articles",
                            color: AVIATheme.timelessBrown
                        )
                    }

                }

                NavigationLink {
                    AdminSpecRangeEditorView()
                } label: {
                    BentoCard(cornerRadius: 11) {
                        HStack(spacing: 14) {
                            Image(systemName: "square.stack.3d.up.fill")
                                .font(.neueCorpMedium(16))
                                .foregroundStyle(AVIATheme.timelessBrown)
                                .frame(width: 44, height: 44)
                                .background(AVIATheme.timelessBrown.opacity(0.12))
                                .clipShape(.rect(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Spec Range Content")
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text("Edit hero image, summary, highlights & room gallery for each spec range")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                        .padding(14)
                    }
                }

                NavigationLink {
                    AdminSpecRangePricingView()
                } label: {
                    BentoCard(cornerRadius: 11) {
                        HStack(spacing: 14) {
                            Image(systemName: "dollarsign.arrow.trianglehead.counterclockwise.rotate.90")
                                .font(.neueCorpMedium(16))
                                .foregroundStyle(AVIATheme.timelessBrown)
                                .frame(width: 44, height: 44)
                                .background(AVIATheme.timelessBrown.opacity(0.12))
                                .clipShape(.rect(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Spec Range Upgrade Pricing")
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text("Set the cost for upgrading the entire spec range between tiers")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                        .padding(14)
                    }
                }

                infoCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .hapticRefresh { await appViewModel.refreshAllData() }
        .background(AVIATheme.background)
        .navigationTitle("Catalog Management")
        .navigationBarTitleDisplayMode(.large)
        .task { await loadCounts() }
    }

    private var headerCard: some View {
        BentoCard(cornerRadius: 13) {
            HStack(spacing: 14) {
                Image(systemName: "slider.horizontal.3")
                    .font(.neueCorpMedium(18))
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(width: 44, height: 44)
                    .background(AVIATheme.primaryGradient)
                    .clipShape(.rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Product Catalog")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Add, edit and manage your spec ranges, colours and home designs")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(16)
        }
    }

    private func catalogCard(icon: String, title: String, subtitle: String, count: Int, countLabel: String, color: Color) -> some View {
        BentoCard(cornerRadius: 11) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.neueCorpMedium(16))
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text(subtitle)
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("\(count)")
                        .font(.neueCorpMedium(18))
                        .foregroundStyle(color)
                    Text(countLabel)
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

    private var infoCard: some View {
        BentoCard(cornerRadius: 11) {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.neueCorp(14))
                    .foregroundStyle(AVIATheme.timelessBrown)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Changes sync instantly")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("All updates are saved to the database and reflected across the app immediately for all users.")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
            }
            .padding(14)
        }
    }

    private func loadCounts() async {
        let catalog = CatalogDataManager.shared
        if !catalog.isLoaded { await catalog.loadAll() }

        specCount = catalog.allSpecCategories.flatMap(\.items).count
        colourCount = catalog.allColourCategories.count
        let designs = await SupabaseService.shared.fetchHomeDesigns()
        designCount = designs.count
        let facades = await SupabaseService.shared.fetchFacades()
        facadeCount = facades.count
        let posts = await SupabaseService.shared.fetchBlogPosts()
        newsCount = posts.count
    }
}
