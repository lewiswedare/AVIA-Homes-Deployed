import SwiftUI

// MARK: - Room Products (slot-based)
//
// Room-first editor: from a room, search products + variants and add them to
// the room. Each assignment is one **slot** — a uuid grouping the 3 range
// rows of one logical client-facing line-item. The same variant can be added
// to a room multiple times as separate slots (e.g. tile SKU A used as both
// "Floor Tiles" AND "Wall Tiles"), each with its own selection title, image
// and per-range cost / inclusion. Only facade-agnostic slots are managed
// here; facade-scoped assignments live in the dedicated facade editor.

struct AdminRoomProductsView: View {
    let room: SpecCategoryRow

    @State private var allItems: [SpecItemFlatRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var searchText: String = ""
    @State private var addingPickerOpen = false
    @State private var editingSlot: IdentifiedSlot?

    private var catalog: CatalogDataManager { CatalogDataManager.shared }

    private let rangeIds: [String] = ["volos", "messina", "portobello"]
    private let rangeNames: [String: String] = ["volos": "Volos", "messina": "Messina", "portobello": "Portobello"]
    private let rangeColors: [String: Color] = [
        "volos": AVIATheme.timelessBrown,
        "messina": AVIATheme.warning,
        "portobello": AVIATheme.heritageBlue
    ]

    // MARK: Slot grouping

    /// One row per slot currently assigned (facade-agnostic) to this room.
    /// Grouped by the parent spec item so visually related slots stay
    /// together.
    private struct SlotEntry: Identifiable {
        let id: String          // slot id
        let variant: SpecProductColourRow
        let itemId: String
        let itemName: String
        let displayTitle: String
        let sortOrder: Int
    }

    private var groupedSlots: [(itemId: String, itemName: String, slots: [SlotEntry])] {
        let itemMap: [String: SpecItemFlatRow] = Dictionary(uniqueKeysWithValues: allItems.map { ($0.id, $0) })
        let variants: [String: SpecProductColourRow] = Dictionary(uniqueKeysWithValues: catalog.coloursByProduct.values.flatMap { $0 }.map { ($0.id, $0) })

        // Build one entry per slot.
        var bySlot: [String: [VariantRoomAssignmentRow]] = [:]
        for a in catalog.allVariantAssignments where a.room_id == room.id && a.facade_id == nil {
            guard let slot = a.selection_slot_id else { continue }
            bySlot[slot, default: []].append(a)
        }

        var entries: [SlotEntry] = []
        for (slotId, rows) in bySlot {
            guard let rep = rows.sorted(by: { ($0.sort_order ?? 0) < ($1.sort_order ?? 0) }).first else { continue }
            guard let variant = variants[rep.variant_id] else { continue }
            guard let itemId = catalog.specItemId(forVariantId: variant.id) else { continue }
            let itemName = itemMap[itemId]?.name ?? "Unnamed item"
            let title = rows.compactMap { $0.display_title?.trimmingCharacters(in: .whitespaces) }.first(where: { !$0.isEmpty }) ?? ""
            entries.append(SlotEntry(
                id: slotId,
                variant: variant,
                itemId: itemId,
                itemName: itemName,
                displayTitle: title,
                sortOrder: rep.sort_order ?? 0
            ))
        }

        // Filter by search.
        let q = searchText.trimmingCharacters(in: .whitespaces)
        let filtered: [SlotEntry] = q.isEmpty ? entries : entries.filter { e in
            e.itemName.localizedStandardContains(q)
                || e.variant.name.localizedStandardContains(q)
                || (e.variant.sku ?? "").localizedStandardContains(q)
                || e.displayTitle.localizedStandardContains(q)
        }

        // Group by item id.
        var byItem: [String: [SlotEntry]] = [:]
        for e in filtered { byItem[e.itemId, default: []].append(e) }
        var groups: [(itemId: String, itemName: String, slots: [SlotEntry])] = []
        for (itemId, slots) in byItem {
            let sorted = slots.sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.displayTitle.localizedStandardCompare(rhs.displayTitle) == .orderedAscending
            }
            let name = sorted.first?.itemName ?? "Unnamed item"
            groups.append((itemId: itemId, itemName: name, slots: sorted))
        }
        return groups.sorted { $0.itemName.localizedStandardCompare($1.itemName) == .orderedAscending }
    }

