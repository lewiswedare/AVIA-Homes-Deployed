import SwiftUI

/// Full "Fittings & Fixtures" browser for a spec range. Lists every catalogue
/// product configured for the range (Included or Upgrade), filterable by room
/// and inclusion, in a grid or list. Tapping a product opens its detail sheet.
struct SpecRangeFittingsView: View {
    let tier: SpecTier

    @State private var selectedCategoryId: String? = nil   // nil = All Rooms
    @State private var layout: Layout = .grid
    @State private var inclusionFilter: InclusionFilter = .all
    @State private var detail: RangeFitting?

    enum Layout: String, CaseIterable, Identifiable {
        case grid, list
        var id: String { rawValue }
        var icon: String { self == .grid ? "square.grid.2x2" : "list.bullet" }
        var label: String { self == .grid ? "Grid" : "List" }
    }

    enum InclusionFilter: String, CaseIterable, Identifiable {
        case all = "All Options"
        case included = "Included"
        case upgrades = "Upgrades"
        var id: String { rawValue }
    }

    private var groups: [RangeFittingGroup] {
        CatalogDataManager.shared.fittingsAndFixtures(forRange: tier.rawValue)
    }

    private var visibleItems: [RangeFitting] {
        var items: [RangeFitting] = {
            guard let cid = selectedCategoryId else { return groups.flatMap { $0.items } }
            return groups.first(where: { $0.categoryId == cid })?.items ?? []
        }()
        switch inclusionFilter {
        case .all: break
        case .included: items = items.filter { $0.inclusion == .included }
        case .upgrades: items = items.filter { $0.inclusion == .upgrade }
        }
        return items
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                controls
                if groups.isEmpty {
                    emptyState(message: "Fittings & fixtures for the \(tier.displayName) range are being finalised. Check back soon.")
                } else if visibleItems.isEmpty {
                    emptyState(message: "No \(inclusionFilter == .upgrades ? "upgrade" : "") items in this room. Try another filter.")
                } else if layout == .grid {
                    gridContent
                } else {
                    listContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .adaptiveWideWidth()
        }
        .background(AVIATheme.background)
        .navigationTitle("Fittings & Fixtures")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("Fittings & Fixtures")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text(tier.displayName)
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
            }
        }
        .sheet(item: $detail) { fitting in
            SpecRangeFittingDetailSheet(tier: tier, fitting: fitting)
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                inclusionMenu
                Spacer(minLength: 0)
                layoutToggle
            }
            roomChips
        }
    }

    private var inclusionMenu: some View {
        Menu {
            ForEach(InclusionFilter.allCases) { option in
                Button {
                    AVIAHaptic.lightTap.trigger()
                    withAnimation(.easeInOut(duration: 0.2)) { inclusionFilter = option }
                } label: {
                    if inclusionFilter == option {
                        Label(option.rawValue, systemImage: "checkmark")
                    } else {
                        Text(option.rawValue)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(inclusionFilter.rawValue)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(AVIATheme.cardBackground)
            .clipShape(Capsule())
            .overlay { Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: 1) }
        }
    }

    private var layoutToggle: some View {
        HStack(spacing: 2) {
            ForEach(Layout.allCases) { option in
                Button {
                    AVIAHaptic.lightTap.trigger()
                    withAnimation(.easeInOut(duration: 0.2)) { layout = option }
                } label: {
                    Image(systemName: option.icon)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(layout == option ? AVIATheme.aviaWhite : AVIATheme.textTertiary)
                        .frame(width: 38, height: 32)
                        .background(layout == option ? AnyShapeStyle(AVIATheme.timelessBrown) : AnyShapeStyle(Color.clear))
                        .clipShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.pressable(.subtle))
                .accessibilityLabel(option.label)
            }
        }
        .padding(3)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 11))
        .overlay { RoundedRectangle(cornerRadius: 11).stroke(AVIATheme.surfaceBorder, lineWidth: 1) }
    }

    private var roomChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                roomChip(id: nil, title: "All Rooms", icon: "square.grid.2x2.fill")
                ForEach(groups) { group in
                    roomChip(id: group.categoryId, title: group.categoryName, icon: group.categoryIcon)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func roomChip(id: String?, title: String, icon: String) -> some View {
        Button {
            AVIAHaptic.lightTap.trigger()
            withAnimation(.easeInOut(duration: 0.2)) { selectedCategoryId = id }
        } label: {
            AVIAChip(title, icon: icon, isSelected: selectedCategoryId == id)
        }
        .buttonStyle(.pressable(.subtle))
    }

    // MARK: - Grid / List

    private var gridContent: some View {
        LazyVGrid(columns: AdaptiveLayout.cardColumns(spacing: 12), spacing: 12) {
            ForEach(visibleItems) { fitting in
                Button {
                    AVIAHaptic.lightTap.trigger()
                    detail = fitting
                } label: {
                    gridCard(fitting)
                }
                .buttonStyle(.pressable(.subtle))
            }
        }
    }

    private var listContent: some View {
        VStack(spacing: 10) {
            ForEach(visibleItems) { fitting in
                Button {
                    AVIAHaptic.lightTap.trigger()
                    detail = fitting
                } label: {
                    listRow(fitting)
                }
                .buttonStyle(.pressable(.subtle))
            }
        }
    }

    private func gridCard(_ fitting: RangeFitting) -> some View {
        let product = fitting.product
        let imageURL = CatalogDataManager.shared.displayImageURL(forProduct: product)
        return VStack(alignment: .leading, spacing: 0) {
            Color(AVIATheme.surfaceElevated)
                .frame(height: 150)
                .overlay { productImage(imageURL) }
                .overlay(alignment: .topLeading) {
                    inclusionTag(fitting)
                        .padding(8)
                }
                .clipShape(.rect(cornerRadii: .init(topLeading: 12, topTrailing: 12)))

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let secondary = secondaryLine(product), !secondary.isEmpty {
                    Text(secondary)
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .lineLimit(1)
                }
                if let sku = product.sku, !sku.isEmpty {
                    Text(sku)
                        .font(.neueCorpMedium(9))
                        .kerning(0.5)
                        .foregroundStyle(AVIATheme.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        }
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(AVIATheme.surfaceBorder, lineWidth: 1) }
    }

    private func listRow(_ fitting: RangeFitting) -> some View {
        let product = fitting.product
        let imageURL = CatalogDataManager.shared.displayImageURL(forProduct: product)
        return HStack(spacing: 12) {
            Color(AVIATheme.surfaceElevated)
                .frame(width: 64, height: 64)
                .overlay { productImage(imageURL) }
                .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(product.name)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let secondary = secondaryLine(product), !secondary.isEmpty {
                    Text(secondary)
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    inclusionTag(fitting)
                    if let sku = product.sku, !sku.isEmpty {
                        Text(sku)
                            .font(.neueCorpMedium(9))
                            .kerning(0.5)
                            .foregroundStyle(AVIATheme.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .padding(10)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(AVIATheme.surfaceBorder, lineWidth: 1) }
    }

    @ViewBuilder
    private func productImage(_ urlString: String?) -> some View {
        if let urlStr = urlString, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else if phase.error != nil {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 24))
                        .foregroundStyle(AVIATheme.textTertiary)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .allowsHitTesting(false)
        } else {
            Image(systemName: "shippingbox")
                .font(.system(size: 24))
                .foregroundStyle(AVIATheme.textTertiary)
        }
    }

    @ViewBuilder
    private func inclusionTag(_ fitting: RangeFitting) -> some View {
        switch fitting.inclusion {
        case .included:
            Text("INCLUDED")
                .font(.neueCorpMedium(8))
                .kerning(0.8)
                .foregroundStyle(AVIATheme.heritageBlue)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(AVIATheme.heritageBlue.opacity(0.14), in: Capsule())
        case .upgrade:
            HStack(spacing: 4) {
                Text("UPGRADE")
                    .font(.neueCorpMedium(8))
                    .kerning(0.8)
                if fitting.upgradeCost > 0 {
                    Text("+\(AVIATheme.formatCost(fitting.upgradeCost))")
                        .font(.neueCorpMedium(9))
                }
            }
            .foregroundStyle(AVIATheme.timelessBrown)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(AVIATheme.timelessBrown.opacity(0.14), in: Capsule())
        case .unavailable:
            EmptyView()
        }
    }

    private func secondaryLine(_ product: SpecProductRow) -> String? {
        let parts = [product.brand, product.model].compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        if parts.isEmpty {
            if let description = product.description, !description.isEmpty { return description }
            return nil
        }
        return parts.joined(separator: " · ")
    }

    private func emptyState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: 34))
                .foregroundStyle(AVIATheme.timelessBrown.opacity(0.35))
            Text(message)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
