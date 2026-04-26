import SwiftUI

struct SpecificationItemDetailView: View {
    @Environment(SpecificationViewModel.self) private var specVM
    let item: SpecItem
    let categoryName: String
    @State private var showUpgradeConfirm: Bool = false
    @State private var selectedUpgradeTier: SpecTier = .portobello
    @State private var previewTier: SpecTier?

    private var activeTier: SpecTier {
        previewTier ?? specVM.currentTier
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if item.imageURL != nil || item.hasTierSpecificImages {
                    heroImage
                }

                VStack(spacing: 16) {
                    currentSpecCard
                    if specVM.hasUpgrade(for: item) {
                        upgradeOptionsSection
                    }
                    allTiersComparison
                }
                .padding(.horizontal, 16)
                .padding(.top, (item.imageURL != nil || item.hasTierSpecificImages) ? 0 : 8)
                .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea(edges: (item.imageURL != nil || item.hasTierSpecificImages) ? .top : [])
        .background(AVIATheme.background)
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            previewTier = specVM.currentTier
        }
        .alert("Request Upgrade", isPresented: $showUpgradeConfirm) {
            Button("Request") {
                specVM.requestUpgrade(item: item, categoryName: categoryName, toTier: selectedUpgradeTier)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let cost = item.upgradeCost(from: specVM.currentTier, to: selectedUpgradeTier), cost > 0 {
                Text("Request an upgrade to \(selectedUpgradeTier.displayName) for \(item.name)?\n\nEstimated cost: \(AVIATheme.formatCost(cost))")
            } else {
                Text("Request an upgrade to the \(selectedUpgradeTier.displayName) specification for \(item.name)? Our team will provide a quote.")
            }
        }
    }

    private var heroImage: some View {
        let displayURL: URL? = item.tierImageURL(for: activeTier) ?? item.imageURL

        return Color(AVIATheme.surfaceElevated)
            .frame(height: 500)
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
                                    .font(.largeTitle)
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
            .overlay(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: AVIATheme.background.opacity(0.3), location: 0.5),
                        .init(color: AVIATheme.background, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
            }
            .overlay(alignment: .bottomTrailing) {
                if item.hasTierSpecificImages {
                    tierSelector
                        .padding(.trailing, 16)
                        .padding(.bottom, 24)
                }
            }
            .clipped()
    }

    private var tierSelector: some View {
        HStack(spacing: 3) {
            ForEach(SpecTier.allCases) { tier in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        previewTier = tier
                    }
                } label: {
                    Text(tier.displayName)
                        .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .padding(.horizontal, activeTier == tier ? 12 : 10)
                    .padding(.vertical, 7)
                    .background(activeTier == tier ? AVIATheme.timelessBrown : AVIATheme.timelessBrown.opacity(0.45))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private var currentSpecCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: activeTier == specVM.currentTier ? "checkmark.circle.fill" : "eye.fill")
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(activeTier == specVM.currentTier ? AVIATheme.success : AVIATheme.timelessBrown)
                Text(activeTier == specVM.currentTier ? "Your Current Specification" : "Viewing \(activeTier.displayName) Specification")
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
                Text(activeTier.displayName)
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AVIATheme.aviaBlack)
                    .clipShape(Capsule())
            }

            Text(item.description(for: activeTier))
                .font(.neueBody)
                .foregroundStyle(AVIATheme.textPrimary)
                .animation(.default, value: activeTier)
        }
        .padding(16)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 13))
    }

    private var upgradeOptionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Upgrade Options")
                .font(.neueCorpMedium(18))
                .foregroundStyle(AVIATheme.textPrimary)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(AVIATheme.timelessBrown)
                        .frame(width: 3)
                }

            ForEach(specVM.upgradeTiers) { tier in
                let tierDesc = item.description(for: tier)
                let currentDesc = item.description(for: specVM.currentTier)
                if tierDesc != currentDesc {
                    upgradeOptionCard(tier: tier, description: tierDesc)
                }
            }
        }
    }

    private func upgradeOptionCard(tier: SpecTier, description: String) -> some View {
        let hasPending = specVM.upgradeRequests.contains { $0.itemId == item.id && $0.toTier == tier && $0.status == .pending }
        let cost = item.upgradeCost(from: specVM.currentTier, to: tier)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Color.clear
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(tier.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(tier.displayName)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text(tier.tagline)
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }

                Spacer()

                if let cost, cost > 0 {
                    Text("+\(AVIATheme.formatCost(cost))")
                        .font(.neueCorpMedium(14))
                        .foregroundStyle(AVIATheme.timelessBrown)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AVIATheme.timelessBrown.opacity(0.1))
                        .clipShape(Capsule())
                } else if cost == nil {
                    Text("Contact for pricing")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
            }

            Text(description)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)

            if hasPending {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.neueCorp(10))
                    Text("Upgrade Requested")
                        .font(.neueCaptionMedium)
                }
                .foregroundStyle(AVIATheme.warning)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(AVIATheme.warning.opacity(0.1))
                .clipShape(.rect(cornerRadius: 8))
            } else {
                Button {
                    selectedUpgradeTier = tier
                    showUpgradeConfirm = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.neueCaptionMedium)
                        Text(cost != nil && cost! > 0 ? "Request Upgrade · \(AVIATheme.formatCost(cost!))" : "Request Upgrade")
                            .font(.neueCaptionMedium)
                    }
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AVIATheme.primaryGradient)
                    .clipShape(.rect(cornerRadius: 8))
                }
            }
        }
        .padding(14)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 11))
    }

    private var allTiersComparison: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("All Ranges")
                .font(.neueCorpMedium(18))
                .foregroundStyle(AVIATheme.textPrimary)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(AVIATheme.timelessBrown)
                        .frame(width: 3)
                }

            ForEach(SpecTier.allCases) { tier in
                let isCurrent = tier == specVM.currentTier
                let isViewing = tier == activeTier

                Button {
                    if item.hasTierSpecificImages {
                        withAnimation(.spring(duration: 0.3)) {
                            previewTier = tier
                        }
                    }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(isViewing ? AVIATheme.timelessBrown : (isCurrent ? AVIATheme.timelessBrown.opacity(0.4) : AVIATheme.surfaceBorder))
                                .frame(width: 10, height: 10)
                            if tier != .portobello {
                                Rectangle()
                                    .fill(AVIATheme.surfaceBorder)
                                    .frame(width: 1.5)
                            }
                        }
                        .frame(width: 10)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(tier.displayName)
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(isViewing ? AVIATheme.timelessBrown : AVIATheme.textSecondary)
                                if isCurrent {
                                    Text("YOURS")
                                        .font(.neueCorpMedium(8))
                                        .foregroundStyle(AVIATheme.timelessBrown)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(AVIATheme.timelessBrown.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                                if !isCurrent, let cost = item.upgradeCost(from: specVM.currentTier, to: tier), cost > 0 {
                                    Text("+\(AVIATheme.formatCost(cost))")
                                        .font(.neueCorpMedium(9))
                                        .foregroundStyle(AVIATheme.timelessBrown)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(AVIATheme.timelessBrown.opacity(0.08))
                                        .clipShape(Capsule())
                                }
                            }
                            Text(item.description(for: tier))
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressable(.subtle))
            }
        }
        .padding(16)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 13))
    }
}
