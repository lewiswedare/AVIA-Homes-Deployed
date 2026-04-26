import SwiftUI

struct SpecificationCompareView: View {
    @Environment(SpecificationViewModel.self) private var specVM
    @State private var selectedCategory: SpecCategory?
    @State private var showFullUpgradeConfirm: Bool = false
    @State private var targetUpgradeTier: SpecTier = .portobello

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                rangeCards
                categoryPicker
                comparisonTable
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .navigationTitle("Compare Ranges")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if selectedCategory == nil {
                selectedCategory = specVM.categories.first
            }
        }
        .alert("Upgrade Entire Range", isPresented: $showFullUpgradeConfirm) {
            Button("Request Full Upgrade") {
                specVM.requestFullUpgrade(toTier: targetUpgradeTier)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Request an upgrade to the full \(targetUpgradeTier.displayName) specification? Our team will contact you with a comprehensive quote.")
        }
    }

    private var rangeCards: some View {
        VStack(spacing: 10) {
            ForEach(SpecTier.allCases) { tier in
                let isCurrent = tier == specVM.currentTier
                let isHigher = tier.tierIndex > specVM.currentTier.tierIndex

                HStack(spacing: 14) {
                    Color.clear
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(tier.imageName)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .allowsHitTesting(false)
                        }
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(isCurrent ? AVIATheme.aviaBlack : AVIATheme.timelessBrown.opacity(0.2), lineWidth: 2)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(tier.displayName)
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                            if isCurrent {
                                Text("CURRENT")
                                    .font(.neueCorpMedium(8))
                                    .foregroundStyle(AVIATheme.aviaWhite)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AVIATheme.aviaBlack)
                                    .clipShape(Capsule())
                            }
                        }
                        Text(tier.tagline)
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }

                    Spacer()

                    if isHigher {
                        Button {
                            targetUpgradeTier = tier
                            showFullUpgradeConfirm = true
                        } label: {
                            Text("Upgrade")
                                .font(.neueCaption2Medium)
                                .foregroundStyle(AVIATheme.aviaWhite)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(AVIATheme.primaryGradient)
                                .clipShape(Capsule())
                        }
                    } else if isCurrent {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.success)
                    }
                }
                .padding(14)
                .background(isCurrent ? AVIATheme.cardBackgroundAlt : AVIATheme.cardBackground)
                .clipShape(.rect(cornerRadius: 11))
                .overlay {
                    if isCurrent {
                        RoundedRectangle(cornerRadius: 11)
                            .stroke(AVIATheme.timelessBrown.opacity(0.3), lineWidth: 1.5)
                    }
                }
            }
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(specVM.categories) { category in
                    let isSelected = selectedCategory?.id == category.id
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategory = category
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.neueCorp(10))
                            Text(category.name)
                                .font(.neueCaption2Medium)
                        }
                        .foregroundStyle(isSelected ? AVIATheme.aviaWhite : AVIATheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isSelected ? AVIATheme.aviaBlack : AVIATheme.cardBackground)
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .contentMargins(.horizontal, 0)
        .scrollIndicators(.hidden)
    }

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            if let category = selectedCategory {
                HStack(alignment: .bottom, spacing: 0) {
                    Text("Item")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(SpecTier.allCases) { tier in
                        Text(tier.displayName)
                            .frame(maxWidth: .infinity)
                    }
                }
                .font(.neueCaption2Medium)
                .foregroundStyle(AVIATheme.textTertiary)
                .padding(12)
                .background(AVIATheme.surfaceElevated)
                .clipShape(.rect(cornerRadii: .init(topLeading: 14, topTrailing: 14)))

                ForEach(Array(category.items.enumerated()), id: \.element.id) { index, item in
                    VStack(spacing: 0) {
                        if index > 0 {
                            Rectangle()
                                .fill(AVIATheme.surfaceBorder)
                                .frame(height: 1)
                        }
                        comparisonRow(item: item)
                    }
                }
                .background(AVIATheme.cardBackground)
                .clipShape(.rect(cornerRadii: .init(bottomLeading: 14, bottomTrailing: 14)))
            }
        }
    }

    private func comparisonRow(item: SpecItem) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(item.name)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)

            ForEach(SpecTier.allCases) { tier in
                let isCurrent = tier == specVM.currentTier
                let desc = item.description(for: tier)

                VStack(alignment: .leading, spacing: 4) {
                    if isCurrent {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.neueCorp(8))
                                .foregroundStyle(AVIATheme.success)
                            Text("Yours")
                                .font(.neueCorpMedium(8))
                                .foregroundStyle(AVIATheme.success)
                        }
                    }
                    Text(desc)
                        .font(.neueCaption2)
                        .foregroundStyle(isCurrent ? AVIATheme.textPrimary : AVIATheme.textSecondary)
                        .lineLimit(4)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isCurrent ? AVIATheme.timelessBrown.opacity(0.04) : Color.clear)
            }
        }
        .padding(.vertical, 4)
    }
}
