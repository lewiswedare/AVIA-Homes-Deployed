import SwiftUI

struct AdminUpgradeQuoteView: View {
    let buildId: String
    let clientName: String
    let selections: [BuildSpecSelection]
    let colourSelections: [BuildColourSelection]
    var onUpdateCost: (String, Double?, String?) -> Void

    @State private var costOverrides: [String: String] = [:]
    @State private var costNotes: [String: String] = [:]

    private var catalog: CatalogDataManager { CatalogDataManager.shared }

    private var upgradeItems: [BuildSpecSelection] {
        selections.filter {
            $0.selectionType == .upgradeRequested ||
            $0.selectionType == .upgradeCosted ||
            $0.selectionType == .upgradeAccepted ||
            $0.selectionType == .upgradeApproved
        }
    }

    private func autoCost(for item: BuildSpecSelection) -> Double? {
        let specItems = catalog.allSpecCategories.flatMap(\.items)
        guard let specItem = specItems.first(where: { $0.id == item.specItemId }) else { return nil }

        guard let fromTier = SpecTier(rawValue: item.specTier) else { return nil }

        for toTier in SpecTier.allCases where toTier.tierIndex > fromTier.tierIndex {
            if let cost = specItem.upgradeCost(from: fromTier, to: toTier) {
                return cost
            }
        }
        return nil
    }

    private func effectiveCost(for item: BuildSpecSelection) -> Double? {
        if let override = costOverrides[item.id], let val = Double(override) {
            return val
        }
        if let existing = item.upgradeCost {
            return existing
        }
        return autoCost(for: item)
    }

    private var subtotal: Double {
        upgradeItems.compactMap { effectiveCost(for: $0) }.reduce(0, +)
    }

    private var colourUpgradeCost: Double {
        colourSelections.filter(\.isUpgrade).compactMap(\.cost).reduce(0, +)
    }

    private var grandTotal: Double {
        subtotal + colourUpgradeCost
    }

    var body: some View {
        VStack(spacing: 16) {
            headerCard

            if upgradeItems.isEmpty && colourSelections.filter(\.isUpgrade).isEmpty {
                AdminEmptyState(
                    icon: "arrow.up.circle",
                    title: "No Upgrades",
                    subtitle: "No upgrade requests for this build"
                )
            } else {
                if !upgradeItems.isEmpty {
                    specUpgradeSection
                }

                if !colourSelections.filter(\.isUpgrade).isEmpty {
                    colourUpgradeSection
                }

                totalSection
                saveAllButton
            }
        }
        .onAppear { populateOverrides() }
    }

    private var headerCard: some View {
        BentoCard(cornerRadius: 16) {
            HStack(spacing: 14) {
                Image(systemName: "doc.text.fill")
                    .font(.neueCorpMedium(18))
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(width: 44, height: 44)
                    .background(AVIATheme.primaryGradient)
                    .clipShape(.rect(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Upgrade Quote for \(clientName)")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Review auto-calculated costs and adjust before confirming")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(16)
        }
    }

    private var specUpgradeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SPEC UPGRADES")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)

            ForEach(upgradeItems, id: \.id) { item in
                quoteLineItem(item)
            }
        }
    }

