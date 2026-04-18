import SwiftUI

struct SpecRangeComparisonOverviewView: View {
    @State private var expandedItemId: String?
    @State private var leftTier: SpecTier = .volos
    @State private var rightTier: SpecTier = .messina

    private var categories: [SpecCategory] { CatalogDataManager.shared.allSpecCategories }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                tierPicker

                if categories.isEmpty {
                    emptyState
                } else {
                    ForEach(categories) { category in
                        categorySection(category)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .navigationTitle("Compare Spec Ranges")
        .navigationBarTitleDisplayMode(.large)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundStyle(AVIATheme.textTertiary)
            Text("No spec items available")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var tierPicker: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Select two ranges to compare")
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textSecondary)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.35)) {
                        let tmp = leftTier
                        leftTier = rightTier
                        rightTier = tmp
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Swap")
                            .font(.neueCaption2Medium)
                    }
                    .foregroundStyle(AVIATheme.timelessBrown)
                }
            }

            HStack(spacing: 12) {
                tierSelector(label: "Range A", selection: $leftTier, other: rightTier)
                tierSelector(label: "Range B", selection: $rightTier, other: leftTier)
            }
        }
        .padding(14)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }

    private func tierSelector(label: String, selection: Binding<SpecTier>, other: SpecTier) -> some View {
        Menu {
            ForEach(SpecTier.allCases) { tier in
                Button {
                    withAnimation(.spring(response: 0.35)) { selection.wrappedValue = tier }
                } label: {
                    HStack {
                        Text(tier.displayName)
                        if selection.wrappedValue == tier {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(label.uppercased())
                    .font(.neueCorpMedium(9))
                    .kerning(1.0)
                    .foregroundStyle(AVIATheme.textTertiary)

                HStack {
                    Text(selection.wrappedValue.displayName)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                Text(selection.wrappedValue.tagline)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(AVIATheme.surfaceElevated.opacity(0.5))
            .clipShape(.rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AVIATheme.timelessBrown.opacity(0.25), lineWidth: 1)
            }
        }
    }

    private func categorySection(_ category: SpecCategory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .frame(width: 32, height: 32)
                    .background(AVIATheme.timelessBrown.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 8))

                Text(category.name)
                    .font(.neueHeadline)
                    .foregroundStyle(AVIATheme.textPrimary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 14) {
                ForEach(category.items) { item in
                    comparisonCard(item: item)
                }
            }
        }
    }

    private func comparisonCard(item: SpecItem) -> some View {
        let isExpanded = expandedItemId == item.id

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(item.name)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
                if item.isUpgradeable {
                    Text("UPGRADEABLE")
                        .font(.neueCorpMedium(8))
                        .kerning(0.5)
                        .foregroundStyle(AVIATheme.timelessBrown)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AVIATheme.timelessBrown.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            HStack(alignment: .top, spacing: 10) {
                bigTierCell(item: item, tier: leftTier)
                bigTierCell(item: item, tier: rightTier)
            }

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    expandedItemId = isExpanded ? nil : item.id
                }
            } label: {
                HStack(spacing: 6) {
                    Text(isExpanded ? "Hide available colours" : "Show available colours")
                        .font(.neueCaption2Medium)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .foregroundStyle(AVIATheme.timelessBrown)
            }

            if isExpanded {
                coloursPreview(item: item)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 18))
    }

    private func bigTierCell(item: SpecItem, tier: SpecTier) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(tier.displayName.uppercased())
                    .font(.neueCorpMedium(9))
                    .kerning(0.8)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AVIATheme.timelessBrown)
                    .clipShape(Capsule())
                Spacer()
            }

            Color(AVIATheme.surfaceElevated)
                .aspectRatio(1.1, contentMode: .fit)
                .overlay {
                    if let url = item.tierImageURL(for: tier) ?? item.imageURL {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else if phase.error != nil {
                                Image(systemName: "photo")
                                    .font(.neueCorp(18))
                                    .foregroundStyle(AVIATheme.textTertiary.opacity(0.3))
                            } else {
                                ProgressView().controlSize(.small)
                            }
                        }
                        .allowsHitTesting(false)
                    } else {
                        Image(systemName: "photo")
                            .font(.neueCorp(18))
                            .foregroundStyle(AVIATheme.textTertiary.opacity(0.3))
                    }
                }
                .clipShape(.rect(cornerRadius: 12))

            Text(item.description(for: tier))
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AVIATheme.surfaceElevated.opacity(0.4))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func coloursPreview(item: SpecItem) -> some View {
        let colourCategory = resolveColourCategory(for: item)

        return VStack(alignment: .leading, spacing: 10) {
            Divider()

            Text("Available colour options")
                .font(.neueCaption2Medium)
                .foregroundStyle(AVIATheme.textSecondary)

            if let colourCategory, !colourCategory.options.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(colourCategory.options.prefix(12)) { option in
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: option.hexColor))
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        Circle()
                                            .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                                    }
                                Text(option.name)
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textSecondary)
                                    .lineLimit(1)
                                    .frame(maxWidth: 60)
                            }
                        }
                    }
                }
            } else {
                Text("Colour selections are personalised with your AVIA consultant.")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
        }
    }

    private func resolveColourCategory(for item: SpecItem) -> ColourCategory? {
        let categories = CatalogDataManager.shared.allColourCategories
        let target = item.name.lowercased()
        return categories.first { $0.name.lowercased() == target }
            ?? categories.first { $0.name.lowercased().contains(target) || target.contains($0.name.lowercased()) }
    }
}

