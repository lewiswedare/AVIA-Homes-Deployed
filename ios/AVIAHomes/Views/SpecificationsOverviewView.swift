import SwiftUI

struct SpecificationsOverviewView: View {
    @Environment(SpecificationViewModel.self) private var specVM
    @Environment(CustomerJourneyViewModel.self) private var journeyVM
    @State private var showConfirmAlert = false
    @State private var selectedCategory: SpecCategory?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroImage

                    VStack(spacing: 16) {
                        specificationCard
                        if specVM.upgradeTiers.count > 0 {
                            compareUpgradeButton
                        }
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
            .sheet(item: $selectedCategory) { category in
                SpecificationCategoryDetailView(category: category)
            }
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
                .foregroundStyle(AVIATheme.aviaWhite)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AVIATheme.primaryGradient)
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
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: AVIATheme.background.opacity(0.4), location: 0.35),
                        .init(color: AVIATheme.background.opacity(0.8), location: 0.65),
                        .init(color: AVIATheme.background, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)
            }
            .overlay(alignment: .bottomLeading) {
                Text("Fittings & Fixtures")
                    .font(.neueCorpMedium(28))
                    .foregroundStyle(AVIATheme.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
            .clipped()
    }

    private var specificationCard: some View {
        BentoCard(cornerRadius: 18) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AVIATheme.timelessBrown.opacity(0.12))
                    Image(systemName: "checkmark.seal.fill")
                        .font(.neueCorpMedium(24))
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
                .frame(width: 68, height: 68)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Specification")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                    Text(specVM.currentTier.displayName)
                        .font(.neueCorpMedium(22))
                        .foregroundStyle(AVIATheme.textPrimary)
                    let totalItems = specVM.categories.reduce(0) { $0 + $1.items.count }
                    Text("\(specVM.categories.count) categories · \(totalItems) inclusions")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                Spacer()
            }
            .padding(18)
        }
    }

    private var compareUpgradeButton: some View {
        NavigationLink {
            SpecRangeComparisonOverviewView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.neueTitle3)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(width: 44, height: 44)
                    .background(AVIATheme.aviaWhite.opacity(0.15))
                    .clipShape(.rect(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Compare & Upgrade Ranges")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.aviaWhite)
                    Text("See what's included in each spec range")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.aviaWhite.opacity(0.7))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.aviaWhite.opacity(0.5))
            }
            .padding(16)
            .background(AVIATheme.primaryGradient)
            .clipShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private var categoriesList: some View {
        VStack(spacing: 0) {
            ForEach(Array(specVM.categories.enumerated()), id: \.element.id) { index, category in
                Button {
                    selectedCategory = category
                } label: {
                    categoryRow(category)
                }
                .buttonStyle(.plain)

                if index < specVM.categories.count - 1 {
                    Divider()
                        .padding(.leading, 62)
                }
            }
        }
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }

    private func categoryRow(_ category: SpecCategory) -> some View {
        let upgradeCount = specVM.upgradeableItems(in: category).count
        let pendingCount = specVM.upgradeRequests.filter { req in
            category.items.contains { $0.id == req.itemId } && req.status == .pending
        }.count

        return HStack(spacing: 14) {
            Image(systemName: category.icon)
                .font(.neueCorpMedium(14))
                .foregroundStyle(AVIATheme.timelessBrown)
                .frame(width: 36, height: 36)
                .background(AVIATheme.timelessBrown.opacity(0.1))
                .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(category.name)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)

                    if pendingCount > 0 {
                        Text("\(pendingCount)")
                            .font(.neueCorpMedium(9))
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .frame(width: 20, height: 20)
                            .background(AVIATheme.warning)
                            .clipShape(Circle())
                    }
                }

                HStack(spacing: 8) {
                    Text("\(category.items.count) items")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)

                    if upgradeCount > 0 {
                        Text("\(upgradeCount) upgradeable")
                            .font(.neueCaption2Medium)
                            .foregroundStyle(AVIATheme.timelessBrown)
                    }
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.neueCaption2Medium)
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
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
                        .foregroundStyle(AVIATheme.timelessBrown)
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
        case .quoted: AVIATheme.timelessBrown
        case .approved: AVIATheme.success
        case .declined: AVIATheme.destructive
        }
    }
}
