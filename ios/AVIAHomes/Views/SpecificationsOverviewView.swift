import SwiftUI

struct SpecificationsOverviewView: View {
    @Environment(SpecificationViewModel.self) private var specVM
    @Environment(CustomerJourneyViewModel.self) private var journeyVM
    @State private var showConfirmAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroImage

                    VStack(spacing: 14) {
                        headerRow
                        currentTierHeader
                        tierSelector
                        categoriesList
                        if !specVM.upgradeRequests.isEmpty {
                            upgradeRequestsSection
                        }
                        if !journeyVM.specsConfirmed {
                            confirmSpecsSection
                        } else {
                            specsConfirmedBanner
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(AVIATheme.background)
            .alert("Confirm Specifications", isPresented: $showConfirmAlert) {
                Button("Confirm") {
                    withAnimation(.spring(response: 0.4)) {
                        journeyVM.confirmSpecifications()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("By confirming, you agree your \(specVM.currentTier.rawValue) specification is finalised. You'll then move on to colour selections.")
            }
        }
    }

    private var confirmSpecsSection: some View {
        VStack(spacing: 10) {
            let pendingCount = specVM.upgradeRequests.filter { $0.status == .pending }.count

            if pendingCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.neueCorp(12))
                        .foregroundStyle(AVIATheme.warning)
                    Text("You have \(pendingCount) pending upgrade request\(pendingCount == 1 ? "" : "s"). Resolve these before confirming.")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AVIATheme.warning.opacity(0.08))
                .clipShape(.rect(cornerRadius: 12))
            }

            Button {
                showConfirmAlert = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.neueSubheadlineMedium)
                    Text("Confirm My Specifications")
                        .font(.neueSubheadlineMedium)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AVIATheme.tealGradient)
                .clipShape(.rect(cornerRadius: 14))
            }
            .disabled(pendingCount > 0)
            .opacity(pendingCount > 0 ? 0.5 : 1)
            .sensoryFeedback(.impact(flexibility: .soft), trigger: showConfirmAlert)
        }
    }

    private var specsConfirmedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.neueCorpMedium(20))
                .foregroundStyle(AVIATheme.success)
            VStack(alignment: .leading, spacing: 2) {
                Text("Specifications Confirmed")
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Text("Your \(specVM.currentTier.rawValue) inclusions are locked in. Move on to colour selections.")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(AVIATheme.success.opacity(0.06))
        .clipShape(.rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(AVIATheme.success.opacity(0.15), lineWidth: 1)
        }
    }

    private var heroImage: some View {
        Color(AVIATheme.surfaceElevated)
            .frame(height: 320)
            .overlay {
                Image("specs_hero")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0.0),
                        .init(color: AVIATheme.background.opacity(0.15), location: 0.25),
                        .init(color: AVIATheme.background.opacity(0.4), location: 0.45),
                        .init(color: AVIATheme.background.opacity(0.7), location: 0.65),
                        .init(color: AVIATheme.background.opacity(0.9), location: 0.8),
                        .init(color: AVIATheme.background, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)
            }
            .clipped()
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.teal)
            Text("Fittings & Fixtures")
                .font(.neueCorpMedium(24))
                .foregroundStyle(AVIATheme.textPrimary)
            Spacer()
        }
    }

    private var currentTierHeader: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: 140)
                    .overlay {
                        Image("spec_kitchen")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
                    .overlay {
                        LinearGradient(
                            stops: [
                                .init(color: AVIATheme.aviaBlack.opacity(0.0), location: 0.0),
                                .init(color: AVIATheme.aviaBlack.opacity(0.0), location: 0.3),
                                .init(color: AVIATheme.aviaBlack.opacity(0.15), location: 0.6),
                                .init(color: AVIATheme.aviaBlack.opacity(0.4), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .overlay(alignment: .topTrailing) {
                        Text(specVM.currentTier.tagline)
                            .font(.neueCaption2Medium)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial.opacity(0.6))
                            .clipShape(Capsule())
                            .padding(14)
                    }
                    .clipped()

                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your Specification")
                                .font(.neueCaption)
                                .foregroundStyle(.white.opacity(0.7))
                            Text(specVM.currentTier.rawValue)
                                .font(.neueCorpMedium(24))
                                .foregroundStyle(.white)
                        }

                        Spacer()

                        Image("spec_arrow")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 28)
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(specVM.categories.count)")
                                .font(.neueCorpMedium(20))
                                .foregroundStyle(.white)
                            Text("Categories")
                                .font(.neueCaption2)
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        Rectangle()
                            .fill(.white.opacity(0.15))
                            .frame(width: 1, height: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            let totalItems = specVM.categories.reduce(0) { $0 + $1.items.count }
                            Text("\(totalItems)")
                                .font(.neueCorpMedium(20))
                                .foregroundStyle(.white)
                            Text("Inclusions")
                                .font(.neueCaption2)
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        Rectangle()
                            .fill(.white.opacity(0.15))
                            .frame(width: 1, height: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(specVM.upgradeRequests.count)")
                                .font(.neueCorpMedium(20))
                                .foregroundStyle(.white)
                            Text("Upgrades")
                                .font(.neueCaption2)
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        Spacer()
                    }
                }
                .padding(20)
            }
            .background(AVIATheme.timelessBrown)
            .clipShape(.rect(cornerRadii: .init(topLeading: 20, topTrailing: 20)))

            if specVM.upgradeTiers.count > 0 {
                NavigationLink {
                    SpecificationCompareView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Compare & Upgrade Ranges")
                            .font(.neueSubheadlineMedium)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    .foregroundStyle(AVIATheme.textPrimary)
                    .padding(16)
                    .background(AVIATheme.cardBackground)
                    .clipShape(.rect(cornerRadii: .init(bottomLeading: 16, bottomTrailing: 16)))
                }
            }
        }
    }

    private var tierSelector: some View {
        HStack(spacing: 6) {
            ForEach(SpecTier.allCases) { tier in
                let isActive = tier == specVM.currentTier
                let isPast = tier.tierIndex < specVM.currentTier.tierIndex

                HStack(spacing: 5) {
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.neueCorp(10))
                    } else if isPast {
                        Image(systemName: "checkmark")
                            .font(.neueCorp(8))
                    }
                    Text(tier.rawValue)
                        .font(.neueCaption2Medium)
                }
                .foregroundStyle(isActive ? .white : AVIATheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(isActive ? AVIATheme.aviaBlack : AVIATheme.cardBackground)
                .clipShape(Capsule())
            }
        }
    }

    private var categoriesList: some View {
        let cats = specVM.categories
        return VStack(spacing: 12) {
            ForEach(0..<cats.count / 2 + cats.count % 2, id: \.self) { rowIndex in
                let firstIndex = rowIndex * 2
                let secondIndex = firstIndex + 1
                HStack(spacing: 12) {
                    NavigationLink {
                        SpecificationCategoryDetailView(category: cats[firstIndex])
                    } label: {
                        bentoCategoryCard(cats[firstIndex])
                    }
                    if secondIndex < cats.count {
                        NavigationLink {
                            SpecificationCategoryDetailView(category: cats[secondIndex])
                        } label: {
                            bentoCategoryCard(cats[secondIndex])
                        }
                    } else {
                        Color.clear
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func bentoCategoryCard(_ category: SpecCategory) -> some View {
        let upgradeCount = specVM.upgradeableItems(in: category).count
        let pendingCount = specVM.upgradeRequests.filter { req in
            category.items.contains { $0.id == req.itemId } && req.status == .pending
        }.count

        return BentoCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    BentoIconCircle(icon: category.icon, color: AVIATheme.teal)
                    Spacer()
                    if pendingCount > 0 {
                        Text("\(pendingCount)")
                            .font(.neueCaption2Medium)
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(AVIATheme.warning)
                            .clipShape(Circle())
                    }
                }

                Text(category.name)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(category.items.count)")
                        .font(.neueCorpMedium(28))
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("items")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }

                if upgradeCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.neueCorp(10))
                        Text("\(upgradeCount) upgradeable")
                            .font(.neueCaption2Medium)
                    }
                    .foregroundStyle(AVIATheme.teal)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var upgradeRequestsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.teal)
                Text("Upgrade Requests")
                    .font(.neueCorpMedium(18))
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
            }

            ForEach(specVM.upgradeRequests.prefix(3)) { request in
                upgradeRequestRow(request)
            }

            if specVM.upgradeRequests.count > 3 {
                NavigationLink {
                    AllUpgradeRequestsView()
                } label: {
                    Text("View all \(specVM.upgradeRequests.count) requests")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.teal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AVIATheme.cardBackground)
                        .clipShape(.rect(cornerRadius: 12))
                }
            }
        }
    }

    private func upgradeRequestRow(_ request: UpgradeRequest) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(request.itemName)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Text("\(request.categoryName) · \(request.fromTier.rawValue) → \(request.toTier.rawValue)")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            Spacer()
            StatusBadge(title: request.status.rawValue, color: upgradeStatusColor(request.status))
        }
        .padding(14)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 14))
    }

    private func upgradeStatusColor(_ status: UpgradeStatus) -> Color {
        switch status {
        case .pending: AVIATheme.warning
        case .quoted: Color(hex: "5B7DB1")
        case .approved: AVIATheme.success
        case .declined: AVIATheme.destructive
        }
    }
}
