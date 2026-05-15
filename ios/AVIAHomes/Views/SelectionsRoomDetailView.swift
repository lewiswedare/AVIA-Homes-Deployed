import SwiftUI

/// Room detail screen — every selectable item in this room. Each card shows
/// the included spec, lets the client request an upgrade, and lets them pick
/// colours/finishes inline.
struct SelectionsRoomDetailView: View {
    @Bindable var viewModel: BuildSpecViewModel
    let room: SelectionRoom
    let buildId: String

    @State private var expandedItemId: String?
    @State private var pendingUpgradeItem: BuildSpecSelection?
    @State private var upgradeNotes: String = ""
    @State private var previewImageURL: IdentifiedURL?

    private func openPreview(_ urlString: String) {
        previewImageURL = IdentifiedURL(urlString: urlString)
    }

    private var catalog: CatalogDataManager { CatalogDataManager.shared }

    private var buildSpecTier: SpecTier {
        SpecTier(rawValue: viewModel.specTier.lowercased()) ?? .messina
    }

    private var items: [BuildSpecSelection] {
        viewModel.selections
            .filter { $0.snapshotCategoryName == room.snapshotCategoryName && $0.selectionType != .removed }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var rangeId: String { viewModel.specTier.lowercased() }

    /// Classify an item by whether — for this room — its variants are
    /// included or only available as an upgrade. If the client has saved a
    /// variant we trust that variant's assignment; otherwise we look at what
    /// the item offers in this room overall.
    private func isItemIncluded(_ sel: BuildSpecSelection) -> Bool {
        guard let roomId = room.categoryId else { return true }
        let cat = CatalogDataManager.shared
        if let cid = sel.colourId,
           let a = cat.assignment(variantId: cid, roomId: roomId, rangeId: rangeId) {
            return a.inclusionValue == .included
        }
        let variantIds = cat.variantIds(forRoom: roomId, rangeId: rangeId)
        let matching = variantIds.compactMap { vid -> VariantRoomAssignmentRow? in
            guard cat.specItemId(forVariantId: vid) == sel.specItemId else { return nil }
            return cat.assignment(variantId: vid, roomId: roomId, rangeId: rangeId)
        }
        if matching.isEmpty { return true }
        return matching.contains { $0.inclusionValue == .included }
    }

    private var includedItems: [BuildSpecSelection] {
        items.filter { isItemIncluded($0) }
    }

    private var upgradeItems: [BuildSpecSelection] {
        items.filter { !isItemIncluded($0) }
    }

    private var upgradeTotal: Double {
        let specCost = items
            .filter { $0.upgradeCost != nil && ($0.selectionType == .upgradeCosted || $0.selectionType == .upgradeAccepted || $0.selectionType == .upgradeApproved) }
            .compactMap(\.upgradeCost).reduce(0, +)
        let itemIds = Set(items.map(\.id))
        let colourCost = viewModel.colourSelections
            .filter { itemIds.contains($0.buildSpecSelectionId ?? "") && $0.isUpgrade && ($0.cost ?? 0) > 0 }
            .compactMap(\.cost).reduce(0, +)
        return specCost + colourCost
    }

    /// Returns the id of the next item after `currentId` that the client still
    /// needs to confirm (no productId saved yet). Wraps to find any earlier
    /// incomplete item; returns nil only when the room is fully picked.
    private func nextIncompleteItemId(after currentId: String) -> String? {
        guard !items.isEmpty,
              let currentIdx = items.firstIndex(where: { $0.id == currentId }) else { return nil }
        let ordered = Array(items[(currentIdx + 1)...]) + Array(items[..<currentIdx])
        return ordered.first(where: { $0.productId == nil && $0.id != currentId })?.id
    }

    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(spacing: 14) {
                    heroHeader
                        .padding(.horizontal, 16)

                    if !includedItems.isEmpty {
                        sectionHeader("INCLUDED", count: includedItems.count, tint: AVIATheme.heritageBlue, icon: "checkmark.seal.fill")
                            .padding(.horizontal, 16)
                        LazyVStack(spacing: 12) {
                            ForEach(includedItems) { item in
                                card(for: item, proxy: proxy)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    if !upgradeItems.isEmpty {
                        sectionHeader("UPGRADES", count: upgradeItems.count, tint: AVIATheme.timelessBrown, icon: "arrow.up.circle.fill")
                            .padding(.horizontal, 16)
                            .padding(.top, 6)
                        LazyVStack(spacing: 12) {
                            ForEach(upgradeItems) { item in
                                card(for: item, proxy: proxy)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Color.clear.frame(height: 24)
                }
                .padding(.top, 6)
            }
        }
        .background(AVIATheme.background)
        .navigationTitle(room.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $pendingUpgradeItem) { item in
            UpgradeRequestSheet(notes: $upgradeNotes) {
                viewModel.requestUpgrade(selectionId: item.id, notes: upgradeNotes.isEmpty ? nil : upgradeNotes)
                AVIAHaptic.success.trigger()
            }
        }
        .fullScreenCover(item: $previewImageURL) { item in
            ZoomableImageViewer(urlString: item.urlString)
        }
    }

    @ViewBuilder
    private func card(for item: BuildSpecSelection, proxy: ScrollViewProxy) -> some View {
        SelectionItemCard(
            viewModel: viewModel,
            selection: item,
            roomId: room.categoryId,
            isExpanded: expandedItemId == item.id,
            onToggle: {
                AVIAHaptic.lightTap.trigger()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    expandedItemId = expandedItemId == item.id ? nil : item.id
                }
            },
            onRequestUpgrade: {
                pendingUpgradeItem = item
                upgradeNotes = item.clientNotes ?? ""
            },
            onPreviewImage: openPreview,
            onConfirmed: {
                let nextId = nextIncompleteItemId(after: item.id)
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    expandedItemId = nextId
                }
                if let nextId {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                            proxy.scrollTo(nextId, anchor: .top)
                        }
                    }
                }
            }
        )
        .id(item.id)
    }

