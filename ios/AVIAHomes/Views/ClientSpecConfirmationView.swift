import SwiftUI

struct ClientSpecConfirmationView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var viewModel = BuildSpecViewModel()
    @State private var showConfirmAlert = false
    @State private var upgradeSelectionId: String?
    @State private var upgradeNotes = ""
    @State private var fullRangePricing: [UpgradePricing] = []
    let buildId: String

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .tint(AVIATheme.timelessBrown)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.hasSelections {
                emptyState
            } else {
                specContent
            }
        }
        .background(AVIATheme.background)
        .navigationTitle("My Specifications")
        .navigationBarTitleDisplayMode(.large)
        .task {
            viewModel.notificationService = appViewModel.notificationService
            viewModel.clientId = appViewModel.currentUser.id
            viewModel.clientName = appViewModel.currentUser.fullName
            viewModel.adminRecipientIds = appViewModel.allRegisteredUsers.filter { $0.role.isAnyStaffRole }.map(\.id)
            if let build = appViewModel.allClientBuilds.first(where: { $0.id == buildId }) {
                let lot = build.lotNumber.isEmpty ? "" : "Lot \(build.lotNumber)"
                let estate = build.estate
                let combined = [lot, estate].filter { !$0.isEmpty }.joined(separator: ", ")
                viewModel.buildAddress = combined.isEmpty ? build.homeDesign : combined
            }
            async let specLoad: Void = viewModel.load(buildId: buildId)

            let storeyType: String
            if let build = appViewModel.allClientBuilds.first(where: { $0.id == buildId }) {
                let storeys = build.customStoreys ?? appViewModel.allHomeDesigns.first(where: { $0.name.lowercased() == build.homeDesign.lowercased() })?.storeys ?? 1
                storeyType = storeys >= 2 ? "double" : "single"
            } else {
                storeyType = "single"
            }

            async let pricingLoad = SupabaseService.shared.fetchFullRangeUpgradePricing(storeyType: storeyType)
            _ = await specLoad
            fullRangePricing = await pricingLoad
        }
        .alert("Confirm Specifications", isPresented: $showConfirmAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Submit") {
                Task { await viewModel.submitClientConfirmation() }
            }
        } message: {
            Text("Once submitted, your specifications will be locked for admin review. You won't be able to make changes until an admin reopens them.")
        }
        .sheet(item: $upgradeSelectionId) { selId in
            UpgradeRequestSheet(notes: $upgradeNotes) {
                viewModel.requestUpgrade(selectionId: selId, notes: upgradeNotes.isEmpty ? nil : upgradeNotes)
                upgradeNotes = ""
                upgradeSelectionId = nil
            }
        }
        .overlay(alignment: .bottom) { toastOverlay }
    }

    private var specContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                clientActionNeededCard
                statusBanner
                tierInfoBanner
                upgradeDraftBasketCard
                specRangeUpgradeCard
                upgradeQuotesAwaitingResponseCard

                ForEach(viewModel.groupedSelections, id: \.categoryId) { group in
                    BuildSpecCategorySection(
                        categoryName: group.category,
                        items: group.items,
                        isEditable: !viewModel.isLockedForClient,
                        isAdmin: false,
                        onUpgradeRequest: { id in
                            upgradeSelectionId = id
                        },
                        onAcceptUpgrade: { id in
                            viewModel.clientAcceptUpgrade(selectionId: id)
                        },
                        onDeclineUpgrade: { id in
                            viewModel.clientDeclineUpgrade(selectionId: id)
                        }
                    )
                }

                if !viewModel.isLockedForClient && viewModel.hasSelections {
                    confirmButton
                }

                if viewModel.isFullyApproved && !viewModel.documents.isEmpty {
                    pdfSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .hapticRefresh { await appViewModel.refreshAllData() }
    }

    /// Loud, top-of-page summary of what the client must do next. Shown when
    /// there are quoted upgrades awaiting response, or when an admin has
    /// reopened/amended their selections.
    @ViewBuilder
    private var clientActionNeededCard: some View {
        let quoted = viewModel.selections.filter { $0.selectionType == .upgradeCosted }.count
        let rangeAwaitingClient = viewModel.rangeUpgradeRequests.filter { $0.status == .pendingClient }.count
        let reopenedOrAmended = (viewModel.overallStatus == .reopenedByAdmin || viewModel.overallStatus == .amendedByAdmin)
        let total = quoted + rangeAwaitingClient + (reopenedOrAmended ? 1 : 0)

        if total > 0 {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "bell.badge.fill")
                        .font(.neueCorpMedium(20))
                        .foregroundStyle(AVIATheme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Action required")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("Your AVIA team is waiting on your response.")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    Spacer()
                    if quoted + rangeAwaitingClient > 0 {
                        Text("\(quoted + rangeAwaitingClient)")
                            .font(.neueCorpMedium(16))
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .frame(minWidth: 28, minHeight: 28)
                            .padding(.horizontal, 6)
                            .background(AVIATheme.accent)
                            .clipShape(Capsule())
                    }
                }

                VStack(spacing: 6) {
                    if quoted > 0 {
                        clientActionRow(icon: "dollarsign.circle.fill",
                                        text: "\(quoted) upgrade quote\(quoted == 1 ? "" : "s") ready for your response",
                                        color: AVIATheme.accent)
                    }
                    if rangeAwaitingClient > 0 {
                        clientActionRow(icon: "arrow.up.forward.circle.fill",
                                        text: "\(rangeAwaitingClient) spec range upgrade awaiting your confirmation",
                                        color: AVIATheme.timelessBrown)
                    }
                    if reopenedOrAmended {
                        clientActionRow(icon: "arrow.uturn.backward.circle.fill",
                                        text: viewModel.overallStatus == .amendedByAdmin
                                            ? "Your admin made amendments \u2014 review and resubmit"
                                            : "Your specs were reopened \u2014 review and resubmit",
                                        color: AVIATheme.heritageBlue)
                    }
                }
            }
            .padding(14)
            .background(AVIATheme.accent.opacity(0.08))
            .clipShape(.rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AVIATheme.accent.opacity(0.35), lineWidth: 1)
            }
        }
    }

    private func clientActionRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.neueCorp(12))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12))
                .clipShape(Circle())
            Text(text)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textPrimary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
        }
        .padding(10)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 10))
    }

    private var statusBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.overallStatus.icon)
                .font(.neueSubheadlineMedium)
                .foregroundStyle(statusColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Text(statusSubtitle)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textSecondary)
            }

            Spacer()

            Text(viewModel.overallStatus.displayLabel)
                .font(.neueCorpMedium(9))
                .foregroundStyle(AVIATheme.aviaWhite)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(statusColor)
                .clipShape(Capsule())
        }
        .padding(14)
        .background(statusColor.opacity(0.06))
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(statusColor.opacity(0.2), lineWidth: 1)
        }
    }

    private var statusColor: Color {
        switch viewModel.overallStatus {
        case .draft, .clientReviewing: AVIATheme.timelessBrown
        case .awaitingAdmin: AVIATheme.warning
        case .awaitingClient: AVIATheme.accent
        case .reopenedByAdmin: AVIATheme.heritageBlue
        case .approved: AVIATheme.success
        case .amendedByAdmin: AVIATheme.heritageBlue
        }
    }

    private var statusTitle: String {
        switch viewModel.overallStatus {
        case .draft, .clientReviewing: "Review Your Specifications"
        case .awaitingAdmin: "Submitted — Awaiting Review"
        case .awaitingClient: "Upgrade Cost Available"
        case .reopenedByAdmin: "Reopened for Changes"
        case .approved: "Specifications Approved"
        case .amendedByAdmin: "Amended by Admin"
        }
    }

    private var statusSubtitle: String {
        switch viewModel.overallStatus {
        case .draft, .clientReviewing:
            "Review each item below and confirm when ready."
        case .awaitingAdmin:
            "Your selections have been submitted and are awaiting admin review."
        case .awaitingClient:
            "An upgrade cost has been provided. Review and accept or decline below."
        case .reopenedByAdmin:
            "An admin has reopened your specifications for changes. Review and resubmit."
        case .approved:
            "Both you and admin have confirmed. Your spec range is finalised."
        case .amendedByAdmin:
            "An admin has made changes to your specifications."
        }
    }

    @ViewBuilder
    private var upgradeDraftBasketCard: some View {
        let drafts = viewModel.upgradeDraftItems
        if !drafts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "tray.full.fill")
                        .font(.neueCorpMedium(18))
                        .foregroundStyle(AVIATheme.timelessBrown)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("My Upgrade Requests")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("\(drafts.count) draft\(drafts.count == 1 ? "" : "s") ready to submit")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    Spacer()
                }

                ForEach(drafts, id: \.id) { item in
                    draftUpgradeRow(item)
                }

                Button {
                    AVIAHaptic.success.trigger()
                    Task { await viewModel.submitAllUpgradeRequests() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "paperplane.fill")
                        Text("Submit \(drafts.count) Upgrade Request\(drafts.count == 1 ? "" : "s")")
                    }
                    .font(.neueSubheadlineMedium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .background(AVIATheme.primaryGradient)
                    .clipShape(.rect(cornerRadius: 12))
                }
                .buttonStyle(.pressable(.prominent))
                .disabled(viewModel.isSaving)
            }
            .padding(14)
            .background(AVIATheme.cardBackground)
            .clipShape(.rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AVIATheme.timelessBrown.opacity(0.25), lineWidth: 1)
            }
        }
    }

    private func draftUpgradeRow(_ item: BuildSpecSelection) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.snapshotName)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Text(item.snapshotCategoryName)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                if let notes = item.clientNotes, !notes.isEmpty {
                    Text(notes)
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Button {
                AVIAHaptic.lightTap.trigger()
                viewModel.removeUpgradeDraft(selectionId: item.id)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle")
                        .font(.neueCorp(10))
                    Text("Remove")
                        .font(.neueCaption2Medium)
                }
                .foregroundStyle(AVIATheme.destructive)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AVIATheme.destructive.opacity(0.1))
                .clipShape(Capsule())
            }
            .buttonStyle(.pressable(.subtle))
            .disabled(viewModel.isSaving)
        }
        .padding(12)
        .background(AVIATheme.timelessBrown.opacity(0.04))
        .clipShape(.rect(cornerRadius: 10))
    }

    @ViewBuilder
    private var upgradeQuotesAwaitingResponseCard: some View {
        let quoted = viewModel.selections.filter { $0.selectionType == .upgradeCosted }
        if !quoted.isEmpty {
            let total = quoted.compactMap(\.upgradeCost).reduce(0, +)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.neueCorpMedium(18))
                        .foregroundStyle(AVIATheme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Upgrade Quotes Ready")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("\(quoted.count) upgrade\(quoted.count == 1 ? "" : "s") awaiting your response")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    Spacer()
                    Text(formatCurrency(total))
                        .font(.neueCorpMedium(18))
                        .foregroundStyle(AVIATheme.accent)
                }

                ForEach(quoted, id: \.id) { item in
                    quotedUpgradeRow(item)
                }
            }
            .padding(14)
            .background(AVIATheme.cardBackground)
            .clipShape(.rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AVIATheme.accent.opacity(0.25), lineWidth: 1)
            }
        }
    }

    private func quotedUpgradeRow(_ item: BuildSpecSelection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.snapshotName)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text(item.snapshotCategoryName)
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                    if let note = item.upgradeCostNote, !note.isEmpty {
                        Text(note)
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Text(formatCurrency(item.upgradeCost ?? 0))
                    .font(.neueCorpMedium(16))
                    .foregroundStyle(AVIATheme.timelessBrown)
            }

            HStack(spacing: 8) {
                Button {
                    viewModel.clientAcceptUpgrade(selectionId: item.id)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.neueCorp(10))
                        Text("Approve")
                            .font(.neueCaption2Medium)
                    }
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(AVIATheme.success)
                    .clipShape(Capsule())
                }

                Button {
                    viewModel.clientDeclineUpgrade(selectionId: item.id)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle")
                            .font(.neueCorp(10))
                        Text("Decline")
                            .font(.neueCaption2Medium)
                    }
                    .foregroundStyle(AVIATheme.destructive)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(AVIATheme.destructive.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(12)
        .background(AVIATheme.accent.opacity(0.04))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var tierInfoBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(AVIATheme.timelessBrown)
            Text("**\(viewModel.specTier.capitalized)** specification range")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AVIATheme.timelessBrown.opacity(0.06))
        .clipShape(.rect(cornerRadius: 12))
    }

    @ViewBuilder
    private var specRangeUpgradeCard: some View {
        let currentTier = SpecTier(rawValue: viewModel.specTier.lowercased()) ?? .volos
        let availableUpgrades = fullRangePricing.filter { pricing in
            guard pricing.isActive,
                  let from = pricing.fromTier,
                  let to = pricing.toTier,
                  let fromTier = SpecTier(rawValue: from),
                  let toTier = SpecTier(rawValue: to),
                  fromTier == currentTier,
                  toTier.tierIndex > currentTier.tierIndex
            else { return false }
            return true
        }

        if let pending = viewModel.pendingRangeUpgrade {
            pendingRangeUpgradeCard(pending)
        } else if !availableUpgrades.isEmpty {
            BentoCard(cornerRadius: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.up.forward.circle.fill")
                            .font(.neueCorpMedium(18))
                            .foregroundStyle(AVIATheme.timelessBrown)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Upgrade Your Entire Spec Range")
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Text("Upgrade everything at once with package pricing, or upgrade individual items below.")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textSecondary)
                                .lineLimit(2)
                        }
                    }

                    ForEach(availableUpgrades, id: \.id) { pricing in
                        if let toTier = pricing.toTier, let tier = SpecTier(rawValue: toTier) {
                            Button {
                                viewModel.clientRequestRangeUpgrade(toTier: toTier, cost: pricing.cost, notes: nil)
                                viewModel.clientAcceptRangeUpgrade(requestId: viewModel.pendingRangeUpgrade?.id ?? "")
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: tier.icon)
                                        .font(.neueCorp(12))
                                        .foregroundStyle(tierColor(tier))
                                        .frame(width: 28, height: 28)
                                        .background(tierColor(tier).opacity(0.12))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Upgrade to \(tier.displayName)")
                                            .font(.neueCaptionMedium)
                                            .foregroundStyle(AVIATheme.textPrimary)
                                        Text(tier.tagline)
                                            .font(.neueCaption2)
                                            .foregroundStyle(AVIATheme.textTertiary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(formatCurrency(pricing.cost))
                                            .font(.neueCorpMedium(16))
                                            .foregroundStyle(AVIATheme.timelessBrown)
                                        Text("Tap to request")
                                            .font(.neueCaption2)
                                            .foregroundStyle(AVIATheme.textTertiary)
                                    }
                                }
                                .padding(12)
                                .background(tierColor(tier).opacity(0.04))
                                .clipShape(.rect(cornerRadius: 10))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(tierColor(tier).opacity(0.15), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.pressable(.subtle))
                        }
                    }
                }
                .padding(14)
            }
        }
    }

    @ViewBuilder
    private func pendingRangeUpgradeCard(_ request: BuildRangeUpgradeRequest) -> some View {
        let toTier = SpecTier(rawValue: request.toTier.lowercased()) ?? .messina
        BentoCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: request.status == .clientAccepted ? "clock.fill" : "arrow.up.forward.circle.fill")
                        .font(.neueCorpMedium(18))
                        .foregroundStyle(request.status == .clientAccepted ? AVIATheme.warning : AVIATheme.timelessBrown)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Upgrade to \(toTier.displayName)")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text(request.status.displayLabel)
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    Spacer()
                    Text(formatCurrency(request.cost))
                        .font(.neueCorpMedium(18))
                        .foregroundStyle(AVIATheme.timelessBrown)
                }

                if request.status == .pendingClient {
                    HStack(spacing: 10) {
                        Button {
                            viewModel.clientAcceptRangeUpgrade(requestId: request.id)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Confirm Upgrade")
                            }
                            .font(.neueCaption2Medium)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .background(AVIATheme.success)
                            .clipShape(Capsule())
                        }

                        Button {
                            viewModel.clientDeclineRangeUpgrade(requestId: request.id)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle")
                                Text("Reject")
                            }
                            .font(.neueCaption2Medium)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .foregroundStyle(AVIATheme.destructive)
                            .background(AVIATheme.destructive.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                } else if request.status == .clientAccepted {
                    HStack(spacing: 6) {
                        Image(systemName: "hourglass")
                            .font(.neueCorp(10))
                        Text("Awaiting admin approval to apply this upgrade.")
                            .font(.neueCaption2)
                    }
                    .foregroundStyle(AVIATheme.warning)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AVIATheme.warning.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 10))
                }
            }
            .padding(14)
        }
    }

    private func tierColor(_ tier: SpecTier) -> Color {
        switch tier {
        case .volos: AVIATheme.timelessBrown
        case .messina: AVIATheme.warning
        case .portobello: AVIATheme.heritageBlue
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "$%.0f", value)
    }

    private var confirmButton: some View {
        Button {
            showConfirmAlert = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                Text("Confirm Specifications")
            }
            .font(.neueSubheadlineMedium)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(AVIATheme.aviaWhite)
            .background(AVIATheme.primaryGradient)
            .clipShape(.rect(cornerRadius: 14))
        }
        .disabled(viewModel.isSaving)
    }

    @ViewBuilder
    private var pdfSection: some View {
        if let latestDoc = viewModel.documents.first {
            BentoCard(cornerRadius: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(AVIATheme.timelessBrown)
                        Text("Specification Document")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Spacer()
                        Text("v\(latestDoc.version)")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }

                    if let urlString = latestDoc.publicURL, let url = URL(string: urlString) {
                        Link(destination: url) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.doc.fill")
                                Text("View PDF")
                            }
                            .font(.neueCaption2Medium)
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(AVIATheme.primaryGradient)
                            .clipShape(Capsule())
                        }
                    }

                    if let date = latestDoc.generatedAt {
                        Text("Generated \(date.formatted(date: .abbreviated, time: .shortened))")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                }
                .padding(14)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(AVIATheme.textTertiary)
            Text("No Specifications Yet")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)
            Text("Your build specifications will appear here once your build has been set up.")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let msg = viewModel.successMessage {
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
                        withAnimation { viewModel.successMessage = nil }
                    }
                }
        }
        if let msg = viewModel.errorMessage {
            Text(msg)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.aviaWhite)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(AVIATheme.destructive, in: Capsule())
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { viewModel.errorMessage = nil }
                    }
                }
        }
    }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}

struct UpgradeRequestSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var notes: String
    let onSubmit: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Request Upgrade")
                        .font(.neueCorpMedium(20))
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Add any notes about this upgrade request. Our team will review and provide a quote.")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }

                TextField("Optional notes...", text: $notes, axis: .vertical)
                    .font(.neueCaption)
                    .lineLimit(4...8)
                    .padding(12)
                    .background(AVIATheme.surfaceElevated)
                    .clipShape(.rect(cornerRadius: 10))

                Button {
                    onSubmit()
                    dismiss()
                } label: {
                    Text("Submit Request")
                        .font(.neueSubheadlineMedium)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(.rect(cornerRadius: 12))
                }

                Spacer()
            }
            .padding(20)
            .background(AVIATheme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
