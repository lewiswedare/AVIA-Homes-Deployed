import SwiftUI

struct SpecificationsOverviewView: View {
    @Environment(SpecificationViewModel.self) private var specVM
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(CustomerJourneyViewModel.self) private var journeyVM
    @State private var showConfirmAlert = false
    @State private var selectedCategory: SpecCategory?
    @State private var selectedUpgradeRequest: UpgradeRequest?
    @State private var requestToRemove: UpgradeRequest?
    @State private var submitToast: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroImage

                    VStack(spacing: 14) {
                        currentTierHeader
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
            .sheet(item: $selectedUpgradeRequest) { request in
                UpgradeResponseSheet(request: request) {
                    specVM.clientAcceptUpgradeCost(requestId: request.id)
                    selectedUpgradeRequest = nil
                } onDecline: {
                    specVM.clientDeclineUpgradeCost(requestId: request.id)
                    selectedUpgradeRequest = nil
                }
            }
            .alert("Remove Upgrade Request?", isPresented: .init(
                get: { requestToRemove != nil },
                set: { if !$0 { requestToRemove = nil } }
            )) {
                Button("Cancel", role: .cancel) { requestToRemove = nil }
                Button("Remove", role: .destructive) {
                    if let req = requestToRemove {
                        specVM.removeUpgradeRequest(requestId: req.id)
                    }
                    requestToRemove = nil
                }
            } message: {
                if let req = requestToRemove {
                    Text("Remove the upgrade request for \(req.itemName)? You can add it again later.")
                }
            }
            .overlay(alignment: .bottom) {
                if let msg = submitToast {
                    Text(msg)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(AVIATheme.success, in: Capsule())
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                withAnimation { submitToast = nil }
                            }
                        }
                }
            }
            .task {
                specVM.notificationService = appViewModel.notificationService
                specVM.clientId = appViewModel.currentUser.id
                specVM.clientName = appViewModel.currentUser.fullName
                specVM.adminRecipientIds = appViewModel.allRegisteredUsers.filter { $0.role.isAnyStaffRole }.map(\.id)
                if let build = appViewModel.clientBuildsForCurrentUser.first {
                    let lot = build.lotNumber.isEmpty ? "" : "Lot \(build.lotNumber)"
                    let estate = build.estate
                    let combined = [lot, estate].filter { !$0.isEmpty }.joined(separator: ", ")
                    specVM.buildAddress = combined.isEmpty ? build.homeDesign : combined
                }
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

    private var draftUpgradeCount: Int {
        specVM.upgradeRequests.filter { $0.status == .pending }.count
    }

    private var confirmSpecsSection: some View {
        VStack(spacing: 10) {
            if draftUpgradeCount > 0 {
                Button {
                    Task {
                        await specVM.submitAllUpgradeRequests()
                        if let msg = specVM.submitMessage {
                            withAnimation { submitToast = msg }
                            specVM.submitMessage = nil
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if specVM.isSubmittingRequests {
                            ProgressView()
                                .tint(AVIATheme.aviaWhite)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.neueSubheadlineMedium)
                        }
                        Text("Request \(draftUpgradeCount) Upgrade\(draftUpgradeCount == 1 ? "" : "s")")
                            .font(.neueSubheadlineMedium)
                    }
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AVIATheme.primaryGradient)
                    .clipShape(.rect(cornerRadius: 14))
                }
                .disabled(specVM.isSubmittingRequests)
                .sensoryFeedback(.success, trigger: specVM.submitMessage)
            } else {
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
                .sensoryFeedback(.impact(flexibility: .soft), trigger: showConfirmAlert)
            }
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
                            .foregroundStyle(AVIATheme.aviaWhite.opacity(0.8))
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
                                .foregroundStyle(AVIATheme.aviaWhite.opacity(0.7))
                            Text(specVM.currentTier.displayName)
                                .font(.neueCorpMedium(24))
                                .foregroundStyle(AVIATheme.aviaWhite)
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
                                .foregroundStyle(AVIATheme.aviaWhite)
                            Text("Categories")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.aviaWhite.opacity(0.6))
                        }

                        Rectangle()
                            .fill(AVIATheme.aviaWhite.opacity(0.15))
                            .frame(width: 1, height: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            let totalItems = specVM.categories.reduce(0) { $0 + $1.items.count }
                            Text("\(totalItems)")
                                .font(.neueCorpMedium(20))
                                .foregroundStyle(AVIATheme.aviaWhite)
                            Text("Inclusions")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.aviaWhite.opacity(0.6))
                        }

                        Rectangle()
                            .fill(AVIATheme.aviaWhite.opacity(0.15))
                            .frame(width: 1, height: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(specVM.upgradeRequests.count)")
                                .font(.neueCorpMedium(20))
                                .foregroundStyle(AVIATheme.aviaWhite)
                            Text("Upgrades")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.aviaWhite.opacity(0.6))
                        }

                        Spacer()
                    }
                }
                .padding(20)
            }

            if specVM.upgradeTiers.count > 0 {
                Rectangle()
                    .fill(AVIATheme.aviaWhite.opacity(0.15))
                    .frame(height: 1)
                    .padding(.horizontal, 16)

                NavigationLink {
                    SpecRangeComparisonOverviewView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Compare & Upgrade Ranges")
                            .font(.neueSubheadlineMedium)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AVIATheme.aviaWhite.opacity(0.5))
                    }
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .padding(16)
                }
            }
        }
        .background(AVIATheme.timelessBrown)
        .clipShape(.rect(cornerRadius: 20))
    }

    private var categoriesList: some View {
        VStack(spacing: 0) {
            ForEach(Array(specVM.categories.enumerated()), id: \.element.id) { index, category in
                Button {
                    selectedCategory = category
                } label: {
                    categoryRow(category)
                }
                .buttonStyle(.pressable(.subtle))

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
        .contentShape(Rectangle())
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
                Button {
                    if request.status == .quoted {
                        selectedUpgradeRequest = request
                    } else if request.status == .pending {
                        requestToRemove = request
                    }
                } label: {
                    upgradeRequestRow(request)
                        .opacity(request.status == .submitted ? 0.5 : 1)
                }
                .buttonStyle(.pressable(.subtle))
                .disabled(request.status != .quoted && request.status != .pending)
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
                    Text("Draft")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle")
                            .font(.neueCaption2)
                        Text("Tap to remove")
                            .font(.neueCaption2Medium)
                    }
                    .foregroundStyle(AVIATheme.destructive)
                }
            }

            if request.status == .submitted {
                HStack(spacing: 6) {
                    Image(systemName: "hourglass")
                        .font(.neueCaption2)
                    Text("Awaiting admin review")
                        .font(.neueCaption2Medium)
                    Spacer()
                }
                .foregroundStyle(AVIATheme.textTertiary)
                .padding(.top, 2)
            }

            if request.status == .quoted {
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .font(.neueCaption2)
                    Text("Tap to approve or decline")
                        .font(.neueCaption2Medium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.neueCaption2)
                }
                .foregroundStyle(AVIATheme.timelessBrown)
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            if request.status == .quoted {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AVIATheme.timelessBrown.opacity(0.3), lineWidth: 1)
            }
        }
    }

    private func upgradeStatusColor(_ status: UpgradeStatus) -> Color {
        switch status {
        case .pending: AVIATheme.warning
        case .submitted: AVIATheme.textTertiary
        case .quoted: AVIATheme.timelessBrown
        case .approved: AVIATheme.success
        case .declined: AVIATheme.destructive
        }
    }
}
