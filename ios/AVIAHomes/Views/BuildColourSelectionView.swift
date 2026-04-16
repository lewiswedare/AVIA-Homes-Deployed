import SwiftUI

struct BuildColourSelectionView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var viewModel = BuildSpecViewModel()
    @State private var selectedSpecItem: BuildSpecSelection?
    let buildId: String

    private var catalog: CatalogDataManager { CatalogDataManager.shared }

    private var buildSpecTier: SpecTier {
        SpecTier(rawValue: viewModel.specTier.lowercased()) ?? .messina
    }

    private var approvedItemsNeedingColour: [BuildSpecSelection] {
        let mapping = catalog.activeSpecToColourMapping
        let tier = buildSpecTier
        return viewModel.approvedItems.filter { sel in
            guard let catIds = mapping[sel.specItemId] else { return false }
            let hasVisibleCategories = catIds.contains { catId in
                guard let cat = catalog.allColourCategories.first(where: { $0.id == catId }) else { return false }
                return cat.isAvailable(for: tier)
            }
            return hasVisibleCategories
        }
    }

    private var groupedItems: [(category: String, items: [BuildSpecSelection])] {
        let grouped = Dictionary(grouping: approvedItemsNeedingColour) { $0.snapshotCategoryName }
        let order = [
            "External Finishes", "Windows & Doors", "Kitchen",
            "Bathroom & Ensuite", "Flooring", "Internal Finishes",
            "Electrical & Lighting", "Outdoor & Landscaping"
        ]
        return order.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (category: cat, items: items.sorted { $0.sortOrder < $1.sortOrder })
        }
    }

    private var completedCount: Int {
        approvedItemsNeedingColour.filter { sel in
            viewModel.colourSelections.contains { $0.buildSpecSelectionId == sel.id }
        }.count
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView().tint(AVIATheme.teal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.overallStatus != .approved {
                specNotApprovedState
            } else if approvedItemsNeedingColour.isEmpty {
                emptyState
            } else {
                colourContent
            }
        }
        .background(AVIATheme.background)
        .navigationTitle("Colour Selections")
        .navigationBarTitleDisplayMode(.large)
        .task {
            viewModel.notificationService = appViewModel.notificationService
            viewModel.clientId = appViewModel.currentUser.id
            viewModel.adminRecipientIds = appViewModel.allRegisteredUsers.filter { $0.role.isAnyStaffRole }.map(\.id)
            await viewModel.load(buildId: buildId)
        }
        .sheet(item: $selectedSpecItem) { specItem in
            BuildColourPickerSheet(
                specItem: specItem,
                specTier: viewModel.specTier,
                existingSelection: viewModel.colourSelections.first { $0.buildSpecSelectionId == specItem.id },
                onSelect: { colourCatId, colourOptId, cost, isUpgrade in
                    Task {
                        await viewModel.saveColourSelection(
                            buildSpecSelectionId: specItem.id,
                            specItemId: specItem.specItemId,
                            colourCategoryId: colourCatId,
                            colourOptionId: colourOptId,
                            cost: cost,
                            isUpgrade: isUpgrade
                        )
                    }
                }
            )
        }
    }

    private var colourUpgradeTotal: Double {
        viewModel.colourSelections
            .filter { $0.isUpgrade && $0.cost != nil }
            .compactMap(\.cost)
            .reduce(0, +)
    }

    private var colourContent: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 16) {
                    progressCard
                    tierInfoBanner

                    ForEach(groupedItems, id: \.category) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.category.uppercased())
                                .font(.neueCaption2Medium)
                                .kerning(1.0)
                                .foregroundStyle(AVIATheme.textTertiary)
                                .padding(.horizontal, 4)

                            ForEach(group.items) { item in
                                colourItemCard(item)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, colourUpgradeTotal > 0 ? 80 : 40)
            }

            if colourUpgradeTotal > 0 {
                upgradeTotalBar
            }
        }
    }

    private var upgradeTotalBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "tag.fill")
                .font(.neueCaptionMedium)
                .foregroundStyle(.white.opacity(0.8))
            Text("Colour Upgrades")
                .font(.neueCaptionMedium)
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            Text(AVIATheme.formatCost(colourUpgradeTotal))
                .font(.neueCorpMedium(18))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(AVIATheme.aviaBlack)
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 10, y: -2)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4), value: colourUpgradeTotal)
    }

    private var progressCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Colour Progress")
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Text("\(completedCount) of \(approvedItemsNeedingColour.count) selected")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textSecondary)
            }
            Spacer()
            let progress = approvedItemsNeedingColour.isEmpty ? 0 : Double(completedCount) / Double(approvedItemsNeedingColour.count)
            ZStack {
                Circle()
                    .stroke(AVIATheme.teal.opacity(0.15), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(AVIATheme.teal, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(progress * 100))%")
                    .font(.neueCorpMedium(11))
                    .foregroundStyle(AVIATheme.teal)
            }
            .frame(width: 44, height: 44)
        }
        .padding(14)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 14))
    }

    private var tierInfoBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "paintpalette.fill")
                .foregroundStyle(AVIATheme.teal)
            Text("Showing colour options for your approved **\(viewModel.specTier.capitalized)** specification items only.")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AVIATheme.teal.opacity(0.06))
        .clipShape(.rect(cornerRadius: 12))
    }

    private func colourItemCard(_ item: BuildSpecSelection) -> some View {
        let colourSel = viewModel.colourSelections.first { $0.buildSpecSelectionId == item.id }
        let tier = buildSpecTier
        let mapping = catalog.activeSpecToColourMapping
        let colourCatIds = mapping[item.specItemId] ?? []
        let matchedColourCats = catalog.allColourCategories.filter { colourCatIds.contains($0.id) && $0.isAvailable(for: tier) }

        return Button {
            selectedSpecItem = item
        } label: {
            HStack(spacing: 12) {
                if let colourSel, let cat = matchedColourCats.first(where: { $0.id == colourSel.colourCategoryId }),
                   let opt = cat.options.first(where: { $0.id == colourSel.colourOptionId }) {
                    if let imgURL = opt.imageURL, !imgURL.isEmpty {
                        Color(.secondarySystemBackground)
                            .frame(width: 44, height: 44)
                            .overlay {
                                AsyncImage(url: URL(string: imgURL)) { phase in
                                    if let image = phase.image {
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    }
                                }
                                .allowsHitTesting(false)
                            }
                            .clipShape(.rect(cornerRadius: 8))
                    } else {
                        Circle()
                            .fill(Color(hex: opt.hexColor))
                            .frame(width: 36, height: 36)
                            .overlay { Circle().stroke(AVIATheme.surfaceBorder, lineWidth: 1) }
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AVIATheme.surfaceElevated)
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "paintpalette")
                                .font(.neueCorp(14))
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.snapshotName)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)

                    if let colourSel, let cat = matchedColourCats.first(where: { $0.id == colourSel.colourCategoryId }),
                       let opt = cat.options.first(where: { $0.id == colourSel.colourOptionId }) {
                        HStack(spacing: 6) {
                            Text(opt.name)
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.success)
                            if colourSel.isUpgrade, let cost = colourSel.cost, cost > 0 {
                                Text(AVIATheme.formatCost(cost))
                                    .font(.neueCorpMedium(9))
                                    .foregroundStyle(AVIATheme.warning)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(AVIATheme.warning.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    } else {
                        Text("Tap to select colour")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                }

                Spacer()

                Image(systemName: colourSel != nil ? "checkmark.circle.fill" : "chevron.right")
                    .font(.system(size: 18))
                    .foregroundStyle(colourSel != nil ? AVIATheme.success : AVIATheme.textTertiary)
            }
            .padding(12)
            .background(AVIATheme.cardBackground)
            .clipShape(.rect(cornerRadius: 14))
            .overlay {
                if colourSel != nil {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AVIATheme.success.opacity(0.2), lineWidth: 1)
                }
            }
        }
    }

    private var specNotApprovedState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(AVIATheme.warning)
            Text("Specifications Not Yet Approved")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)
            Text("Colour selections will be available once your Admin has approved your specification range.")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "paintpalette")
                .font(.system(size: 44))
                .foregroundStyle(AVIATheme.textTertiary)
            Text("No Colour Selections Needed")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)
            Text("None of your approved specification items require colour selections.")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension BuildSpecSelection: Hashable {
    nonisolated static func == (lhs: BuildSpecSelection, rhs: BuildSpecSelection) -> Bool {
        lhs.id == rhs.id
    }
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct BuildColourPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let specItem: BuildSpecSelection
    let specTier: String
    let existingSelection: BuildColourSelection?
    let onSelect: (String, String, Double?, Bool) -> Void

    private var catalog: CatalogDataManager { CatalogDataManager.shared }

    private var resolvedTier: SpecTier {
        SpecTier(rawValue: specTier.lowercased()) ?? .messina
    }

    private var linkedSpecItem: SpecItem? {
        catalog.specItem(for: specItem.specItemId)
    }

    private var colourCategories: [ColourCategory] {
        let mapping = catalog.activeSpecToColourMapping
        let catIds = mapping[specItem.specItemId] ?? []
        let tier = resolvedTier
        return catIds.compactMap { catId in
            guard let cat = catalog.allColourCategories.first(where: { $0.id == catId }) else { return nil }
            guard cat.isAvailable(for: tier) else { return nil }
            let filteredOptions = cat.options.filter { opt in
                let tierOk = opt.applicableTiers == nil || opt.applicableTiers!.isEmpty || opt.applicableTiers!.contains(tier.rawValue)
                let availOk = opt.availableTiers.isEmpty || opt.isAvailable(for: tier) || opt.isUpgradeOption(for: tier)
                return tierOk && availOk
            }
            guard !filteredOptions.isEmpty else { return nil }
            return ColourCategory(
                id: cat.id, name: cat.name, icon: cat.icon,
                section: cat.section, options: filteredOptions,
                note: cat.note, imageURL: cat.imageURL,
                applicableTiers: cat.applicableTiers,
                specItemId: cat.specItemId
            )
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "cube.box.fill")
                                .foregroundStyle(AVIATheme.teal)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(specItem.snapshotName)
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text(specItem.snapshotDescription)
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textSecondary)
                                    .lineLimit(2)
                            }
                        }

                        if let specItemModel = linkedSpecItem {
                            let tierDesc = specItemModel.description(for: resolvedTier)
                            if !tierDesc.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundStyle(AVIATheme.teal.opacity(0.7))
                                        .font(.system(size: 12))
                                    Text("Your \(resolvedTier.displayName) spec: \(tierDesc)")
                                        .font(.neueCaption2)
                                        .foregroundStyle(AVIATheme.textSecondary)
                                }
                                .padding(10)
                                .background(AVIATheme.teal.opacity(0.06))
                                .clipShape(.rect(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(14)
                    .background(AVIATheme.cardBackground)
                    .clipShape(.rect(cornerRadius: 14))

                    if colourCategories.isEmpty {
                        Text("No colour options available for this item.")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textTertiary)
                            .padding(.horizontal, 4)
                    }

                    ForEach(colourCategories) { cat in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(cat.name)
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textPrimary)

                            if let note = cat.note {
                                Text(note)
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                            }

                            let tier = resolvedTier
                            let columns = [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ]

                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(cat.options) { option in
                                    let isSelected = existingSelection?.colourOptionId == option.id && existingSelection?.colourCategoryId == cat.id
                                    let isOptionUpgrade = option.isUpgradeOption(for: tier)
                                    let hasUpgradeCost = (option.cost ?? 0) > 0
                                    ColourSwatchView(
                                        option: option,
                                        isSelected: isSelected,
                                        isTierUpgrade: isOptionUpgrade
                                    ) {
                                        onSelect(cat.id, option.id, option.cost, isOptionUpgrade || hasUpgradeCost)
                                        dismiss()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(AVIATheme.background)
            .navigationTitle("Select Colour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(AVIATheme.teal)
                }
            }
        }
        .presentationDetents([.large])
    }
}
