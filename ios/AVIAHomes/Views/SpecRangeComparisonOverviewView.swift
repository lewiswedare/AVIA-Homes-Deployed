import SwiftUI

struct SpecRangeComparisonOverviewView: View {
    @State private var selectedCategoryIndex: Int = 0
    @State private var expandedItemId: String?
    @State private var highlightedTier: SpecTier?

    private let tiers = SpecTier.allCases
    private var categories: [SpecCategory] { CatalogDataManager.shared.allSpecCategories }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                tierSelector
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                categoryPicker
                    .padding(.top, 16)

                itemsList
                    .padding(.top, 12)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
            }
        }
        .background(AVIATheme.background)
        .navigationTitle("Compare Spec Ranges")
        .navigationBarTitleDisplayMode(.large)
    }

    private var tierSelector: some View {
        HStack(spacing: 8) {
            ForEach(tiers) { tier in
                let data = CatalogDataManager.shared.specRangeData(for: tier)
                let isSelected = highlightedTier == tier

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        highlightedTier = highlightedTier == tier ? nil : tier
                    }
                } label: {
                    VStack(spacing: 8) {
                        Color(AVIATheme.surfaceElevated)
                            .frame(height: 80)
                            .overlay {
                                AsyncImage(url: URL(string: data.heroImageURL)) { phase in
                                    if let image = phase.image {
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    }
                                }
                                .allowsHitTesting(false)
                            }
                            .clipShape(.rect(cornerRadius: 12))

                        Text(tier.displayName)
                            .font(.neueCaptionMedium)
                            .foregroundStyle(isSelected ? AVIATheme.aviaBlack : AVIATheme.textPrimary)

                        Text(tier.tagline)
                            .font(.neueCaption2)
                            .foregroundStyle(isSelected ? AVIATheme.textSecondary : AVIATheme.textTertiary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)
                }
            }
        }
        .padding(12)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
        .overlay {
            if highlightedTier != nil {
                selectedTierIndicator
            }
        }
    }

    @ViewBuilder
    private var selectedTierIndicator: some View {
        if let tier = highlightedTier {
            VStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.neueCorp(11))
                    Text("Viewing \(tier.displayName)")
                        .font(.neueCaption2Medium)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AVIATheme.aviaBlack)
                .clipShape(Capsule())
                .offset(y: 14)
            }
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                    let isSelected = index == selectedCategoryIndex
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategoryIndex = index
                            expandedItemId = nil
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.neueCorp(10))
                            Text(category.name)
                                .font(.neueCaption2Medium)
                        }
                        .foregroundStyle(isSelected ? .white : AVIATheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isSelected ? AVIATheme.aviaBlack : AVIATheme.cardBackground)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .contentMargins(.horizontal, 0)
        .scrollIndicators(.hidden)
        .padding(.top, highlightedTier != nil ? 8 : 0)
    }

    private var itemsList: some View {
        let safeIndex = min(selectedCategoryIndex, max(categories.count - 1, 0))

        return VStack(spacing: 12) {
            if categories.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundStyle(AVIATheme.textTertiary)
                    Text("No spec items available")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textSecondary)
                    Text("Spec range data is managed by your admin team.")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(categories[safeIndex].items) { item in
                    comparisonItemCard(item: item)
                }
            }
        }
    }

    private func comparisonItemCard(item: SpecItem) -> some View {
        let isExpanded = expandedItemId == item.id

        return VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    expandedItemId = isExpanded ? nil : item.id
                }
            } label: {
                HStack(spacing: 12) {
                    if let url = item.imageURL {
                        Color(AVIATheme.surfaceElevated)
                            .frame(width: 44, height: 44)
                            .overlay {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    }
                                }
                                .allowsHitTesting(false)
                            }
                            .clipShape(.rect(cornerRadius: 8))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)

                        if item.isUpgradeable {
                            Text("UPGRADEABLE")
                                .font(.neueCorpMedium(8))
                                .kerning(0.5)
                                .foregroundStyle(AVIATheme.teal)
                        }
                    }

                    Spacer(minLength: 0)

                    if let tier = highlightedTier {
                        Text(item.description(for: tier))
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                    }

                    Image(systemName: "chevron.right")
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(14)
            }

            if isExpanded {
                Divider()
                    .padding(.horizontal, 14)

                tierComparisonGrid(item: item)
                    .padding(14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }

    private func tierComparisonGrid(item: SpecItem) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(tiers) { tier in
                    let isHighlighted = highlightedTier == tier
                    Text(tier.displayName)
                        .font(isHighlighted ? .neueCaption2Medium : .neueCaption2Medium)
                        .foregroundStyle(isHighlighted ? AVIATheme.aviaBlack : AVIATheme.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            HStack(alignment: .top, spacing: 8) {
                ForEach(tiers) { tier in
                    tierCell(item: item, tier: tier)
                }
            }
        }
    }

    private func tierCell(item: SpecItem, tier: SpecTier) -> some View {
        let isHighlighted = highlightedTier == tier

        return VStack(spacing: 8) {
            if let url = item.tierImageURL(for: tier) {
                Color(isHighlighted ? AVIATheme.aviaBlack.opacity(0.1) : AVIATheme.surfaceElevated)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else if phase.error != nil {
                                Image(systemName: "photo")
                                    .font(.neueCorp(16))
                                    .foregroundStyle(AVIATheme.textTertiary.opacity(0.3))
                            } else {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 8))
            } else if let url = item.imageURL {
                Color(isHighlighted ? AVIATheme.aviaBlack.opacity(0.1) : AVIATheme.surfaceElevated)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 8))
            }

            Text(item.description(for: tier))
                .font(isHighlighted ? .neueCaption2Medium : .neueCaption2)
                .foregroundStyle(isHighlighted ? AVIATheme.textPrimary : AVIATheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(6)
        .background(isHighlighted ? AVIATheme.aviaBlack.opacity(0.05) : Color.clear)
        .clipShape(.rect(cornerRadius: 10))
    }
}
