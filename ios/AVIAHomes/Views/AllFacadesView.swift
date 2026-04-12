import SwiftUI

struct AllFacadesView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var selectedStoreyFilter: Int? = nil
    @State private var selectedPricingFilter: PricingFilter? = nil

    private var filteredFacades: [Facade] {
        var facades = viewModel.allFacades
        if let storeys = selectedStoreyFilter {
            facades = facades.filter { $0.storeys == storeys }
        }
        if let pricing = selectedPricingFilter {
            switch pricing {
            case .included:
                facades = facades.filter { $0.pricing.isIncluded }
            case .upgrade:
                facades = facades.filter { !$0.pricing.isIncluded }
            }
        }
        return facades
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerImage

                VStack(spacing: 20) {
                    titleSection

                    filtersSection

                    facadeCount

                    LazyVStack(spacing: 16) {
                        ForEach(filteredFacades) { facade in
                            NavigationLink(value: facade) {
                                facadeCard(facade: facade)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(AVIATheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var headerImage: some View {
        Color(AVIATheme.surfaceElevated)
            .frame(height: 280)
            .overlay {
                Image("hero_facade")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: AVIATheme.background.opacity(0.15), location: 0.25),
                        .init(color: AVIATheme.background.opacity(0.4), location: 0.45),
                        .init(color: AVIATheme.background.opacity(0.7), location: 0.65),
                        .init(color: AVIATheme.background.opacity(0.9), location: 0.8),
                        .init(color: AVIATheme.background, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 180)
            }
            .clipped()
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Our Facades")
                .font(.neueCorpMedium(32))
                .foregroundStyle(AVIATheme.textPrimary)

            Text("Choose the perfect look for your home's exterior")
                .font(.neueSubheadline)
                .foregroundStyle(AVIATheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Filters

    private var filtersSection: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                filterChip(
                    label: "Single Storey",
                    isActive: selectedStoreyFilter == 1
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedStoreyFilter = selectedStoreyFilter == 1 ? nil : 1
                    }
                }

                filterChip(
                    label: "Double Storey",
                    isActive: selectedStoreyFilter == 2
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedStoreyFilter = selectedStoreyFilter == 2 ? nil : 2
                    }
                }

                filterChip(
                    label: "Included",
                    isActive: selectedPricingFilter == .included
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedPricingFilter = selectedPricingFilter == .included ? nil : .included
                    }
                }

                filterChip(
                    label: "Upgrade",
                    isActive: selectedPricingFilter == .upgrade
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedPricingFilter = selectedPricingFilter == .upgrade ? nil : .upgrade
                    }
                }

                if selectedStoreyFilter != nil || selectedPricingFilter != nil {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedStoreyFilter = nil
                            selectedPricingFilter = nil
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.neueCorp(9))
                            Text("Clear")
                                .font(.neueCaptionMedium)
                        }
                        .foregroundStyle(AVIATheme.destructive)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var facadeCount: some View {
        HStack {
            Text("\(filteredFacades.count) facade\(filteredFacades.count == 1 ? "" : "s")")
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.textTertiary)
            Spacer()
        }
    }

    private func filterChip(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.neueCaptionMedium)
                .foregroundStyle(isActive ? .white : AVIATheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isActive ? AVIATheme.teal : AVIATheme.cardBackground)
                .clipShape(Capsule())
                .overlay {
                    if !isActive {
                        Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                    }
                }
        }
        .sensoryFeedback(.selection, trigger: isActive)
    }

    // MARK: - Facade Card

    private func facadeCard(facade: Facade) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color(AVIATheme.surfaceElevated)
                .frame(height: 200)
                .overlay {
                    AsyncImage(url: URL(string: facade.heroImageURL)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else if phase.error != nil {
                            Image(systemName: "photo")
                                .font(.neueCorpMedium(24))
                                .foregroundStyle(AVIATheme.teal.opacity(0.25))
                        } else {
                            ProgressView()
                        }
                    }
                    .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadii: .init(topLeading: 16, topTrailing: 16)))
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 6) {
                        Text(facade.style.uppercased())
                            .font(.neueCorpMedium(9))
                            .kerning(0.8)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AVIATheme.aviaBlack.opacity(0.7))
                            .clipShape(Capsule())

                        Text(facade.storeys == 1 ? "SINGLE STOREY" : "DOUBLE STOREY")
                            .font(.neueCorpMedium(9))
                            .kerning(0.8)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AVIATheme.teal.opacity(0.8))
                            .clipShape(Capsule())
                    }
                    .padding(12)
                }
                .overlay(alignment: .topTrailing) {
                    pricingBadge(facade.pricing)
                        .padding(12)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(facade.name)
                    .font(.neueCorpMedium(20))
                    .foregroundStyle(AVIATheme.textPrimary)

                Text(facade.description)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
                    .lineLimit(2)

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.neueCaption2)
                        Text("\(facade.galleryImageURLs.count) images")
                            .font(.neueCaption2)
                    }
                    .foregroundStyle(AVIATheme.textTertiary)

                    Spacer()

                    HStack(spacing: 4) {
                        Text("View Details")
                            .font(.neueCaptionMedium)
                        Image(systemName: "arrow.right")
                            .font(.neueCaption2)
                    }
                    .foregroundStyle(AVIATheme.teal)
                }
            }
            .padding(14)
        }
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }

    private func pricingBadge(_ pricing: FacadePricing) -> some View {
        Text(pricing.displayText)
            .font(.neueCorpMedium(9))
            .kerning(0.6)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(AVIATheme.timelessBrown.opacity(0.85))
            .clipShape(Capsule())
    }
}

private enum PricingFilter {
    case included
    case upgrade
}