    private func quoteLineItem(_ item: BuildSpecSelection) -> some View {
        BentoCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.snapshotName)
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("\(item.snapshotCategoryName) \u{2022} \(item.specTier.capitalized)")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }

                    Spacer()

                    selectionTypePill(item.selectionType)
                }

                if let auto = autoCost(for: item) {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.neueCorp(9))
                        Text("Auto-calculated: \(formatAUD(auto))")
                            .font(.neueCaption2)
                    }
                    .foregroundStyle(AVIATheme.timelessBrown)
                }

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cost (AUD)")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                        HStack(spacing: 4) {
                            Text("$")
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textSecondary)
                            TextField("0.00", text: bindOverride(item.id))
                                .keyboardType(.decimalPad)
                                .font(.neueCaption)
                        }
                        .padding(10)
                        .background(AVIATheme.surfaceElevated)
                        .clipShape(.rect(cornerRadius: 8))
                        .frame(width: 120)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Note")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                        TextField("Cost note...", text: bindNote(item.id))
                            .font(.neueCaption)
                            .padding(10)
                            .background(AVIATheme.surfaceElevated)
                            .clipShape(.rect(cornerRadius: 8))
                    }
                }
            }
            .padding(14)
        }
    }

    @ViewBuilder
    private func selectionTypePill(_ type: SelectionType) -> some View {
        let (label, color): (String, Color) = switch type {
        case .upgradeRequested: ("REQUESTED", AVIATheme.warning)
        case .upgradeCosted: ("COSTED", AVIATheme.accent)
        case .upgradeAccepted: ("ACCEPTED", AVIATheme.heritageBlue)
        case .upgradeApproved: ("APPROVED", AVIATheme.success)
        default: ("", AVIATheme.textTertiary)
        }
        if !label.isEmpty {
            Text(label)
                .font(.neueCorpMedium(7))
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private var colourUpgradeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COLOUR UPGRADES")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)

            let upgradeColours = colourSelections.filter(\.isUpgrade)
            BentoCard(cornerRadius: 14) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Text("Option")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Category")
                            .frame(width: 80, alignment: .center)
                        Text("Cost")
                            .frame(width: 70, alignment: .trailing)
                    }
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.textTertiary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AVIATheme.surfaceElevated.opacity(0.5))

                    ForEach(Array(upgradeColours.enumerated()), id: \.element.id) { index, cs in
                        let resolved = resolveColour(cs)
                        HStack(spacing: 0) {
                            HStack(spacing: 8) {
                                if let hex = resolved?.hex {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 20, height: 20)
                                        .overlay { Circle().stroke(AVIATheme.surfaceBorder, lineWidth: 1) }
                                }
                                Text(resolved?.optName ?? cs.colourOptionId)
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text(resolved?.catName ?? cs.colourCategoryId)
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textSecondary)
                                .lineLimit(1)
                                .frame(width: 80, alignment: .center)

                            Text(cs.cost.map { formatAUD($0) } ?? "-")
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                                .frame(width: 70, alignment: .trailing)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                        if index < upgradeColours.count - 1 {
                            Rectangle()
                                .fill(AVIATheme.surfaceBorder)
                                .frame(height: 1)
                                .padding(.leading, 14)
                        }
                    }
                }
            }
        }
    }

    private var totalSection: some View {
        BentoCard(cornerRadius: 14) {
            VStack(spacing: 10) {
                HStack {
                    Text("Spec Upgrades Subtotal")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textSecondary)
                    Spacer()
                    Text(formatAUD(subtotal))
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                }

                if colourUpgradeCost > 0 {
                    HStack {
                        Text("Colour Upgrades Subtotal")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textSecondary)
                        Spacer()
                        Text(formatAUD(colourUpgradeCost))
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                    }
                }

                Rectangle()
                    .fill(AVIATheme.surfaceBorder)
                    .frame(height: 1)

                HStack {
                    Text("Total Upgrade Cost")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Spacer()
                    Text(formatAUD(grandTotal))
                        .font(.neueCorpMedium(20))
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }
            .padding(16)
        }
    }

    private var saveAllButton: some View {
        Button {
            saveAllCosts()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Set Costs & Send to Client")
            }
            .font(.neueSubheadlineMedium)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(AVIATheme.aviaWhite)
            .background(AVIATheme.primaryGradient)
            .clipShape(.rect(cornerRadius: 14))
        }
    }

    private func populateOverrides() {
        for item in upgradeItems {
            if let cost = item.upgradeCost {
                costOverrides[item.id] = String(format: "%.2f", cost)
            } else if let auto = autoCost(for: item) {
                costOverrides[item.id] = String(format: "%.2f", auto)
            }
            costNotes[item.id] = item.upgradeCostNote ?? ""
        }
    }

    private func saveAllCosts() {
        for item in upgradeItems {
            let cost = Double(costOverrides[item.id] ?? "")
            let note = costNotes[item.id]
            onUpdateCost(item.id, cost, note?.isEmpty == true ? nil : note)
        }
    }

    private func bindOverride(_ id: String) -> Binding<String> {
        Binding(
            get: { costOverrides[id] ?? "" },
            set: { costOverrides[id] = $0 }
        )
    }

    private func bindNote(_ id: String) -> Binding<String> {
        Binding(
            get: { costNotes[id] ?? "" },
            set: { costNotes[id] = $0 }
        )
    }

    private func resolveColour(_ cs: BuildColourSelection) -> (catName: String, optName: String, hex: String)? {
        guard let cat = catalog.allColourCategories.first(where: { $0.id == cs.colourCategoryId }) else { return nil }
        guard let opt = cat.options.first(where: { $0.id == cs.colourOptionId }) else { return nil }
        return (catName: cat.name, optName: opt.name, hex: opt.hexColor)
    }

    private func formatAUD(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }
}
