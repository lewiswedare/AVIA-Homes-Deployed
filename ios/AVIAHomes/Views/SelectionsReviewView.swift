import SwiftUI

/// Review-and-submit sheet — checklist of every selection grouped by room,
/// total upgrade cost, and a single submit button that pushes upgrade
/// requests + colour selections to the AVIA team for quoting/approval.
struct SelectionsReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: BuildSpecViewModel
    @State private var isSubmitting = false

    private var catalog: CatalogDataManager { CatalogDataManager.shared }

    private var groupedByRoom: [(room: SelectionRoom, items: [BuildSpecSelection])] {
        let grouped = Dictionary(grouping: viewModel.selections.filter { $0.selectionType != .removed }) {
            SelectionRoom.from(snapshotCategoryName: $0.snapshotCategoryName)
        }
        return SelectionRoom.displayOrder.compactMap { room in
            guard let items = grouped[room], !items.isEmpty else { return nil }
            return (room: room, items: items.sorted { $0.sortOrder < $1.sortOrder })
        }
    }

    private var pendingDraftCount: Int {
        viewModel.upgradeDraftItems.count + viewModel.draftColourSelections.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
                    breakdownCard
                    ForEach(groupedByRoom, id: \.room.id) { entry in
                        roomSection(room: entry.room, items: entry.items)
                    }
                }
                .padding(16)
            }
            .background(AVIATheme.background)
            .navigationTitle("Review Selections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .tint(AVIATheme.timelessBrown)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if pendingDraftCount > 0 {
                    submitBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                }
            }
        }
    }

    private var breakdownCard: some View {
        let breakdown = viewModel.upgradeBreakdown
        return Group {
            if breakdown.total > 0 {
                BentoCard(cornerRadius: 14) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("UPGRADE BREAKDOWN")
                                .font(.neueCorpMedium(9))
                                .kerning(1.2)
                                .foregroundStyle(AVIATheme.timelessBrown)
                            Spacer()
                            Text(AVIATheme.formatCost(breakdown.total))
                                .font(.neueCorpMedium(13))
                                .foregroundStyle(AVIATheme.textPrimary)
                        }

                        VStack(spacing: 8) {
                            breakdownRow(label: "Spec range upgrades", icon: "arrow.up.circle.fill", colour: AVIATheme.heritageBlue, amount: breakdown.specRange)
                            breakdownRow(label: "Product upgrades", icon: "shippingbox.fill", colour: AVIATheme.timelessBrown, amount: breakdown.product)
                            breakdownRow(label: "Colour extras", icon: "paintpalette.fill", colour: AVIATheme.warning, amount: breakdown.colour)
                        }

                        if !breakdown.lineItems.isEmpty {
                            Divider().background(AVIATheme.surfaceBorder)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("LINE ITEMS")
                                    .font(.neueCorpMedium(9))
                                    .kerning(1.2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                                ForEach(breakdown.lineItems) { line in
                                    HStack(alignment: .top, spacing: 10) {
                                        Circle()
                                            .fill(kindColor(line.kind).opacity(0.15))
                                            .frame(width: 22, height: 22)
                                            .overlay {
                                                Image(systemName: kindIcon(line.kind))
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundStyle(kindColor(line.kind))
                                            }
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(line.name)
                                                .font(.neueCaption2Medium)
                                                .foregroundStyle(AVIATheme.textPrimary)
                                                .lineLimit(1)
                                            Text(line.detail)
                                                .font(.neueCaption2)
                                                .foregroundStyle(AVIATheme.textTertiary)
                                                .lineLimit(1)
                                        }
                                        Spacer(minLength: 0)
                                        Text("+\(AVIATheme.formatCost(line.amount))")
                                            .font(.neueCorpMedium(11))
                                            .foregroundStyle(AVIATheme.textPrimary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private func breakdownRow(label: String, icon: String, colour: Color, amount: Double) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(colour)
                .frame(width: 22)
            Text(label)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
            Spacer()
            Text(amount > 0 ? AVIATheme.formatCost(amount) : "—")
                .font(.neueCorpMedium(12))
                .foregroundStyle(amount > 0 ? AVIATheme.textPrimary : AVIATheme.textTertiary)
        }
    }

    private func kindIcon(_ kind: BuildSpecViewModel.UpgradeBreakdown.LineItem.Kind) -> String {
        switch kind {
        case .specRange: "arrow.up.circle.fill"
        case .product: "shippingbox.fill"
        case .colour: "paintpalette.fill"
        }
    }

    private func kindColor(_ kind: BuildSpecViewModel.UpgradeBreakdown.LineItem.Kind) -> Color {
        switch kind {
        case .specRange: AVIATheme.heritageBlue
        case .product: AVIATheme.timelessBrown
        case .colour: AVIATheme.warning
        }
    }

    private var summaryCard: some View {
        BentoCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text("SUMMARY")
                    .font(.neueCorpMedium(9))
                    .kerning(1.2)
                    .foregroundStyle(AVIATheme.timelessBrown)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total upgrades")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                        Text(viewModel.totalUpgradeCost > 0 ? AVIATheme.formatCost(viewModel.totalUpgradeCost) : "$0")
                            .font(.neueCorpMedium(22))
                            .foregroundStyle(AVIATheme.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("To submit")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                        Text("\(pendingDraftCount)")
                            .font(.neueCorpMedium(22))
                            .foregroundStyle(pendingDraftCount > 0 ? AVIATheme.timelessBrown : AVIATheme.textSecondary)
                    }
                }
                if pendingDraftCount > 0 {
                    Text("You have \(pendingDraftCount) pending change\(pendingDraftCount == 1 ? "" : "s") ready to send to AVIA. Submit when you're ready.")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
            }
            .padding(16)
        }
    }

    private func roomSection(room: SelectionRoom, items: [BuildSpecSelection]) -> some View {
        BentoCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: room.icon)
                        .font(.neueCorp(11))
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text(room.displayName.uppercased())
                        .font(.neueCorpMedium(10))
                        .kerning(1.2)
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
                ForEach(items) { item in
                    rowFor(item)
                    if item.id != items.last?.id {
                        Divider().background(AVIATheme.surfaceBorder)
                    }
                }
            }
            .padding(14)
        }
    }

    private func rowFor(_ item: BuildSpecSelection) -> some View {
        let colour = viewModel.colourSelections.first { $0.buildSpecSelectionId == item.id }
        let resolvedColour: (name: String, hex: String)? = {
            guard let c = colour,
                  let cat = catalog.allColourCategories.first(where: { $0.id == c.colourCategoryId }),
                  let opt = cat.options.first(where: { $0.id == c.colourOptionId }) else { return nil }
            return (opt.name, opt.hexColor)
        }()

        return HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.snapshotName)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Text(tierLabel(for: item))
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textSecondary)
                if let resolvedColour {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: resolvedColour.hex))
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(AVIATheme.surfaceBorder, lineWidth: 0.5))
                        Text(resolvedColour.name)
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                if let cost = item.upgradeCost, cost > 0 {
                    Text("+\(AVIATheme.formatCost(cost))")
                        .font(.neueCorpMedium(11))
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
                Text(statusLabel(for: item, colour: colour))
                    .font(.neueCorpMedium(8))
                    .kerning(0.8)
                    .foregroundStyle(statusColor(for: item, colour: colour))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(statusColor(for: item, colour: colour).opacity(0.12), in: Capsule())
            }
        }
    }

    private func tierLabel(for item: BuildSpecSelection) -> String {
        switch item.selectionType {
        case .upgradeDraft: "Draft upgrade"
        case .upgradeRequested: "Upgrade requested"
        case .upgradeCosted: "Quoted upgrade"
        case .upgradeAccepted, .upgradeApproved: "Upgraded"
        case .upgradeDeclined, .included: "Included"
        case .substituted: "Substituted"
        case .removed: "Removed"
        }
    }

    private func statusLabel(for item: BuildSpecSelection, colour: BuildColourSelection?) -> String {
        if item.selectionType == .upgradeDraft { return "DRAFT" }
        if item.selectionType == .upgradeRequested { return "AWAITING QUOTE" }
        if item.selectionType == .upgradeCosted { return "REVIEW QUOTE" }
        if item.selectionType == .upgradeApproved || item.selectionType == .upgradeAccepted { return "UPGRADED" }
        if let c = colour {
            switch c.selectionStatus {
            case .draft: return "COLOUR DRAFT"
            case .submitted: return "SUBMITTED"
            case .approved: return "APPROVED"
            case .reopened: return "REOPENED"
            case .upgradeRequested: return "UPGRADE REQ"
            case .upgradePendingClient: return "REVIEW QUOTE"
            case .upgradeAcceptedByClient: return "AWAITING ADMIN"
            case .upgradeDeclinedByClient: return "DECLINED"
            }
        }
        return "INCLUDED"
    }

    private func statusColor(for item: BuildSpecSelection, colour: BuildColourSelection?) -> Color {
        if item.selectionType == .upgradeDraft { return AVIATheme.warning }
        if item.selectionType == .upgradeRequested || item.selectionType == .upgradeCosted { return AVIATheme.warning }
        if item.selectionType == .upgradeApproved || item.selectionType == .upgradeAccepted { return AVIATheme.heritageBlue }
        if let c = colour, c.selectionStatus == .draft { return AVIATheme.warning }
        if let c = colour, c.selectionStatus == .approved { return AVIATheme.heritageBlue }
        return AVIATheme.textSecondary
    }

    private var submitBar: some View {
        Button {
            AVIAHaptic.success.trigger()
            isSubmitting = true
            Task {
                if !viewModel.upgradeDraftItems.isEmpty {
                    await viewModel.submitAllUpgradeRequests()
                }
                if !viewModel.draftColourSelections.isEmpty {
                    await viewModel.submitColourSelectionsForApproval()
                }
                isSubmitting = false
                dismiss()
            }
        } label: {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView().tint(AVIATheme.aviaWhite)
                } else {
                    Image(systemName: "paperplane.fill")
                }
                Text(isSubmitting ? "Submitting…" : "Submit \(pendingDraftCount) Selection\(pendingDraftCount == 1 ? "" : "s")")
            }
            .font(.neueSubheadlineMedium)
            .foregroundStyle(AVIATheme.aviaWhite)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(AVIATheme.primaryGradient)
            .clipShape(.rect(cornerRadius: 12))
            .shadow(color: AVIATheme.timelessBrown.opacity(0.25), radius: 12, y: 6)
        }
        .disabled(isSubmitting)
        .buttonStyle(.pressable(.prominent))
    }
}