    private func sectionHeader(_ title: String, count: Int, tint: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.neueCorp(11))
                .foregroundStyle(tint)
            Text(title)
                .font(.neueCorpMedium(11))
                .kerning(1.4)
                .foregroundStyle(tint)
            Text("\(count)")
                .font(.neueCorpMedium(10))
                .foregroundStyle(tint)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(tint.opacity(0.12), in: Capsule())
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var heroBannerImage: some View {
        if let urlString = room.heroImageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else if phase.error != nil {
                    Image(room.heroImageName).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color(.secondarySystemBackground)
                }
            }
        } else {
            Image(room.heroImageName).resizable().aspectRatio(contentMode: .fill)
        }
    }

    private var heroHeader: some View {
        Color(.secondarySystemBackground)
            .frame(height: 180)
            .overlay {
                heroBannerImage
                    .allowsHitTesting(false)
            }
            .clipShape(.rect(cornerRadius: 16))
            .overlay {
                LinearGradient(
                    colors: [Color.black.opacity(0.0), Color.black.opacity(0.65)],
                    startPoint: .top, endPoint: .bottom
                )
                .clipShape(.rect(cornerRadius: 16))
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: room.icon)
                            .font(.neueCorp(11))
                        Text(room.displayName.uppercased())
                            .font(.neueCorpMedium(11))
                            .kerning(1.2)
                    }
                    .foregroundStyle(AVIATheme.aviaWhite)

                    Text(room.subtitle)
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.aviaWhite.opacity(0.85))

                    HStack(spacing: 6) {
                        Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                            .font(.neueCorpMedium(10))
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(.ultraThinMaterial, in: Capsule())
                        if upgradeTotal > 0 {
                            Text("UPGRADES \(AVIATheme.formatCost(upgradeTotal))")
                                .font(.neueCorpMedium(9))
                                .kerning(0.8)
                                .foregroundStyle(AVIATheme.aviaWhite)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(AVIATheme.timelessBrown, in: Capsule())
                        }
                    }
                }
                .padding(14)
            }
    }
}

// MARK: - Item card

private struct SelectionItemCard: View {
    @Bindable var viewModel: BuildSpecViewModel
    let selection: BuildSpecSelection
    /// Room context — when set, image + cost are sourced from
    /// `variant_room_assignments` for the active variant.
    var roomId: String? = nil
    let isExpanded: Bool
    let onToggle: () -> Void
    let onRequestUpgrade: () -> Void
    let onPreviewImage: (String) -> Void
    var onConfirmed: () -> Void = {}

    private var catalog: CatalogDataManager { CatalogDataManager.shared }

    private var buildSpecTier: SpecTier {
        SpecTier(rawValue: viewModel.specTier.lowercased()) ?? .messina
    }

    private var linkedSpecItem: SpecItem? {
        catalog.specItem(for: selection.specItemId)
    }

