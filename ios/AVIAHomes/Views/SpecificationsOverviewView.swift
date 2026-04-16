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
                Text("By confirming, you agree your \(specVM.currentTier.displayName) specification is finalised. You'll then move on to colour selections.")
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
                Text("Your \(specVM.currentTier.displayName) inclusions are locked in. Move on to colour selections.")
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
                Text("Fittings & Fixtures")
                    .font(.neueCorpMedium(28))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial)
            }
            .clipped()
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
                            Text(specVM.currentTier.displayName)
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
                    Text(tier.displayName)
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
                    Text(category.name)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
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

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(category.items.count)")
                        .font(.neueCorpMedium(28))
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("items")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }

                if upgradeCount > 0 {
                    Text("\(upgradeCount) upgradeable")
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var upgradeTotalCost: Double {
        specVM.upgradeRequests.compactMap(\.upgradeCost).reduce(0, +)
    }

    private var upgradeRequestsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Upgrade Requests")
                    .font(.neueCorpMedium(18))
                    .foregroundStyle(AVIATheme.textPrimary)
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(AVIATheme.timelessBrown)
                            .frame(width: 3)
                    }
                Spacer()
                if upgradeTotalCost > 0 {
                    Text(AVIATheme.formatCost(upgradeTotalCost))
                        .font(.neueCorpMedium(14))
                        .foregroundStyle(AVIATheme.timelessBrown)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AVIATheme.timelessBrown.opacity(0.08))
                        .clipShape(Capsule())
                }
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(request.itemName)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("\(request.categoryName) · \(request.fromTier.displayName) → \(request.toTier.displayName)")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                Spacer()
                StatusBadge(title: request.status.rawValue, color: upgradeStatusColor(request.status))
            }

            if let cost = request.upgradeCost, cost > 0 {
                HStack(spacing: 4) {
                    Text(AVIATheme.formatCost(cost))
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text("upgrade cost")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AVIATheme.timelessBrown.opacity(0.08))
                .clipShape(Capsule())
            }

            if let notes = request.adminNotes, !notes.isEmpty {
                Text(notes)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AVIATheme.surfaceElevated)
                    .clipShape(.rect(cornerRadius: 10))
            }

            if request.status == .pending {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AVIATheme.warning)
                        .frame(width: 6, height: 6)
                    Text("Under Review")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
            }
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
