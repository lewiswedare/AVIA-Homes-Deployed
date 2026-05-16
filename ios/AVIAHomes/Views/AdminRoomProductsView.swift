import SwiftUI

// MARK: - Room Products
//
// Room-first editor: from a room, search products + variants and add them to
// the room. Each assignment supports a per-room "Selection title" override
// (e.g. one tile variant can appear as "Floor Tiles" in the Bathroom and
// "Splashback" in the Kitchen) plus the existing per-range image + cost +
// inclusion. Only facade-agnostic rows are managed here; facade-scoped
// assignments live in the dedicated facade editor.

struct AdminRoomProductsView: View {
    let room: SpecCategoryRow

    @State private var allItems: [SpecItemFlatRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var searchText: String = ""
    @State private var addingPickerOpen = false
    @State private var editingVariantId: String?

    private var catalog: CatalogDataManager { CatalogDataManager.shared }

    private let rangeIds: [String] = ["volos", "messina", "portobello"]
    private let rangeNames: [String: String] = ["volos": "Volos", "messina": "Messina", "portobello": "Portobello"]
    private let rangeColors: [String: Color] = [
        "volos": AVIATheme.timelessBrown,
        "messina": AVIATheme.warning,
        "portobello": AVIATheme.heritageBlue
    ]

    // MARK: Grouped state

    /// Variants currently assigned to this room (facade-agnostic), grouped by
    /// their spec_item id.
    private var groupedAssignedVariants: [(itemId: String, itemName: String, variants: [SpecProductColourRow])] {
        let mine = catalog.allVariantAssignments.filter { $0.room_id == room.id && $0.facade_id == nil }
        let variantIds = Set(mine.map(\.variant_id))
        var byItem: [String: [SpecProductColourRow]] = [:]
        for v in catalog.coloursByProduct.values.flatMap({ $0 }) where variantIds.contains(v.id) {
            guard let itemId = catalog.specItemId(forVariantId: v.id) else { continue }
            byItem[itemId, default: []].append(v)
        }
        let itemMap: [String: SpecItemFlatRow] = Dictionary(uniqueKeysWithValues: allItems.map { ($0.id, $0) })
        var result: [(itemId: String, itemName: String, variants: [SpecProductColourRow])] = []
        for (itemId, vs) in byItem {
            let item = itemMap[itemId]
            let name = item?.name ?? "Unnamed item"
            // Filter by search across item name, variant name & SKU.
            let q = searchText.trimmingCharacters(in: .whitespaces)
            if !q.isEmpty {
                let itemHits = name.localizedStandardContains(q)
                let variantHits = vs.contains { v in
                    v.name.localizedStandardContains(q) || (v.sku ?? "").localizedStandardContains(q)
                }
                let titleHits: Bool = {
                    let title = catalog.displayTitle(forSpecItem: itemId, roomId: room.id, rangeId: rangeIds[0]) ?? ""
                    return title.localizedStandardContains(q)
                }()
                guard itemHits || variantHits || titleHits else { continue }
            }
            let sortedVariants = vs.sorted { ($0.sort_order ?? 0) < ($1.sort_order ?? 0) }
            result.append((itemId: itemId, itemName: name, variants: sortedVariants))
        }
        return result.sorted { $0.itemName.localizedStandardCompare($1.itemName) == .orderedAscending }
    }

    private var totalAssignedVariants: Int {
        let mine = catalog.allVariantAssignments.filter { $0.room_id == room.id && $0.facade_id == nil }
        return Set(mine.map(\.variant_id)).count
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                heroHeader
                statsBar

                if isLoading && groupedAssignedVariants.isEmpty {
                    ProgressView().tint(AVIATheme.timelessBrown).padding(.vertical, 60)
                } else if groupedAssignedVariants.isEmpty {
                    AdminEmptyState(
                        icon: "shippingbox",
                        title: "No products in this room yet",
                        subtitle: "Tap Add Product to search the catalogue and assign variants to \(room.name)."
                    )
                    addButton
                        .padding(.top, 8)
                } else {
                    ForEach(groupedAssignedVariants, id: \.itemId) { group in
                        itemSection(group)
                    }
                    addButton
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
            .padding(.top, 10)
        }
        .background(AVIATheme.background)
        .navigationTitle(room.name)
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search products in this room…")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { addingPickerOpen = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }
        }
        .sheet(isPresented: $addingPickerOpen) {
            RoomProductPickerSheet(
                roomName: room.name,
                allItems: allItems,
                catalog: catalog
            ) { variantId in
                addingPickerOpen = false
                // Small delay so the picker dismisses before the editor opens.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    editingVariantId = variantId
                }
            }
        }
        .sheet(item: Binding(
            get: { editingVariantId.map { IdentifiedVariant(id: $0) } },
            set: { editingVariantId = $0?.id }
        )) { wrapped in
            let variant = catalog.coloursByProduct.values.flatMap { $0 }.first(where: { $0.id == wrapped.id })
            RoomVariantAssignmentSheet(
                room: room,
                variantId: wrapped.id,
                variantName: variant?.name ?? "Variant",
                onSaved: {
                    Task { await reload() }
                }
            )
        }
        .overlay(alignment: .bottom) { toastOverlay }
        .task { await reload() }
    }

    private var heroHeader: some View {
        BentoCard(cornerRadius: 12) {
            HStack(spacing: 12) {
                Image(systemName: room.icon)
                    .font(.neueCorpMedium(18))
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .frame(width: 46, height: 46)
                    .background(AVIATheme.timelessBrown.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text(room.name)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Search the catalogue and add products + variants. Set a per-room title, image and price per range.")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
        }
    }

    private var statsBar: some View {
        HStack(spacing: 12) {
            AdminMiniStat(value: "\(groupedAssignedVariants.count)", label: "Products", color: AVIATheme.timelessBrown)
            AdminMiniStat(value: "\(totalAssignedVariants)", label: "Variants", color: AVIATheme.warning)
            AdminMiniStat(value: "\(allItems.count)", label: "In Catalogue", color: AVIATheme.heritageBlue)
        }
    }

    private var addButton: some View {
        Button { addingPickerOpen = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text("Add Product to \(room.name)")
                    .font(.neueSubheadlineMedium)
            }
            .foregroundStyle(AVIATheme.aviaWhite)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(AVIATheme.primaryGradient)
            .clipShape(.rect(cornerRadius: 11))
        }
    }

    // MARK: Item section

    @ViewBuilder
    private func itemSection(_ group: (itemId: String, itemName: String, variants: [SpecProductColourRow])) -> some View {
        let displayTitle = catalog.displayTitle(forSpecItem: group.itemId, roomId: room.id, rangeId: rangeIds[0]) ?? ""

        BentoCard(cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        if !displayTitle.isEmpty {
                            Text(displayTitle)
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Text(group.itemName)
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                        } else {
                            Text(group.itemName)
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Text("No room title — using product name")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                    }
                    Spacer()
                    Text("\(group.variants.count) \(group.variants.count == 1 ? "variant" : "variants")")
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(AVIATheme.surfaceElevated, in: Capsule())
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                Divider().background(AVIATheme.surfaceBorder)

                VStack(spacing: 6) {
                    ForEach(group.variants, id: \.id) { variant in
                        variantRow(variant)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
    }

    private func variantRow(_ variant: SpecProductColourRow) -> some View {
        let assignments = catalog.allVariantAssignments.filter { $0.variant_id == variant.id && $0.room_id == room.id && $0.facade_id == nil }
        return Button {
            editingVariantId = variant.id
        } label: {
            HStack(spacing: 10) {
                variantSwatch(variant)
                VStack(alignment: .leading, spacing: 2) {
                    Text(variant.name.isEmpty ? "Unnamed variant" : variant.name)
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    if let sku = variant.sku, !sku.isEmpty {
                        Text("SKU \(sku)")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                }
                Spacer()
                HStack(spacing: 5) {
                    ForEach(rangeIds, id: \.self) { rangeId in
                        rangeBadge(rangeId: rangeId, assignments: assignments)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(8)
            .background(AVIATheme.surfaceElevated.opacity(0.6))
            .clipShape(.rect(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                Task { await removeVariantFromRoom(variant.id) }
            } label: {
                Label("Remove from \(room.name)", systemImage: "trash")
            }
        }
    }

    private func variantSwatch(_ variant: SpecProductColourRow) -> some View {
        Group {
            if let urlString = variant.image_url, !urlString.isEmpty, let url = URL(string: urlString) {
                Color(.secondarySystemBackground)
                    .frame(width: 30, height: 30)
                    .overlay {
                        AsyncImage(url: url) { phase in
                            if let img = phase.image {
                                img.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Image(systemName: "photo").font(.neueCaption2).foregroundStyle(AVIATheme.textTertiary)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .clipShape(Circle())
                    .overlay { Circle().stroke(AVIATheme.surfaceBorder, lineWidth: 1) }
            } else {
                Circle()
                    .fill(Color(hex: variant.hex ?? "CCCCCC"))
                    .frame(width: 30, height: 30)
                    .overlay { Circle().stroke(AVIATheme.surfaceBorder, lineWidth: 1) }
            }
        }
    }

    private func rangeBadge(rangeId: String, assignments: [VariantRoomAssignmentRow]) -> some View {
        let row = assignments.first(where: { $0.range_id == rangeId })
        let color = rangeColors[rangeId] ?? AVIATheme.textTertiary
        return HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            if let r = row {
                Image(systemName: r.inclusionValue == .included ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                    .font(.neueCaption2)
                    .foregroundStyle(r.inclusionValue == .included ? AVIATheme.success : AVIATheme.warning)
            } else {
                Image(systemName: "minus.circle")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(color.opacity(0.08), in: Capsule())
    }

    // MARK: Toast

    @ViewBuilder
    private var toastOverlay: some View {
        if let msg = successMessage {
            Text(msg)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.aviaWhite)
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(AVIATheme.success, in: Capsule())
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { successMessage = nil }
                    }
                }
        }
        if let msg = errorMessage {
            Text(msg)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.aviaWhite)
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(AVIATheme.destructive, in: Capsule())
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { errorMessage = nil }
                    }
                }
        }
    }

    // MARK: Data

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        async let itemsTask = SupabaseService.shared.fetchSpecItemsFlat()
        allItems = await itemsTask
        await catalog.loadAll()
    }

    private func removeVariantFromRoom(_ variantId: String) async {
        let svc = SupabaseService.shared
        var allOk = true
        for rangeId in rangeIds {
            let ok = await svc.deleteVariantRoomAssignment(
                variantId: variantId,
                roomId: room.id,
                rangeId: rangeId,
                facadeId: nil
            )
            if !ok { allOk = false }
        }
        if allOk {
            successMessage = "Removed from \(room.name)"
            await reload()
        } else {
            errorMessage = "Couldn't remove all assignments"
        }
    }
}

// MARK: - Add Picker Sheet

private struct IdentifiedVariant: Identifiable, Hashable {
    let id: String
}

private struct RoomProductPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let roomName: String
    let allItems: [SpecItemFlatRow]
    let catalog: CatalogDataManager
    let onPicked: (_ variantId: String) -> Void

    @State private var query: String = ""
    @State private var expandedItemId: String?

    private var filteredItems: [SpecItemFlatRow] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            return allItems.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        return allItems.filter { item in
            if item.name.localizedStandardContains(q) { return true }
            if (item.sku ?? "").localizedStandardContains(q) { return true }
            if (item.supplier ?? "").localizedStandardContains(q) { return true }
            let pids = catalog.productsBySpecItem[item.id] ?? []
            for pid in pids {
                for v in catalog.coloursByProduct[pid] ?? [] {
                    if v.name.localizedStandardContains(q) { return true }
                    if (v.sku ?? "").localizedStandardContains(q) { return true }
                }
            }
            return false
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    if filteredItems.isEmpty {
                        AdminEmptyState(
                            icon: "magnifyingglass",
                            title: "No matches",
                            subtitle: "Try a different name, SKU or supplier."
                        )
                        .padding(.top, 40)
                    } else {
                        ForEach(filteredItems, id: \.id) { item in
                            itemRow(item)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(.bottom, 40)
            }
            .background(AVIATheme.background)
            .navigationTitle("Add to \(roomName)")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search products & variants…")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func itemRow(_ item: SpecItemFlatRow) -> some View {
        let isOpen = expandedItemId == item.id
        let productIds = catalog.productsBySpecItem[item.id] ?? []
        let variants: [SpecProductColourRow] = productIds.flatMap { catalog.coloursByProduct[$0] ?? [] }
        return BentoCard(cornerRadius: 10) {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        expandedItemId = isOpen ? nil : item.id
                    }
                } label: {
                    HStack(spacing: 10) {
                        thumbnail(urlString: item.image_url)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                                .lineLimit(1)
                            HStack(spacing: 6) {
                                if let supplier = item.supplier, !supplier.isEmpty {
                                    Text(supplier)
                                        .font(.neueCaption2)
                                        .foregroundStyle(AVIATheme.textTertiary)
                                }
                                Text("\(variants.count) \(variants.count == 1 ? "variant" : "variants")")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                            .rotationEffect(.degrees(isOpen ? 180 : 0))
                    }
                    .padding(12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isOpen {
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                    if variants.isEmpty {
                        Text("This product has no variants yet — add one under All Products first.")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                            .padding(12)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(variants, id: \.id) { v in
                                pickRow(v)
                            }
                        }
                        .padding(8)
                    }
                }
            }
        }
    }

    private func pickRow(_ v: SpecProductColourRow) -> some View {
        Button {
            AVIAHaptic.lightTap.trigger()
            onPicked(v.id)
        } label: {
            HStack(spacing: 10) {
                if let urlString = v.image_url, !urlString.isEmpty, let url = URL(string: urlString) {
                    Color(.secondarySystemBackground)
                        .frame(width: 28, height: 28)
                        .overlay {
                            AsyncImage(url: url) { phase in
                                if let img = phase.image {
                                    img.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Image(systemName: "photo").font(.neueCaption2)
                                }
                            }
                            .allowsHitTesting(false)
                        }
                        .clipShape(Circle())
                        .overlay { Circle().stroke(AVIATheme.surfaceBorder, lineWidth: 1) }
                } else {
                    Circle()
                        .fill(Color(hex: v.hex ?? "CCCCCC"))
                        .frame(width: 28, height: 28)
                        .overlay { Circle().stroke(AVIATheme.surfaceBorder, lineWidth: 1) }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(v.name.isEmpty ? "Unnamed variant" : v.name)
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    if let sku = v.sku, !sku.isEmpty {
                        Text("SKU \(sku)")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.timelessBrown)
            }
            .padding(8)
            .background(AVIATheme.surfaceElevated.opacity(0.6))
            .clipShape(.rect(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func thumbnail(urlString: String?) -> some View {
        Color(.secondarySystemBackground)
            .frame(width: 40, height: 40)
            .overlay {
                if let s = urlString, !s.isEmpty, let url = URL(string: s) {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image {
                            img.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: "shippingbox")
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                    }
                    .allowsHitTesting(false)
                } else {
                    Image(systemName: "shippingbox")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textTertiary)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(.rect(cornerRadius: 7))
    }
}

// MARK: - Variant Assignment Editor (scoped to ONE room)

private struct RoomVariantAssignmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    let room: SpecCategoryRow
    let variantId: String
    let variantName: String
    let onSaved: () -> Void

    @State private var displayTitle: String = ""
    @State private var perRange: [String: VariantRoomCellState] = [:]
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var hasLoaded = false

    private let rangeIds: [String] = ["volos", "messina", "portobello"]
    private let rangeNames: [String: String] = ["volos": "Volos", "messina": "Messina", "portobello": "Portobello"]
    private let rangeColors: [String: Color] = [
        "volos": AVIATheme.timelessBrown,
        "messina": AVIATheme.warning,
        "portobello": AVIATheme.heritageBlue
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    headerCard
                    titleCard
                    ForEach(rangeIds, id: \.self) { rangeBlock(rangeId: $0) }
                    if let msg = errorMessage {
                        Text(msg)
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.destructive)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .padding(.bottom, 40)
            }
            .background(AVIATheme.background)
            .navigationTitle("Assign to \(room.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView().tint(AVIATheme.timelessBrown)
                    } else {
                        Button("Save") { Task { await save() } }
                            .fontWeight(.semibold)
                    }
                }
            }
            .task {
                guard !hasLoaded else { return }
                hasLoaded = true
                load()
            }
        }
    }

    private var headerCard: some View {
        BentoCard(cornerRadius: 11) {
            HStack(spacing: 12) {
                Image(systemName: room.icon)
                    .font(.neueCorpMedium(14))
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .frame(width: 36, height: 36)
                    .background(AVIATheme.timelessBrown.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(variantName.isEmpty ? "Variant" : variantName)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Per-range image, cost & inclusion for \(room.name).")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
        }
    }

    private var titleCard: some View {
        BentoCard(cornerRadius: 11) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Selection title in \(room.name)")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                TextField("e.g. Floor Tiles", text: $displayTitle)
                    .font(.neueCaption)
                    .padding(10)
                    .background(AVIATheme.surfaceElevated)
                    .clipShape(.rect(cornerRadius: 6))
                Text("Overrides the product's name when this variant is shown to clients in this room. Leave blank to use the product name.")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(14)
        }
    }

    private func rangeBlock(rangeId: String) -> some View {
        let color = rangeColors[rangeId] ?? AVIATheme.timelessBrown
        return BentoCard(cornerRadius: 11) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle().fill(color).frame(width: 10, height: 10)
                    Text(rangeNames[rangeId] ?? rangeId)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Spacer()
                }

                Picker("", selection: Binding(
                    get: { perRange[rangeId]?.inclusion ?? .included },
                    set: { newValue in
                        var cell = perRange[rangeId] ?? VariantRoomCellState()
                        cell.inclusion = newValue
                        perRange[rangeId] = cell
                    }
                )) {
                    ForEach(VariantInclusion.allCases, id: \.self) { inc in
                        Text(inc.displayName).tag(inc)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 6) {
                    Text("Cost").font(.neueCaption2).foregroundStyle(AVIATheme.textSecondary)
                    Spacer()
                    Text("$").font(.neueCaption2).foregroundStyle(AVIATheme.textTertiary)
                    TextField("0.00", text: Binding(
                        get: { perRange[rangeId]?.cost ?? "" },
                        set: { newValue in
                            var cell = perRange[rangeId] ?? VariantRoomCellState()
                            cell.cost = newValue
                            perRange[rangeId] = cell
                        }
                    ))
                    .font(.neueCaption)
                    .keyboardType(.decimalPad)
                    .frame(width: 110)
                    .padding(8)
                    .background(AVIATheme.surfaceElevated)
                    .clipShape(.rect(cornerRadius: 6))
                    Text("AUD").font(.neueCaption2).foregroundStyle(AVIATheme.textTertiary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Image for \(rangeNames[rangeId] ?? rangeId) in this room")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                    AdminCompactImagePicker(
                        imageURL: Binding(
                            get: { perRange[rangeId]?.imageURL ?? "" },
                            set: { newValue in
                                var cell = perRange[rangeId] ?? VariantRoomCellState()
                                cell.imageURL = newValue
                                perRange[rangeId] = cell
                            }
                        ),
                        folder: "variant-room-assignments/\(rangeId)",
                        itemId: "\(variantId)_\(room.id)_\(rangeId)"
                    )
                }
            }
            .padding(14)
        }
    }

    private func load() {
        let catalog = CatalogDataManager.shared
        let mine = catalog.allVariantAssignments.filter {
            $0.variant_id == variantId && $0.room_id == room.id && $0.facade_id == nil
        }
        for a in mine {
            if let t = a.display_title, !t.isEmpty, displayTitle.isEmpty {
                displayTitle = t
            }
            var cell = VariantRoomCellState()
            cell.inclusion = a.inclusionValue
            cell.cost = a.cost > 0 ? String(format: "%.2f", a.cost) : ""
            cell.imageURL = a.image_url ?? ""
            perRange[a.range_id] = cell
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let svc = SupabaseService.shared

        let title = displayTitle.trimmingCharacters(in: .whitespaces)
        let titleOpt: String? = title.isEmpty ? nil : title

        // Delete any facade-agnostic rows for this (variant, room) so we can
        // bulk re-insert with the new values. Mirrors AdminVariantRoomAssignmentsView's
        // replace-on-save strategy — far simpler than per-row upserts against
        // the partial unique indexes.
        for rangeId in rangeIds {
            _ = await svc.deleteVariantRoomAssignment(
                variantId: variantId,
                roomId: room.id,
                rangeId: rangeId,
                facadeId: nil
            )
        }

        var inserts: [VariantRoomAssignmentInsert] = []
        for rangeId in rangeIds {
            let cell = perRange[rangeId] ?? VariantRoomCellState()
            let trimmedCost = cell.cost.trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: ",", with: "")
            let cost = Double(trimmedCost) ?? 0
            inserts.append(
                VariantRoomAssignmentInsert(
                    variant_id: variantId,
                    room_id: room.id,
                    range_id: rangeId,
                    facade_id: nil,
                    image_url: cell.imageURL.isEmpty ? nil : cell.imageURL,
                    cost: cost,
                    inclusion: cell.inclusion.rawValue,
                    sort_order: 0,
                    display_title: titleOpt
                )
            )
        }

        let ins = await svc.bulkInsertVariantRoomAssignments(inserts)
        guard ins.ok else {
            errorMessage = "Save failed: \(ins.error ?? "unknown")"
            return
        }

        await CatalogDataManager.shared.loadAll()
        onSaved()
        dismiss()
    }
}
