import SwiftUI

struct SpecificationCategoryDetailView: View {
    @Environment(SpecificationViewModel.self) private var specVM
    let category: SpecCategory
    @State private var previewTiers: [String: SpecTier] = [:]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                categoryHeader
                ForEach(category.items) { item in
                    itemCard(item)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.large)
    }

    private var categoryHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: category.icon)
                .font(.neueCorpMedium(16))
                .foregroundStyle(AVIATheme.aviaWhite)
                .frame(width: 44, height: 44)
                .background(AVIATheme.primaryGradient)
                .clipShape(.rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text("\(category.items.count) inclusions in this category")
                    .font(.neueSubheadline)
                    .foregroundStyle(AVIATheme.textSecondary)

                let upgradeCount = specVM.upgradeableItems(in: category).count
                if upgradeCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.neueCorp(10))
                        Text("\(upgradeCount) items can be upgraded")
                            .font(.neueCaption2)
                    }
                    .foregroundStyle(AVIATheme.timelessBrown)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }

    private func itemCard(_ item: SpecItem) -> some View {
        let hasPending = specVM.pendingUpgradeCount(for: item.id)
        let canUpgrade = specVM.hasUpgrade(for: item)
        let selectedTier = previewTiers[item.id] ?? specVM.currentTier

        return NavigationLink {
            SpecificationItemDetailView(item: item, categoryName: category.name)
        } label: {
            VStack(spacing: 0) {
                if item.imageURL != nil || item.hasTierSpecificImages {
                    specImageSection(item: item, selectedTier: selectedTier, hasPending: hasPending, canUpgrade: canUpgrade)
                }

                VStack(alignment: .leading, spacing: 10) {
                    if item.imageURL == nil && !item.hasTierSpecificImages {
                        HStack(spacing: 10) {
                            Text(item.name)
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Spacer()
                        }
                    }

                    HStack(spacing: 8) {
                        Text(selectedTier.displayName)
                            .font(.neueCaption2Medium)
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AVIATheme.aviaBlack)
                            .clipShape(Capsule())

                        Text(item.description(for: selectedTier))
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)
                    }

                    if canUpgrade {
                        Rectangle()
                            .fill(AVIATheme.surfaceBorder)
                            .frame(height: 1)

                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.neueCorp(10))
                                .foregroundStyle(AVIATheme.timelessBrown)

                            let nextTier = specVM.upgradeTiers.first { item.description(for: $0) != item.description(for: specVM.currentTier) }
                            if let nextTier {
                                Text("\(nextTier.displayName): \(item.description(for: nextTier))")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "chevron.right")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                    } else {
                        HStack {
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                    }
                }
                .padding(14)
            }
            .background(AVIATheme.cardBackground)
            .clipShape(.rect(cornerRadius: 16))
        }
    }

    private func specImageSection(item: SpecItem, selectedTier: SpecTier, hasPending: Bool, canUpgrade: Bool) -> some View {
        let displayURL: URL? = item.tierImageURL(for: selectedTier) ?? item.imageURL

        return Color(AVIATheme.surfaceElevated)
            .frame(height: 200)
            .overlay {
                Group {
                    if let url = displayURL {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else if phase.error != nil {
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                            } else {
                                ProgressView()
                                    .tint(AVIATheme.textTertiary)
                            }
                        }
                        .id(url)
                    }
                }
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.4),
                        .init(color: AVIATheme.aviaBlack.opacity(0.5), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomLeading) {
                Text(item.name)
                    .font(.neueCorpMedium(18))
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .padding(14)
            }
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 6) {
                    if hasPending {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.neueCorp(9))
                            Text("Pending")
                                .font(.neueCaption2Medium)
                        }
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AVIATheme.warning)
                        .clipShape(Capsule())
                    } else if canUpgrade {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.neueCorp(10))
                            Text("Upgradeable")
                                .font(.neueCaption2Medium)
                        }
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial.opacity(0.7))
                        .clipShape(Capsule())
                    }
                }
                .padding(10)
            }
            .overlay(alignment: .bottomTrailing) {
                if item.hasTierSpecificImages {
                    tierToggle(for: item)
                        .padding(10)
                }
            }
            .clipped()
    }

    private func tierToggle(for item: SpecItem) -> some View {
        let selectedTier = previewTiers[item.id] ?? specVM.currentTier

        return HStack(spacing: 2) {
            ForEach(SpecTier.allCases) { tier in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        previewTiers[item.id] = tier
                    }
                } label: {
                    Text(String(tier.displayName.prefix(1)))
                        .font(.neueCorpMedium(11))
                        .foregroundStyle(selectedTier == tier ? AVIATheme.aviaBlack : AVIATheme.aviaWhite)
                        .frame(width: 28, height: 24)
                        .background(selectedTier == tier ? AVIATheme.aviaWhite : AVIATheme.aviaWhite.opacity(0.25))
                        .clipShape(.rect(cornerRadius: 6))
                }
            }
        }
        .padding(3)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 9))
    }
}
