import SwiftUI

/// Product-driven picker shown inside a Spec Item card. Replaces the legacy
/// tier-upgrade + colour-swatch flow when the spec item has products configured
/// for the current range. Hierarchy: Range -> Item -> Product -> Colour.
///
/// Flow: the client expands a product to stage it, taps a colour swatch to
/// stage that, then taps **Confirm** to actually persist the selection. Only
/// confirming will lock the choice in and trigger `onConfirmed`, which the
/// parent uses to advance to the next item.
struct SelectionProductPickerView: View {
    @Bindable var viewModel: BuildSpecViewModel
    let selection: BuildSpecSelection
    /// Products available in the build's current range (already filtered to
    /// exclude Unavailable). Sorted by sort_order.
    let products: [(product: SpecProductRow, membership: SpecRangeItemProductRow)]
    /// Room context. When set, the picker filters variants to those assigned to
    /// this room and prefers the room-specific image + cost from
    /// `variant_room_assignments` over the product/colour defaults.
    var roomId: String? = nil
    /// Facade scope. When the build has a selected facade, variant lookups
    /// prefer facade-specific assignment rows and hide variants only scoped
    /// to a different facade.
    var facadeId: String? = nil
    /// Called after the client taps Confirm and the selection is saved. The
    /// parent can use this to scroll to / expand the next incomplete item.
    var onConfirmed: () -> Void = {}

    @State private var stagedProductId: String?
    @State private var stagedColourId: String?
    @State private var isSaving: Bool = false
    @State private var previewImageURL: IdentifiedURL?

    private var catalog: CatalogDataManager { CatalogDataManager.shared }

    private var rangeId: String { selection.specTier.lowercased() }

    /// True when the spec item has at least one variant_room_assignment row
    /// somewhere. When true we trust the assignment table to decide which
    /// variants/products belong in which room; when false we fall back to the
    /// legacy behaviour of showing every product/colour for the item so
    /// un-migrated items don't silently disappear.
    private var hasAnyAssignments: Bool {
        catalog.hasAnyRoomAssignment(forSpecItem: selection.specItemId)
    }

    /// Returns the room-specific assignment for a variant when we have a room
    /// context, otherwise nil. Drives image + cost overrides.
    private func assignment(for variantId: String) -> VariantRoomAssignmentRow? {
        guard let roomId else { return nil }
        return catalog.assignment(variantId: variantId, roomId: roomId, rangeId: rangeId, facadeId: facadeId)
    }

    /// Variants for a product, filtered to those assigned to the active room.
    /// When the spec item has any assignments at all, the room scope is
    /// authoritative — only variants assigned to this room are shown. Only
    /// fully un-migrated items (no assignments anywhere) fall back to all
    /// colours so they don't silently disappear during rollout.
    private func roomScopedColours(for productId: String) -> [SpecProductColourRow] {
        let all = catalog.productColours(for: productId)
        guard roomId != nil else { return all }
        let filtered = all.filter { assignment(for: $0.id) != nil }
        if !filtered.isEmpty { return filtered }
        return hasAnyAssignments ? [] : all
    }

    /// Products filtered to those that have at least one variant assigned to
    /// the active room. Mirrors `roomScopedColours` — when the item has any
    /// assignments we strictly scope, otherwise we fall back to every product
    /// for the item so legacy items keep working.
    private var roomScopedProducts: [(product: SpecProductRow, membership: SpecRangeItemProductRow)] {
        guard roomId != nil else { return products }
        let filtered = products.filter { entry in
            !roomScopedColours(for: entry.product.id).isEmpty
        }
        if !filtered.isEmpty { return filtered }
        return hasAnyAssignments ? [] : products
    }

    private var savedIsUpgrade: Bool {
        guard let pid = selection.productId,
              let m = catalog.rangeProductMemberships["\(selection.specTier.lowercased())|\(pid)"] else { return false }
        return (m.inclusion_override ?? "") == "upgrade" || (m.upgrade_price_override ?? 0) > 0
    }

