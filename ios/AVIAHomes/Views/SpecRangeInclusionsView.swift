import SwiftUI

struct SpecRangeInclusionsView: View {
    let tier: SpecTier
    @State private var expandedCategories: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard

                ForEach(CatalogDataManager.shared.allSpecCategories) { category in
                    categorySection(category)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(AVIATheme.background)
        .navigationTitle("\(tier.displayName) Inclusions")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tier.displayName)
                    .font(.neueHeadline)
                    .foregroundStyle(AVIATheme.textPrimary)
                Text(tier.tagline)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textTertiary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                let totalItems = CatalogDataManager.shared.allSpecCategories.reduce(0) { $0 + $1.items.count }
                Text("\(totalItems)")
                    .font(.neueCorpMedium(22))
                    .foregroundStyle(AVIATheme.textPrimary)
                Text("items")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
        }
        .padding(16)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }

    private func categorySection(_ category: SpecCategory) -> some View {
        let isExpanded = expandedCategories.contains(category.id)

        return VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if isExpanded {
                        expandedCategories.remove(category.id)
                    } else {
                        expandedCategories.insert(category.id)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: category.icon)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                        .frame(width: 32, height: 32)
                        .background(AVIATheme.timelessBrown.opacity(0.08))
                        .clipShape(.rect(cornerRadius: 8))

                    Text(category.name)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)

                    Spacer(minLength: 0)

                    Text("\(category.items.count)")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textTertiary)

                    Image(systemName: "chevron.right")
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }

            if isExpanded {
                Divider()
                    .padding(.leading, 58)

                VStack(spacing: 0) {
                    ForEach(Array(category.items.enumerated()), id: \.element.id) { index, item in
                        inclusionRow(item: item)

                        if index < category.items.count - 1 {
                            Divider()
                                .padding(.leading, 14)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }

    private func inclusionRow(item: SpecItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(item.name)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)

                Spacer(minLength: 0)

                if item.isUpgradeable {
                    Text("UPGRADEABLE")
                        .font(.neueCorpMedium(8))
                        .kerning(0.5)
                        .foregroundStyle(AVIATheme.timelessBrown)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AVIATheme.timelessBrown.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            Text(item.description(for: tier))
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