    private var colourCategories: [ColourCategory] {
        let mapping = catalog.activeSpecToColourMapping
        let catIds = mapping[selection.specItemId] ?? []
        let tier = buildSpecTier
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
                applicableTiers: cat.applicableTiers, specItemId: cat.specItemId
            )
        }
    }

    private var colourSelectionsForItem: [BuildColourSelection] {
        viewModel.colourSelections.filter { $0.buildSpecSelectionId == selection.id }
    }

    private var hasColours: Bool { !colourCategories.isEmpty }
    private var allColoursPicked: Bool {
        guard hasColours else { return true }
        return colourCategories.allSatisfy { cat in
            colourSelectionsForItem.contains { $0.colourCategoryId == cat.id }
        }
    }

    private var canRequestUpgrade: Bool {
        guard let item = linkedSpecItem, item.isUpgradeable else { return false }
        return SpecTier.allCases.contains { $0.tierIndex > buildSpecTier.tierIndex && item.upgradeCost(from: buildSpecTier, to: $0) != nil }
    }

    private var upgradeOptions: [(tier: SpecTier, cost: Double)] {
        guard let item = linkedSpecItem else { return [] }
        return SpecTier.allCases
            .filter { $0.tierIndex > buildSpecTier.tierIndex }
            .compactMap { tier in
                guard let cost = item.upgradeCost(from: buildSpecTier, to: tier) else { return nil }
                return (tier: tier, cost: cost)
            }
    }

    private var isFixedInclusion: Bool {
        linkedSpecItem?.isFixedInclusion ?? false
    }

    private var statusInfo: (label: String, color: Color, icon: String) {
        if isFixedInclusion {
            return ("INCLUDED", AVIATheme.heritageBlue, "checkmark.seal.fill")
        }
        switch selection.selectionType {
        case .upgradeDraft: return ("UPGRADE DRAFT", AVIATheme.warning, "pencil.circle.fill")
        case .upgradeRequested: return ("AWAITING QUOTE", AVIATheme.warning, "clock.fill")
        case .upgradeCosted: return ("REVIEW QUOTE", AVIATheme.timelessBrown, "dollarsign.circle.fill")
        case .upgradeAccepted, .upgradeApproved: return ("UPGRADED", AVIATheme.heritageBlue, "arrow.up.circle.fill")
        case .upgradeDeclined: return ("KEPT STANDARD", AVIATheme.textSecondary, "checkmark.circle.fill")
        case .substituted: return ("SUBSTITUTED", AVIATheme.timelessBrown, "arrow.triangle.swap")
        case .included:
            if hasColours && allColoursPicked {
                return ("COMPLETE", AVIATheme.heritageBlue, "checkmark.seal.fill")
            } else if hasColours {
                return ("PICK COLOUR", AVIATheme.timelessBrown, "paintpalette.fill")
            }
            return ("INCLUDED", AVIATheme.textSecondary, "checkmark.circle.fill")
        case .removed: return ("REMOVED", AVIATheme.textTertiary, "xmark.circle.fill")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if isExpanded && !isFixedInclusion {
                expandedContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .background(isFixedInclusion ? AVIATheme.cardBackground.opacity(0.6) : AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
        }
    }

    private var hasImage: Bool { currentImageURL != nil }

    private var currentImageURL: String? {
        // Prefer a room-specific image for the chosen variant when available.
        if let roomId, let cid = selection.colourId,
           let a = catalog.assignment(variantId: cid, roomId: roomId, rangeId: selection.specTier.lowercased()),
           let u = a.image_url, !u.isEmpty {
            return u
        }
        if let s = selection.snapshotImageURL, !s.isEmpty, URL(string: s) != nil { return s }
        if let url = linkedSpecItem?.imageURL { return url.absoluteString }
        return nil
    }

    private var header: some View {
        Group {
            if isFixedInclusion {
                headerContent
            } else {
                Button(action: onToggle) {
                    headerContent
                }
                .buttonStyle(.pressable(.subtle))
            }
        }
    }

    private var headerContent: some View {
        HStack(alignment: .top, spacing: 12) {
            if hasImage {
                itemThumbnail
                    .frame(width: 56, height: 56)
                    .clipShape(.rect(cornerRadius: 10))
                    .onTapGesture {
                        if let urlStr = currentImageURL {
                            AVIAHaptic.lightTap.trigger()
                            onPreviewImage(urlStr)
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(selection.snapshotName)
                    .font(.neueCorpMedium(15))
                    .foregroundStyle(AVIATheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                Text(selection.snapshotDescription)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    Label(statusInfo.label, systemImage: statusInfo.icon)
                        .font(.neueCorpMedium(8))
                        .kerning(0.8)
                        .foregroundStyle(statusInfo.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusInfo.color.opacity(0.12), in: Capsule())

                    if !isFixedInclusion, let cost = selection.upgradeCost, cost > 0 {
                        Text("+\(AVIATheme.formatCost(cost))")
                            .font(.neueCorpMedium(9))
                            .foregroundStyle(AVIATheme.timelessBrown)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AVIATheme.timelessBrown.opacity(0.1), in: Capsule())
                    }
                }
            }

            Spacer(minLength: 0)

            if !isFixedInclusion {
                Image(systemName: "chevron.down")
                    .font(.neueCorp(11))
                    .foregroundStyle(AVIATheme.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
        }
        .padding(14)
        .contentShape(Rectangle())
    }

    private var itemThumbnail: some View {
        Group {
            if let urlStr = currentImageURL, let url = URL(string: urlStr) {
                Color(.secondarySystemBackground)
                    .overlay {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                placeholderIcon
                            }
                        }
                        .allowsHitTesting(false)
                    }
            } else if let url = selection.snapshotImageURL.flatMap(URL.init(string:)) {
                Color(.secondarySystemBackground)
                    .overlay {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                placeholderIcon
                            }
                        }
                        .allowsHitTesting(false)
                    }
            } else if let url = linkedSpecItem?.imageURL {
                Color(.secondarySystemBackground)
                    .overlay {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                placeholderIcon
                            }
                        }
                        .allowsHitTesting(false)
                    }
            }
        }
    }

    private var comingSoonPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.neueCorp(20))
                .foregroundStyle(AVIATheme.timelessBrown)
            Text("Options coming soon")
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.textPrimary)
            Text("AVIA is finalising product choices for this item. You'll be able to pick here once they're loaded.")
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(AVIATheme.background.opacity(0.5))
        .clipShape(.rect(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: "photo")
            .font(.neueCorp(16))
            .foregroundStyle(AVIATheme.textTertiary)
    }

    private var rangeProducts: [(product: SpecProductRow, membership: SpecRangeItemProductRow)] {
        catalog.products(for: selection.specItemId, rangeId: buildSpecTier.rawValue)
    }

    private var hasProducts: Bool { !rangeProducts.isEmpty }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider().background(AVIATheme.surfaceBorder)

            if hasProducts {
                SelectionProductPickerView(
                    viewModel: viewModel,
                    selection: selection,
                    products: rangeProducts,
                    roomId: roomId,
                    onConfirmed: onConfirmed
                )
            } else if hasColours || canRequestUpgrade {
                tierSection
                if hasColours {
                    Divider().background(AVIATheme.surfaceBorder)
                    coloursSection
                }
            } else {
                comingSoonPlaceholder
            }
        }
        .padding(14)
    }

    // MARK: Tier section

    private var tierSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STEP 1 — CHOOSE YOUR FINISH")
                .font(.neueCorpMedium(9))
                .kerning(1.2)
                .foregroundStyle(AVIATheme.timelessBrown)

            standardTile

            if canRequestUpgrade {
                ForEach(upgradeOptions, id: \.tier.id) { upgrade in
                    upgradeTile(tier: upgrade.tier, cost: upgrade.cost)
                }
            }

            if let cost = selection.upgradeCost, selection.selectionType == .upgradeCosted {
                quotedActions(cost: cost)
            }
        }
    }

    private var standardTile: some View {
        let isSelected = selection.selectionType == .included || selection.selectionType == .upgradeDeclined
        return Button {
            // No-op for now — included is the default; cancelling an upgrade
            // requires the existing draft removal flow.
            if selection.selectionType == .upgradeDraft {
                AVIAHaptic.lightTap.trigger()
                viewModel.removeUpgradeDraft(selectionId: selection.id)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.neueCorp(16))
                    .foregroundStyle(isSelected ? AVIATheme.timelessBrown : AVIATheme.textTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Included — \(buildSpecTier.displayName)")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("STANDARD")
                            .font(.neueCorpMedium(7))
                            .kerning(0.8)
                            .foregroundStyle(AVIATheme.heritageBlue)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(AVIATheme.heritageBlue.opacity(0.15), in: Capsule())
                    }
                    if let item = linkedSpecItem {
                        Text(item.description(for: buildSpecTier))
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                Text("$0")
                    .font(.neueCorpMedium(11))
                    .foregroundStyle(AVIATheme.textSecondary)
            }
            .padding(12)
            .background(isSelected ? AVIATheme.cardBackgroundAlt : AVIATheme.background.opacity(0.5))
            .clipShape(.rect(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? AVIATheme.timelessBrown.opacity(0.4) : AVIATheme.surfaceBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.pressable(.subtle))
    }

    private func upgradeTile(tier: SpecTier, cost: Double) -> some View {
        let isUpgradePending = selection.selectionType == .upgradeDraft || selection.selectionType == .upgradeRequested
        let isUpgradeApproved = selection.selectionType == .upgradeApproved || selection.selectionType == .upgradeAccepted

        return Button {
            guard !isUpgradePending && !isUpgradeApproved else { return }
            AVIAHaptic.mediumTap.trigger()
            onRequestUpgrade()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isUpgradePending || isUpgradeApproved ? "largecircle.fill.circle" : "circle")
                    .font(.neueCorp(16))
                    .foregroundStyle(isUpgradePending || isUpgradeApproved ? AVIATheme.timelessBrown : AVIATheme.textTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Upgrade to \(tier.displayName)")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("PREMIUM")
                            .font(.neueCorpMedium(7))
                            .kerning(0.8)
                            .foregroundStyle(AVIATheme.timelessBrown)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(AVIATheme.timelessBrown.opacity(0.12), in: Capsule())
                    }
                    if let item = linkedSpecItem {
                        Text(item.description(for: tier))
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .lineLimit(2)
                    }
                    if isUpgradePending {
                        Text("Awaiting AVIA quote")
                            .font(.neueCorpMedium(8))
                            .kerning(0.8)
                            .foregroundStyle(AVIATheme.warning)
                    }
                }

                Spacer(minLength: 0)

                Text("+\(AVIATheme.formatCost(cost))")
                    .font(.neueCorpMedium(11))
                    .foregroundStyle(AVIATheme.timelessBrown)
            }
            .padding(12)
            .background((isUpgradePending || isUpgradeApproved) ? AVIATheme.timelessBrown.opacity(0.06) : AVIATheme.background.opacity(0.5))
            .clipShape(.rect(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke((isUpgradePending || isUpgradeApproved) ? AVIATheme.timelessBrown.opacity(0.5) : AVIATheme.surfaceBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.pressable(.subtle))
        .disabled(isUpgradeApproved)
    }

    private func quotedActions(cost: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Final quote: \(AVIATheme.formatCost(cost))")
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.timelessBrown)

            HStack(spacing: 10) {
                Button {
                    AVIAHaptic.success.trigger()
                    viewModel.clientAcceptUpgrade(selectionId: selection.id)
                } label: {
                    Text("Accept Upgrade")
                        .font(.neueCaptionMedium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(.rect(cornerRadius: 9))
                }
                .buttonStyle(.pressable(.standard))

                Button {
                    AVIAHaptic.lightTap.trigger()
                    viewModel.clientDeclineUpgrade(selectionId: selection.id)
                } label: {
                    Text("Keep Standard")
                        .font(.neueCaptionMedium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(AVIATheme.textPrimary)
                        .background(AVIATheme.surfaceElevated)
                        .clipShape(.rect(cornerRadius: 9))
                }
                .buttonStyle(.pressable(.subtle))
            }
        }
        .padding(12)
        .background(AVIATheme.timelessBrown.opacity(0.05))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: Colours section

    private var coloursSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STEP 2 — CHOOSE YOUR COLOUR")
                .font(.neueCorpMedium(9))
                .kerning(1.2)
                .foregroundStyle(AVIATheme.timelessBrown)

            ForEach(colourCategories) { category in
                colourCategoryGroup(category)
            }
        }
    }

    private func colourCategoryGroup(_ category: ColourCategory) -> some View {
        let existing = colourSelectionsForItem.first { $0.colourCategoryId == category.id }
        let tier = buildSpecTier
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.neueCorp(11))
                    .foregroundStyle(AVIATheme.timelessBrown)
                Text(category.name)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
                if existing != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.neueCorp(12))
                        .foregroundStyle(AVIATheme.heritageBlue)
                }
            }
            if let note = category.note {
                Text(note)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(category.options) { option in
                    let isSelected = existing?.colourOptionId == option.id
                    let isOptionUpgrade = option.isUpgradeOption(for: tier)
                    let hasUpgradeCost = (option.cost ?? 0) > 0
                    ColourSwatchView(
                        option: option,
                        isSelected: isSelected,
                        isTierUpgrade: isOptionUpgrade
                    ) {
                        AVIAHaptic.lightTap.trigger()
                        Task {
                            await viewModel.saveColourSelection(
                                buildSpecSelectionId: selection.id,
                                specItemId: selection.specItemId,
                                colourCategoryId: category.id,
                                colourOptionId: option.id,
                                cost: option.cost,
                                isUpgrade: isOptionUpgrade || hasUpgradeCost
                            )
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(AVIATheme.background.opacity(0.5))
        .clipShape(.rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10).stroke(AVIATheme.surfaceBorder, lineWidth: 1)
        }
    }
}
