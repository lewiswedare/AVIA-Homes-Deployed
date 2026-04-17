import SwiftUI

struct SpecificationCategoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SpecificationViewModel.self) private var specVM
    let category: SpecCategory

    var body: some View {
        NavigationStack {
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.neueSubheadlineMedium)
                        .tint(AVIATheme.timelessBrown)
                }
            }
        }
        .presentationBackground(AVIATheme.background)
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
        let selectedTier = specVM.currentTier

        return NavigationLink {
            SpecificationItemDetailView(item: item, categoryName: category.name)
        } label: {
            VStack(spacing: 0) {
                if item.imageURL != nil || item.hasTierSpecificImages {
                    specImageSection(item: item, selectedTier: selectedTier, hasPending: hasPending, canUpgrade: canUpgrade)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text(item.name)
                            .font(.neueCorpMedium(18))
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)

                        Image("spec_arrow")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .foregroundStyle(AVIATheme.aviaWhite.opacity(0.85))
                    }

                    Rectangle()
                        .fill(AVIATheme.aviaWhite.opacity(0.2))
                        .frame(height: 1)

                    Text(item.description(for: selectedTier))
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.aviaWhite.opacity(0.85))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
            }
            .background(AVIATheme.timelessBrown)
            .clipShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
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
            .clipped()
    }
}