    private var savedColourHasExtra: Bool {
        guard let pid = selection.productId, let cid = selection.colourId,
              let colour = catalog.coloursByProduct[pid]?.first(where: { $0.id == cid }) else { return false }
        return (colour.extra_cost ?? 0) > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("CHOOSE A PRODUCT")
                    .font(.neueCorpMedium(9))
                    .kerning(1.2)
                    .foregroundStyle(AVIATheme.timelessBrown)
                Spacer()
                if selection.productId != nil && (savedIsUpgrade || savedColourHasExtra) {
                    Button {
                        AVIAHaptic.lightTap.trigger()
                        resetToDefault()
                    } label: {
                        Label("Remove upgrade", systemImage: "arrow.uturn.backward")
                            .font(.neueCorpMedium(9))
                            .kerning(0.8)
                            .foregroundStyle(AVIATheme.timelessBrown)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(AVIATheme.timelessBrown.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.pressable(.subtle))
                }
            }

            let visibleProducts = roomScopedProducts
            if visibleProducts.isEmpty {
                Text("No products assigned to this room yet.")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(visibleProducts, id: \.product.id) { entry in
                        productCard(product: entry.product, membership: entry.membership)
                    }
                }
            }
        }
        .onAppear { syncStagedFromSaved() }
        .onChange(of: selection.id) { _, _ in syncStagedFromSaved() }
        .fullScreenCover(item: $previewImageURL) { item in
            ZoomableImageViewer(urlString: item.urlString)
        }
    }

    private func syncStagedFromSaved() {
        stagedProductId = selection.productId
        stagedColourId = selection.colourId
    }

    /// Clears the client's product + colour choice for this spec item, so
    /// it goes back to "not yet selected" (no upgrade applied).
    private func resetToDefault() {
        Task {
            await viewModel.clearProductSelection(selectionId: selection.id)
            await MainActor.run {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    stagedProductId = nil
                    stagedColourId = nil
                }
            }
        }
    }

    // MARK: - Product card

    @ViewBuilder
    private func productCard(product: SpecProductRow, membership: SpecRangeItemProductRow) -> some View {
        let inclusion = ProductRangeInclusion(rawValue: membership.inclusion_override ?? "included") ?? .included
        let isSaved = selection.productId == product.id
        let isStaged = stagedProductId == product.id
        let colours = roomScopedColours(for: product.id)
        // When a colour variant with its own image is staged (or saved) for
        // this product, prefer that image as the hero thumbnail so clients
        // can preview the actual variant they've chosen.
        let activeColourId: String? = isStaged ? stagedColourId : (isSaved ? selection.colourId : nil)
        let activeColourImageURL: String? = {
            guard let cid = activeColourId else { return nil }
            // Prefer the room-specific assignment image when we have one.
            if let urlStr = assignment(for: cid)?.image_url, !urlStr.isEmpty {
                return urlStr
            }
            guard let colour = colours.first(where: { $0.id == cid }),
                  let urlStr = colour.image_url, !urlStr.isEmpty else { return nil }
            return urlStr
        }()
        let heroImageURL: String? = activeColourImageURL ?? product.image_url
        let isExpanded = isStaged
        let upgradeCost = membership.upgrade_price_override ?? 0
        let needsColour = !colours.isEmpty
        let stagedColourValid = stagedColourId != nil && colours.contains(where: { $0.id == stagedColourId })
        let canConfirm = isStaged && (!needsColour || stagedColourValid) && hasUnsavedChanges(productId: product.id)

        VStack(alignment: .leading, spacing: 0) {
            Button {
                AVIAHaptic.lightTap.trigger()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    if isStaged {
                        // Collapse: revert staged back to whatever is saved
                        // so we don't leave half-made changes hanging.
                        syncStagedFromSaved()
                    } else {
                        stagedProductId = product.id
                        // If this is the currently saved product, restore the
                        // saved colour so the swatch stays highlighted; for a
                        // brand-new pick the client must choose deliberately.
                        stagedColourId = (selection.productId == product.id) ? selection.colourId : nil
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    heroThumb(urlString: heroImageURL)
                        .frame(width: 52, height: 52)
                        .clipShape(.rect(cornerRadius: 8))
                        .onTapGesture {
                            if let urlStr = heroImageURL, !urlStr.isEmpty {
                                AVIAHaptic.lightTap.trigger()
                                previewImageURL = IdentifiedURL(urlString: urlStr)
                            }
                        }
                        .animation(.easeInOut(duration: 0.22), value: heroImageURL)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: isSaved ? "largecircle.fill.circle" : (isStaged ? "circle.dashed" : "circle"))
                                .font(.neueCorp(14))
                                .foregroundStyle(isSaved ? AVIATheme.timelessBrown : (isStaged ? AVIATheme.timelessBrown.opacity(0.7) : AVIATheme.textTertiary))
                            Text(product.name)
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                                .lineLimit(2)
                        }
                        if let brand = product.brand, !brand.isEmpty {
                            Text(brand)
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                        HStack(spacing: 6) {
                            inclusionBadge(inclusion: inclusion, cost: upgradeCost)
                            if isSaved {
                                Text("CONFIRMED")
                                    .font(.neueCorpMedium(8))
                                    .kerning(0.8)
                                    .foregroundStyle(AVIATheme.heritageBlue)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(AVIATheme.heritageBlue.opacity(0.12), in: Capsule())
                            } else if isStaged {
                                Text("UNCONFIRMED")
                                    .font(.neueCorpMedium(8))
                                    .kerning(0.8)
                                    .foregroundStyle(AVIATheme.warning)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(AVIATheme.warning.opacity(0.12), in: Capsule())
                            }
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.neueCorp(11))
                        .foregroundStyle(AVIATheme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable(.subtle))

            if isExpanded {
                Divider().background(AVIATheme.surfaceBorder)
                VStack(alignment: .leading, spacing: 14) {
                    largePreview(urlString: heroImageURL)
                    if needsColour {
                        colourGrid(productId: product.id, colours: colours)
                    } else {
                        Text("This product has no colour options. Tap Confirm to lock it in.")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    confirmBar(productId: product.id, canConfirm: canConfirm, needsColour: needsColour)
                }
                .padding(12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(isSaved ? AVIATheme.cardBackgroundAlt : (isStaged ? AVIATheme.warning.opacity(0.04) : AVIATheme.background.opacity(0.5)))
        .clipShape(.rect(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(isSaved ? AVIATheme.timelessBrown.opacity(0.45) : (isStaged ? AVIATheme.warning.opacity(0.5) : AVIATheme.surfaceBorder), lineWidth: 1)
        }
    }

    private func hasUnsavedChanges(productId: String) -> Bool {
        if selection.productId != productId { return true }
        return selection.colourId != stagedColourId
    }

    @ViewBuilder
    private func confirmBar(productId: String, canConfirm: Bool, needsColour: Bool) -> some View {
        let helper: String? = {
            if needsColour && stagedColourId == nil { return "Pick a colour to enable Confirm" }
            if !canConfirm && selection.productId == productId { return "Already confirmed — tap a different product or colour to change" }
            return nil
        }()
        VStack(alignment: .leading, spacing: 8) {
            if let helper {
                Text(helper)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            Button {
                AVIAHaptic.success.trigger()
                confirmStaged(productId: productId)
            } label: {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.neueCorp(13))
                    }
                    Text(isSaving ? "Confirming…" : "Confirm Selection")
                        .font(.neueCaptionMedium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundStyle(canConfirm ? AVIATheme.aviaWhite : AVIATheme.textTertiary)
                .background(canConfirm ? AnyShapeStyle(AVIATheme.primaryGradient) : AnyShapeStyle(AVIATheme.surfaceElevated))
                .clipShape(.rect(cornerRadius: 10))
            }
            .buttonStyle(.pressable(.standard))
            .disabled(!canConfirm || isSaving)
        }
    }

    private func confirmStaged(productId: String) {
        guard !isSaving else { return }
        isSaving = true
        let colourToSave = stagedColourId
        Task {
            await viewModel.saveProductSelection(
                selectionId: selection.id,
                productId: productId,
                colourId: colourToSave
            )
            await MainActor.run {
                isSaving = false
                onConfirmed()
            }
        }
    }

    @ViewBuilder
    private func largePreview(urlString: String?) -> some View {
        Color(.secondarySystemBackground)
            .frame(height: 260)
            .frame(maxWidth: .infinity)
            .overlay {
                if let urlStr = urlString, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image {
                            img.resizable().aspectRatio(contentMode: .fill)
                                .transition(.opacity.combined(with: .scale(scale: 1.02)))
                        } else if phase.error != nil {
                            Image(systemName: "photo")
                                .font(.system(size: 32))
                                .foregroundStyle(AVIATheme.textTertiary)
                        } else {
                            ProgressView()
                        }
                    }
                    .id(urlStr)
                    .allowsHitTesting(false)
                } else {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 32))
                        .foregroundStyle(AVIATheme.textTertiary)
                }
            }
            .clipShape(.rect(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
            }
            .overlay(alignment: .topTrailing) {
                if let urlStr = urlString, !urlStr.isEmpty {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.neueCorpMedium(11))
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .padding(8)
                        .background(Color.black.opacity(0.45), in: Circle())
                        .padding(10)
                }
            }
            .animation(.easeInOut(duration: 0.28), value: urlString)
            .contentShape(Rectangle())
            .onTapGesture {
                if let urlStr = urlString, !urlStr.isEmpty {
                    AVIAHaptic.lightTap.trigger()
                    previewImageURL = IdentifiedURL(urlString: urlStr)
                }
            }
    }

    private func heroThumb(urlString: String?) -> some View {
        Color(.secondarySystemBackground)
            .overlay {
                if let urlStr = urlString, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image {
                            img.resizable().aspectRatio(contentMode: .fill)
                                .transition(.opacity)
                        } else {
                            Image(systemName: "shippingbox")
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                    }
                    .id(urlStr)
                    .allowsHitTesting(false)
                } else {
                    Image(systemName: "shippingbox")
                        .foregroundStyle(AVIATheme.textTertiary)
                }
            }
    }

    @ViewBuilder
    private func inclusionBadge(inclusion: ProductRangeInclusion, cost: Double) -> some View {
        switch inclusion {
        case .included:
            Text("INCLUDED")
                .font(.neueCorpMedium(8))
                .kerning(0.8)
                .foregroundStyle(AVIATheme.heritageBlue)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(AVIATheme.heritageBlue.opacity(0.12), in: Capsule())
        case .upgrade:
            HStack(spacing: 6) {
                Text("UPGRADE")
                    .font(.neueCorpMedium(8))
                    .kerning(0.8)
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(AVIATheme.timelessBrown.opacity(0.12), in: Capsule())
                if cost > 0 {
                    Text("+\(AVIATheme.formatCost(cost))")
                        .font(.neueCorpMedium(10))
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }
        case .unavailable:
            EmptyView()
        }
    }

    // MARK: - Colour grid

    private func colourGrid(productId: String, colours: [SpecProductColourRow]) -> some View {
        let columns = AdaptiveLayout.denseSwatchColumns(spacing: 10)
        return VStack(alignment: .leading, spacing: 8) {
            Text("COLOUR")
                .font(.neueCorpMedium(8))
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(colours, id: \.id) { colour in
                    colourSwatch(productId: productId, colour: colour)
                }
            }
        }
    }

    private func colourSwatch(productId: String, colour: SpecProductColourRow) -> some View {
        let isStagedColour = stagedColourId == colour.id
        let roomAssignment = assignment(for: colour.id)
        // Prefer room-specific cost when assigned as an upgrade; fall back to
        // the colour's base extra_cost otherwise.
        let extra: Double = {
            if let a = roomAssignment {
                return a.inclusionValue == .upgrade ? a.cost : 0
            }
            return colour.extra_cost ?? 0
        }()
        let imageURL: String? = {
            if let a = roomAssignment, let u = a.image_url, !u.isEmpty { return u }
            return colour.image_url
        }()
        let hasImage = !(imageURL ?? "").isEmpty
        return Button {
            AVIAHaptic.lightTap.trigger()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                stagedColourId = colour.id
            }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if hasImage, let urlStr = imageURL, let url = URL(string: urlStr) {
                            Color(.secondarySystemBackground)
                                .frame(width: 44, height: 44)
                                .overlay {
                                    AsyncImage(url: url) { phase in
                                        if let img = phase.image {
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } else {
                                            Image(systemName: "photo")
                                                .font(.neueCorp(12))
                                                .foregroundStyle(AVIATheme.textTertiary)
                                        }
                                    }
                                    .allowsHitTesting(false)
                                }
                                .clipShape(Circle())
                                .overlay {
                                    Circle().stroke(isStagedColour ? AVIATheme.timelessBrown : AVIATheme.surfaceBorder, lineWidth: isStagedColour ? 2.5 : 1)
                                }
                        } else {
                            Circle()
                                .fill(Color(hex: colour.hex ?? "CCCCCC"))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Circle().stroke(isStagedColour ? AVIATheme.timelessBrown : AVIATheme.surfaceBorder, lineWidth: isStagedColour ? 2.5 : 1)
                                }
                        }
                    }
                    if isStagedColour {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.neueCorp(13))
                            .foregroundStyle(AVIATheme.timelessBrown)
                            .background(Color.white, in: Circle())
                            .offset(x: 4, y: -4)
                    }
                }
                Text(colour.name)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let sku = colour.sku, !sku.isEmpty {
                    Text(sku)
                        .font(.neueCorpMedium(8))
                        .kerning(0.5)
                        .foregroundStyle(AVIATheme.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                if extra > 0 {
                    Text("+\(AVIATheme.formatCost(extra))")
                        .font(.neueCorpMedium(8))
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(.subtle))
    }
}
