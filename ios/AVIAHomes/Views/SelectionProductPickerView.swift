import SwiftUI

/// Product-driven picker shown inside a Spec Item card. Replaces the legacy
/// tier-upgrade + colour-swatch flow when the spec item has products configured
/// for the current range. Hierarchy: Range -> Item -> Product -> Colour.
struct SelectionProductPickerView: View {
    @Bindable var viewModel: BuildSpecViewModel
    let selection: BuildSpecSelection
    /// Products available in the build's current range (already filtered to
    /// exclude Unavailable). Sorted by sort_order.
    let products: [(product: SpecProductRow, membership: SpecRangeItemProductRow)]

    @State private var expandedProductId: String?
    @State private var previewImageURL: IdentifiedURL?

    private var catalog: CatalogDataManager { CatalogDataManager.shared }

    private var selectedIsUpgrade: Bool {
        guard let pid = selection.productId,
              let m = catalog.rangeProductMemberships["\(selection.specTier.lowercased())|\(pid)"] else { return false }
        return (m.inclusion_override ?? "") == "upgrade" || (m.upgrade_price_override ?? 0) > 0
    }

    private var selectedColourHasExtra: Bool {
        guard let pid = selection.productId, let cid = selection.colourId,
              let colour = catalog.coloursByProduct[pid]?.first(where: { $0.id == cid }) else { return false }
        return (colour.extra_cost ?? 0) > 0
    }

    private var chosenProductId: String? {
        selection.productId ?? catalog.defaultProductId(
            for: selection.specItemId,
            rangeId: selection.specTier.lowercased()
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("CHOOSE A PRODUCT")
                    .font(.neueCorpMedium(9))
                    .kerning(1.2)
                    .foregroundStyle(AVIATheme.timelessBrown)
                Spacer()
                if selectedIsUpgrade || selectedColourHasExtra {
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

            VStack(spacing: 10) {
                ForEach(products, id: \.product.id) { entry in
                    productCard(product: entry.product, membership: entry.membership)
                }
            }
        }
        .fullScreenCover(item: $previewImageURL) { item in
            ZoomableImageViewer(urlString: item.urlString)
        }
    }

    private func resetToDefault() {
        let rangeId = selection.specTier.lowercased()
        let defaultPid = catalog.defaultProductId(for: selection.specItemId, rangeId: rangeId)
        let defaultCid = defaultPid.flatMap { catalog.defaultIncludedColourId(for: $0) }
        Task {
            await viewModel.saveProductSelection(
                selectionId: selection.id,
                productId: defaultPid ?? "",
                colourId: defaultCid
            )
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            expandedProductId = nil
        }
    }

    // MARK: - Product card

    @ViewBuilder
    private func productCard(product: SpecProductRow, membership: SpecRangeItemProductRow) -> some View {
        let inclusion = ProductRangeInclusion(rawValue: membership.inclusion_override ?? "included") ?? .included
        let isSelected = chosenProductId == product.id
        let colours = catalog.productColours(for: product.id)
        let isExpanded = expandedProductId == product.id || (isSelected && !colours.isEmpty)
        let upgradeCost = membership.upgrade_price_override ?? 0

        VStack(alignment: .leading, spacing: 0) {
            Button {
                AVIAHaptic.lightTap.trigger()
                pickProduct(product, membership: membership, colours: colours)
                if !colours.isEmpty {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        expandedProductId = (expandedProductId == product.id) ? nil : product.id
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    productThumb(product)
                        .frame(width: 52, height: 52)
                        .clipShape(.rect(cornerRadius: 8))
                        .onTapGesture {
                            if let urlStr = product.image_url, !urlStr.isEmpty {
                                AVIAHaptic.lightTap.trigger()
                                previewImageURL = IdentifiedURL(urlString: urlStr)
                            }
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                .font(.neueCorp(14))
                                .foregroundStyle(isSelected ? AVIATheme.timelessBrown : AVIATheme.textTertiary)
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
                        inclusionBadge(inclusion: inclusion, cost: upgradeCost)
                    }

                    Spacer(minLength: 0)

                    if !colours.isEmpty {
                        Image(systemName: "chevron.down")
                            .font(.neueCorp(11))
                            .foregroundStyle(AVIATheme.textTertiary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable(.subtle))

            if isExpanded && !colours.isEmpty {
                Divider().background(AVIATheme.surfaceBorder)
                colourGrid(productId: product.id, colours: colours)
                    .padding(12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(isSelected ? AVIATheme.cardBackgroundAlt : AVIATheme.background.opacity(0.5))
        .clipShape(.rect(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(isSelected ? AVIATheme.timelessBrown.opacity(0.45) : AVIATheme.surfaceBorder, lineWidth: 1)
        }
    }

    private func productThumb(_ product: SpecProductRow) -> some View {
        Color(.secondarySystemBackground)
            .overlay {
                if let urlStr = product.image_url, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image {
                            img.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: "shippingbox")
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                    }
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
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
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
        let isSelected = (selection.productId == productId) && (selection.colourId == colour.id)
        let extra = colour.extra_cost ?? 0
        return Button {
            AVIAHaptic.lightTap.trigger()
            Task {
                await viewModel.saveProductSelection(
                    selectionId: selection.id,
                    productId: productId,
                    colourId: colour.id
                )
            }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(Color(hex: colour.hex ?? "CCCCCC"))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Circle().stroke(isSelected ? AVIATheme.timelessBrown : AVIATheme.surfaceBorder, lineWidth: isSelected ? 2.5 : 1)
                        }
                    if isSelected {
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

    // MARK: - Actions

    private func pickProduct(
        _ product: SpecProductRow,
        membership: SpecRangeItemProductRow,
        colours: [SpecProductColourRow]
    ) {
        let resolvedColour: String? = {
            if let existing = selection.colourId,
               colours.contains(where: { $0.id == existing }),
               selection.productId == product.id {
                return existing
            }
            return colours.first(where: { $0.is_default == true })?.id ?? colours.first?.id
        }()
        Task {
            await viewModel.saveProductSelection(
                selectionId: selection.id,
                productId: product.id,
                colourId: resolvedColour
            )
        }
    }
}