    private var totalSlots: Int {
        groupedSlots.reduce(0) { $0 + $1.slots.count }
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                heroHeader
                statsBar

                if isLoading && groupedSlots.isEmpty {
                    ProgressView().tint(AVIATheme.timelessBrown).padding(.vertical, 60)
                } else if groupedSlots.isEmpty {
                    AdminEmptyState(
                        icon: "shippingbox",
                        title: "No products in this room yet",
                        subtitle: "Tap Add Product to search the catalogue and assign variants to \(room.name)."
                    )
                    addButton
                        .padding(.top, 8)
                } else {
                    ForEach(groupedSlots, id: \.itemId) { group in
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
                // New slot id for each "add" — that's what lets the same
                // variant be added to the same room multiple times.
                let newSlot = UUID().uuidString
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    editingSlot = IdentifiedSlot(id: newSlot, variantId: variantId, isNew: true)
                }
            }
        }
        .sheet(item: $editingSlot) { wrapped in
            let variant = catalog.coloursByProduct.values.flatMap { $0 }.first(where: { $0.id == wrapped.variantId })
            RoomSlotAssignmentSheet(
                room: room,
                slotId: wrapped.id,
                variantId: wrapped.variantId,
                variantName: variant?.name ?? "Variant",
                isNew: wrapped.isNew,
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
                    Text("Add products as titled slots — e.g. the same tile SKU as both \"Floor Tiles\" and \"Wall Tiles\". Each slot has its own image + price per range.")
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
            AdminMiniStat(value: "\(groupedSlots.count)", label: "Products", color: AVIATheme.timelessBrown)
            AdminMiniStat(value: "\(totalSlots)", label: "Slots", color: AVIATheme.warning)
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
    private func itemSection(_ group: (itemId: String, itemName: String, slots: [SlotEntry])) -> some View {
        BentoCard(cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(group.itemName)
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("\(group.slots.count) \(group.slots.count == 1 ? "slot" : "slots") in this room")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                Divider().background(AVIATheme.surfaceBorder)

                VStack(spacing: 6) {
                    ForEach(group.slots) { entry in
                        slotRow(entry)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
    }

    private func slotRow(_ entry: SlotEntry) -> some View {
        let assignments = catalog.rows(forSlot: entry.id).filter { $0.facade_id == nil }
        let titleText = entry.displayTitle.isEmpty ? entry.variant.name : entry.displayTitle
        let subtitle: String = entry.displayTitle.isEmpty
            ? (entry.variant.sku.map { "SKU \($0)" } ?? "No selection title")
            : entry.variant.name
        return Button {
            editingSlot = IdentifiedSlot(id: entry.id, variantId: entry.variant.id, isNew: false)
        } label: {
            HStack(spacing: 10) {
                variantSwatch(entry.variant)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titleText)
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                        .lineLimit(1)
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
                Task { await removeSlot(entry.id) }
            } label: {
                Label("Remove slot from \(room.name)", systemImage: "trash")
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

    private func removeSlot(_ slotId: String) async {
        let result = await SupabaseService.shared.deleteVariantRoomAssignmentsBySlot(slotId: slotId)
        if result.ok {
            successMessage = "Removed slot from \(room.name)"
            await reload()
        } else {
            errorMessage = "Couldn't remove slot"
        }
    }
}

// MARK: - Identified types

private struct IdentifiedSlot: Identifiable, Hashable {
    let id: String
    let variantId: String
    let isNew: Bool
}

// MARK: - Add Picker Sheet

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

// MARK: - Per-slot Assignment Editor

private struct RoomSlotAssignmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    let room: SpecCategoryRow
    let slotId: String
    let variantId: String
    let variantName: String
    let isNew: Bool
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
            .navigationTitle(isNew ? "New slot in \(room.name)" : "Edit slot in \(room.name)")
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
                    Text(isNew ? "Adding a new slot. Save to publish to \(room.name)." : "Per-range image, cost & inclusion for this slot.")
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
                Text("Shown to clients in place of the product name. Use distinct titles to add the same variant multiple times (e.g. \"Floor Tiles\" + \"Wall Tiles\").")
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
                    Text("Image for \(rangeNames[rangeId] ?? rangeId) in this slot")
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
                        itemId: "\(variantId)_\(room.id)_\(rangeId)_\(slotId)"
                    )
                }
            }
            .padding(14)
        }
    }

    private func load() {
        let catalog = CatalogDataManager.shared
        let mine = catalog.allVariantAssignments.filter {
            $0.selection_slot_id == slotId && $0.facade_id == nil
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

        // Delete this slot's existing rows so we can re-insert with the
        // current values. Scoped tightly by slot id so other slots of the
        // same variant in the same room are untouched.
        _ = await svc.deleteVariantRoomAssignmentsBySlot(slotId: slotId)

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
                    display_title: titleOpt,
                    selection_slot_id: slotId
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
