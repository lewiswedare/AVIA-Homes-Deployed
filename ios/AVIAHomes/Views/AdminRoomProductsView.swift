import SwiftUI

// MARK: - Room Products (selection-category + slot based)
//
// Room-first editor. Slots in a room are now grouped by **Selection
// Category** — a free-text name the admin sets on the slot's
// `display_title`. Multiple categories can exist per room (e.g. "Floor
// Tiles" + "Wall Tiles"), and the same variant can appear under more
// than one category, each carrying its own per-range image + cost.
//
// Conceptually:
//
// Room (e.g. Bathroom)
//   └── Selection Category ("Floor Tiles")
//         └── Slot — one variant + 3 range rows (image/cost/inclusion)
//
// Each slot still represents one client-facing line item. Admins create a
// category by naming it, then bulk-pick variants to drop into it; each
// pick spawns one slot pre-tagged with the category name.

struct AdminRoomProductsView: View {
    let room: SpecCategoryRow

    @State private var allItems: [SpecItemFlatRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var searchText: String = ""

    @State private var newCategorySheetOpen = false
    @State private var addVariantToCategory: AddVariantContext?
    @State private var renameCategory: RenameContext?
    @State private var duplicateCategory: DuplicateContext?
    @State private var reorderSheetOpen = false
    @State private var editingSlot: IdentifiedSlot?

    private var catalog: CatalogDataManager { CatalogDataManager.shared }

    private let rangeIds: [String] = ["volos", "messina", "portobello"]
    private let rangeNames: [String: String] = ["volos": "Volos", "messina": "Messina", "portobello": "Portobello"]
    private let rangeColors: [String: Color] = [
        "volos": AVIATheme.timelessBrown,
        "messina": AVIATheme.warning,
        "portobello": AVIATheme.heritageBlue
    ]

    // MARK: Slot + category grouping

    private struct SlotEntry: Identifiable {
        let id: String          // slot id
        let variant: SpecProductColourRow
        let itemId: String
        let itemName: String
        let displayTitle: String
        let sortOrder: Int
    }

    private struct CategoryGroup: Identifiable {
        let id: String          // normalized title (lowercased + trimmed), "" for Untitled
        let displayName: String // canonical title as typed
        let slots: [SlotEntry]
        let minSortOrder: Int   // for category ordering
    }

    /// All facade-agnostic slots in this room, grouped by selection
    /// category (display_title). Untitled slots collapse into one
    /// "Untitled" group so the admin can rename them in one shot.
    private var groupedCategories: [CategoryGroup] {
        let itemMap: [String: SpecItemFlatRow] = Dictionary(uniqueKeysWithValues: allItems.map { ($0.id, $0) })
        let variants: [String: SpecProductColourRow] = Dictionary(uniqueKeysWithValues: catalog.coloursByProduct.values.flatMap { $0 }.map { ($0.id, $0) })

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

        // Search filter.
        let q = searchText.trimmingCharacters(in: .whitespaces)
        let filtered: [SlotEntry] = q.isEmpty ? entries : entries.filter { e in
            e.itemName.localizedStandardContains(q)
                || e.variant.name.localizedStandardContains(q)
                || (e.variant.sku ?? "").localizedStandardContains(q)
                || e.displayTitle.localizedStandardContains(q)
        }

        // Group by normalized title.
        var byKey: [String: [SlotEntry]] = [:]
        var displayNameForKey: [String: String] = [:]
        for e in filtered {
            let key = e.displayTitle.lowercased()
            byKey[key, default: []].append(e)
            if displayNameForKey[key] == nil {
                displayNameForKey[key] = e.displayTitle
            }
        }

        var groups: [CategoryGroup] = []
        for (key, slots) in byKey {
            let sorted = slots.sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                if lhs.itemName != rhs.itemName {
                    return lhs.itemName.localizedStandardCompare(rhs.itemName) == .orderedAscending
                }
                return lhs.variant.name.localizedStandardCompare(rhs.variant.name) == .orderedAscending
            }
            let minSort = sorted.map { $0.sortOrder }.min() ?? 0
            groups.append(CategoryGroup(id: key, displayName: displayNameForKey[key] ?? "", slots: sorted, minSortOrder: minSort))
        }
        // Untitled (empty key) sinks to the bottom; named groups ordered by
        // their persisted sort_order (admin drag-to-reorder), name as tiebreak.
        return groups.sorted { lhs, rhs in
            if lhs.id.isEmpty != rhs.id.isEmpty { return !lhs.id.isEmpty }
            if lhs.minSortOrder != rhs.minSortOrder { return lhs.minSortOrder < rhs.minSortOrder }
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }

    private var totalSlots: Int {
        groupedCategories.reduce(0) { $0 + $1.slots.count }
    }

    private var existingCategoryNames: [String] {
        groupedCategories
            .compactMap { $0.displayName.isEmpty ? nil : $0.displayName }
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                heroHeader
                statsBar

                if isLoading && groupedCategories.isEmpty {
                    ProgressView().tint(AVIATheme.timelessBrown).padding(.vertical, 60)
                } else if groupedCategories.isEmpty {
                    AdminEmptyState(
                        icon: "square.grid.2x2",
                        title: "No selection categories yet",
                        subtitle: "Create a category like \"Floor Tiles\" then drop variants into it. The same variant can live in multiple categories with its own image and price."
                    )
                    newCategoryButton
                        .padding(.top, 8)
                } else {
                    ForEach(groupedCategories) { group in
                        categorySection(group)
                    }
                    newCategoryButton
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
        .searchable(text: $searchText, prompt: "Search categories, products or variants…")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        newCategorySheetOpen = true
                    } label: {
                        Label("New Selection Category", systemImage: "plus.circle")
                    }
                    Button {
                        reorderSheetOpen = true
                    } label: {
                        Label("Reorder Categories", systemImage: "arrow.up.arrow.down")
                    }
                    .disabled(groupedCategories.filter { !$0.id.isEmpty }.count < 2)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }
        }
        .sheet(isPresented: $newCategorySheetOpen) {
            NewCategorySheet(
                room: room,
                allItems: allItems,
                catalog: catalog,
                existingCategoryNames: existingCategoryNames
            ) { categoryName, variantIds in
                newCategorySheetOpen = false
                Task { await createCategory(name: categoryName, variantIds: variantIds) }
            }
        }
        .sheet(item: $addVariantToCategory) { ctx in
            VariantMultiPickerSheet(
                roomName: room.name,
                categoryName: ctx.categoryName,
                allItems: allItems,
                catalog: catalog
            ) { variantIds in
                addVariantToCategory = nil
                Task { await addVariants(variantIds: variantIds, toCategory: ctx.categoryName) }
            }
        }
        .sheet(item: $renameCategory) { ctx in
            RenameCategorySheet(
                roomName: room.name,
                currentName: ctx.currentName
            ) { newName in
                renameCategory = nil
                Task { await renameCategory(slotIds: ctx.slotIds, currentName: ctx.currentName, newName: newName) }
            }
        }
        .sheet(item: $duplicateCategory) { ctx in
            DuplicateCategorySheet(
                roomName: room.name,
                sourceName: ctx.sourceName,
                existingNames: existingCategoryNames
            ) { newName in
                duplicateCategory = nil
                Task { await cloneCategory(sourceSlotIds: ctx.slotIds, newName: newName) }
            }
        }
        .sheet(isPresented: $reorderSheetOpen) {
            ReorderCategoriesSheet(
                roomName: room.name,
                categories: groupedCategories.filter { !$0.id.isEmpty }.map {
                    ReorderCategoriesSheet.Item(id: $0.id, displayName: $0.displayName, slotIds: $0.slots.map { $0.id }, variantCount: $0.slots.count)
                }
            ) { reorderedSlotsByCategory in
                reorderSheetOpen = false
                Task { await applyCategoryOrder(reorderedSlotsByCategory) }
            }
        }
        .sheet(item: $editingSlot) { wrapped in
            let variant = catalog.coloursByProduct.values.flatMap { $0 }.first(where: { $0.id == wrapped.variantId })
            RoomSlotAssignmentSheet(
                room: room,
                slotId: wrapped.id,
                variantId: wrapped.variantId,
                variantName: variant?.name ?? "Variant",
                isNew: false,
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
                    Text("Group variants under selection categories — e.g. \"Floor Tiles\" and \"Wall Tiles\" can share the same internal-tile catalogue, each with its own per-range image + price.")
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
            AdminMiniStat(value: "\(groupedCategories.count)", label: "Categories", color: AVIATheme.timelessBrown)
            AdminMiniStat(value: "\(totalSlots)", label: "Slots", color: AVIATheme.warning)
            AdminMiniStat(value: "\(allItems.count)", label: "In Catalogue", color: AVIATheme.heritageBlue)
        }
    }

    private var newCategoryButton: some View {
        Button { newCategorySheetOpen = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text("New Selection Category")
                    .font(.neueSubheadlineMedium)
            }
            .foregroundStyle(AVIATheme.aviaWhite)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(AVIATheme.primaryGradient)
            .clipShape(.rect(cornerRadius: 11))
        }
    }

    // MARK: Category section

    @ViewBuilder
    private func categorySection(_ group: CategoryGroup) -> some View {
        BentoCard(cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 10) {
                categoryHeader(group)

                Divider().background(AVIATheme.surfaceBorder)

                VStack(spacing: 6) {
                    ForEach(group.slots) { entry in
                        slotRow(entry)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 4)

                Button {
                    addVariantToCategory = AddVariantContext(
                        categoryName: group.displayName,
                        normalizedKey: group.id
                    )
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                        Text(group.displayName.isEmpty ? "Add variant" : "Add variant to \(group.displayName)")
                            .font(.neueCaption2Medium)
                            .lineLimit(1)
                    }
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(AVIATheme.timelessBrown.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 8))
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
    }

    @ViewBuilder
    private func categoryHeader(_ group: CategoryGroup) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: group.id.isEmpty ? "square.dashed" : "square.grid.2x2")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text(group.displayName.isEmpty ? "Untitled" : group.displayName)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                }
                Text("\(group.slots.count) \(group.slots.count == 1 ? "variant" : "variants") in this category")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            Spacer()
            Menu {
                Button {
                    renameCategory = RenameContext(
                        currentName: group.displayName,
                        slotIds: group.slots.map { $0.id }
                    )
                } label: {
                    Label(group.id.isEmpty ? "Name category" : "Rename category", systemImage: "pencil")
                }
                Button {
                    addVariantToCategory = AddVariantContext(
                        categoryName: group.displayName,
                        normalizedKey: group.id
                    )
                } label: {
                    Label("Add variant", systemImage: "plus")
                }
                Button {
                    duplicateCategory = DuplicateContext(
                        sourceName: group.displayName,
                        slotIds: group.slots.map { $0.id }
                    )
                } label: {
                    Label("Duplicate category", systemImage: "square.on.square")
                }
                .disabled(group.slots.isEmpty)
                Button(role: .destructive) {
                    Task { await deleteCategory(slotIds: group.slots.map { $0.id }, name: group.displayName) }
                } label: {
                    Label("Delete category", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
                    .padding(6)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
    }

    private func slotRow(_ entry: SlotEntry) -> some View {
        let assignments = catalog.rows(forSlot: entry.id).filter { $0.facade_id == nil }
        return Button {
            editingSlot = IdentifiedSlot(id: entry.id, variantId: entry.variant.id, isNew: false)
        } label: {
            HStack(spacing: 10) {
                variantSwatch(entry.variant)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.variant.name.isEmpty ? "Unnamed variant" : entry.variant.name)
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.textPrimary)
                        .lineLimit(1)
                    Text(entry.itemName)
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
                Image(systemName: "pencil")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.timelessBrown)
            }
            .padding(8)
            .background(AVIATheme.surfaceElevated.opacity(0.6))
            .clipShape(.rect(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                editingSlot = IdentifiedSlot(id: entry.id, variantId: entry.variant.id, isNew: false)
            } label: {
                Label("Edit slot", systemImage: "pencil")
            }
            Button(role: .destructive) {
                Task { await removeSlot(entry.id) }
            } label: {
                Label("Remove from category", systemImage: "trash")
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

    private func createCategory(name: String, variantIds: [String]) async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Category name can't be empty"
            return
        }
        guard !variantIds.isEmpty else {
            successMessage = "Created \"\(trimmed)\" — add variants from its menu"
            return
        }
        await insertSlots(variantIds: variantIds, title: trimmed)
        successMessage = "Added \(variantIds.count) variant\(variantIds.count == 1 ? "" : "s") to \(trimmed)"
        await reload()
    }

    private func addVariants(variantIds: [String], toCategory categoryName: String) async {
        guard !variantIds.isEmpty else { return }
        let trimmed = categoryName.trimmingCharacters(in: .whitespaces)
        let title: String? = trimmed.isEmpty ? nil : trimmed
        await insertSlots(variantIds: variantIds, title: title)
        let categoryLabel = trimmed.isEmpty ? "Untitled" : trimmed
        successMessage = "Added \(variantIds.count) variant\(variantIds.count == 1 ? "" : "s") to \(categoryLabel)"
        await reload()
    }

    /// Inserts one slot per variant id with the supplied display title.
    /// Each slot writes 3 rows (one per range) so the slot is visible
    /// across the spec ranges. Default values: included + cost 0 + no
    /// image; admin drills into a slot afterwards to set per-range
    /// detail.
    private func insertSlots(variantIds: [String], title: String?) async {
        var inserts: [VariantRoomAssignmentInsert] = []
        for variantId in variantIds {
            let slotId = UUID().uuidString
            for rangeId in rangeIds {
                inserts.append(
                    VariantRoomAssignmentInsert(
                        variant_id: variantId,
                        room_id: room.id,
                        range_id: rangeId,
                        facade_id: nil,
                        image_url: nil,
                        cost: 0,
                        inclusion: VariantInclusion.included.rawValue,
                        sort_order: 0,
                        display_title: title,
                        selection_slot_id: slotId
                    )
                )
            }
        }
        let result = await SupabaseService.shared.bulkInsertVariantRoomAssignments(inserts)
        if !result.ok {
            errorMessage = "Save failed: \(result.error ?? "unknown")"
        }
    }

    private func renameCategory(slotIds: [String], currentName: String, newName: String) async {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Category name can't be empty"
            return
        }
        let trimmedCurrent = currentName.trimmingCharacters(in: .whitespaces)
        if trimmed.lowercased() == trimmedCurrent.lowercased() {
            return
        }
        // Reject if another category already owns this name.
        let exists = groupedCategories.contains { $0.id == trimmed.lowercased() && !$0.slots.contains(where: { slotIds.contains($0.id) }) }
        if exists {
            errorMessage = "A category named \"\(trimmed)\" already exists in \(room.name)"
            return
        }
        let result = await SupabaseService.shared.updateVariantRoomAssignmentsTitleBySlots(slotIds: slotIds, newTitle: trimmed)
        if result.ok {
            successMessage = "Renamed to \(trimmed)"
            await reload()
        } else {
            errorMessage = "Couldn't rename: \(result.error ?? "unknown")"
        }
    }

    /// Persist a new category ordering. `reorderedSlotsByCategory` is the
    /// final top→bottom array of categories (each as its full slot id list).
    /// We assign incrementing sort_order blocks so the room view sorts to
    /// match without touching slot identity.
    private func applyCategoryOrder(_ reorderedSlotsByCategory: [[String]]) async {
        let svc = SupabaseService.shared
        var anyFail = false
        for (index, slotIds) in reorderedSlotsByCategory.enumerated() {
            guard !slotIds.isEmpty else { continue }
            // sort_order is shared by every slot in a category — multiply by
            // 10 so future single-slot insertions can settle between groups.
            let order = index * 10
            let r = await svc.updateVariantRoomAssignmentsSortBySlots(slotIds: slotIds, sortOrder: order)
            if !r.ok { anyFail = true }
        }
        if anyFail {
            errorMessage = "Couldn't save the new order — try again"
        } else {
            successMessage = "Category order updated"
        }
        await reload()
    }

    /// Clone every slot in `sourceSlotIds` into a new category named
    /// `newName`. Each clone gets a fresh slot uuid + copies all 3 per-range
    /// rows (image, cost, inclusion) verbatim so the admin can tweak them
    /// independently afterwards.
    private func cloneCategory(sourceSlotIds: [String], newName: String) async {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Give the new category a name"
            return
        }
        let normalized = trimmed.lowercased()
        if existingCategoryNames.contains(where: { $0.lowercased() == normalized }) {
            errorMessage = "\"\(trimmed)\" already exists in \(room.name)"
            return
        }
        var inserts: [VariantRoomAssignmentInsert] = []
        let all = catalog.allVariantAssignments
        for sourceSlot in sourceSlotIds {
            let sourceRows = all.filter { $0.selection_slot_id == sourceSlot && $0.facade_id == nil }
            guard let first = sourceRows.first else { continue }
            let newSlot = UUID().uuidString
            // Copy one row per (range) found on the source.
            for r in sourceRows {
                inserts.append(
                    VariantRoomAssignmentInsert(
                        variant_id: r.variant_id,
                        room_id: r.room_id,
                        range_id: r.range_id,
                        facade_id: nil,
                        image_url: r.image_url,
                        cost: r.cost,
                        inclusion: r.inclusion,
                        sort_order: r.sort_order ?? 0,
                        display_title: trimmed,
                        selection_slot_id: newSlot
                    )
                )
            }
            // If the source somehow had fewer than 3 range rows, top up
            // with included/0/no-image so the new slot is visible in every
            // range — keeps the admin grid consistent.
            let existingRanges = Set(sourceRows.map { $0.range_id })
            for rangeId in rangeIds where !existingRanges.contains(rangeId) {
                inserts.append(
                    VariantRoomAssignmentInsert(
                        variant_id: first.variant_id,
                        room_id: first.room_id,
                        range_id: rangeId,
                        facade_id: nil,
                        image_url: nil,
                        cost: 0,
                        inclusion: VariantInclusion.included.rawValue,
                        sort_order: 0,
                        display_title: trimmed,
                        selection_slot_id: newSlot
                    )
                )
            }
        }
        guard !inserts.isEmpty else {
            errorMessage = "Nothing to duplicate in \(room.name)"
            return
        }
        let result = await SupabaseService.shared.bulkInsertVariantRoomAssignments(inserts)
        if result.ok {
            successMessage = "Duplicated to \(trimmed)"
            await reload()
        } else {
            errorMessage = "Couldn't duplicate: \(result.error ?? "unknown")"
        }
    }

    private func deleteCategory(slotIds: [String], name: String) async {
        guard !slotIds.isEmpty else { return }
        let svc = SupabaseService.shared
        var anyFail = false
        for slotId in slotIds {
            let r = await svc.deleteVariantRoomAssignmentsBySlot(slotId: slotId)
            if !r.ok { anyFail = true }
        }
        if anyFail {
            errorMessage = "Some slots couldn't be removed"
        } else {
            let label = name.isEmpty ? "Untitled" : name
            successMessage = "Removed \(label) from \(room.name)"
        }
        await reload()
    }
}

// MARK: - Identified types

private struct IdentifiedSlot: Identifiable, Hashable {
    let id: String
    let variantId: String
    let isNew: Bool
}

private struct AddVariantContext: Identifiable {
    var id: String { normalizedKey + "_addvariant" }
    let categoryName: String
    let normalizedKey: String
}

private struct RenameContext: Identifiable {
    var id: String { currentName.lowercased() + "_rename" }
    let currentName: String
    let slotIds: [String]
}

private struct DuplicateContext: Identifiable {
    var id: String { sourceName.lowercased() + "_duplicate" }
    let sourceName: String
    let slotIds: [String]
}

// MARK: - New Category sheet (name + multi-select variants)

private struct NewCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let room: SpecCategoryRow
    let allItems: [SpecItemFlatRow]
    let catalog: CatalogDataManager
    let existingCategoryNames: [String]
    let onSave: (_ categoryName: String, _ variantIds: [String]) -> Void

    @State private var categoryName: String = ""
    @State private var query: String = ""
    @State private var expandedItemId: String?
    @State private var selectedVariantIds: Set<String> = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    nameCard
                    suggestionsCard
                    pickerCard
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
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { attemptSave() }
                        .fontWeight(.semibold)
                        .disabled(categoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var nameCard: some View {
        BentoCard(cornerRadius: 11) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Category name in \(room.name)")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                TextField("e.g. Floor Tiles", text: $categoryName)
                    .font(.neueCaption)
                    .padding(10)
                    .background(AVIATheme.surfaceElevated)
                    .clipShape(.rect(cornerRadius: 6))
                Text("Clients see this as the line-item title. Re-using a variant under a second category lets you set different images and prices for the same SKU.")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(14)
        }
    }

    @ViewBuilder
    private var suggestionsCard: some View {
        if !existingCategoryNames.isEmpty {
            BentoCard(cornerRadius: 11) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Existing in this room")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 6)], spacing: 6) {
                        ForEach(existingCategoryNames, id: \.self) { name in
                            Text(name)
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AVIATheme.surfaceElevated.opacity(0.6), in: Capsule())
                        }
                    }
                }
                .padding(14)
            }
        }
    }

    private var pickerCard: some View {
        BentoCard(cornerRadius: 11) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Pick variants")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Spacer()
                    Text("\(selectedVariantIds.count) selected")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                TextField("Search products & variants…", text: $query)
                    .font(.neueCaption2)
                    .padding(10)
                    .background(AVIATheme.surfaceElevated)
                    .clipShape(.rect(cornerRadius: 6))
                    .padding(.horizontal, 14)

                VStack(spacing: 6) {
                    ForEach(filteredItems, id: \.id) { item in
                        VariantPickerRow(
                            item: item,
                            catalog: catalog,
                            isExpanded: expandedItemId == item.id,
                            selectedVariantIds: $selectedVariantIds,
                            onToggleExpand: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    expandedItemId = expandedItemId == item.id ? nil : item.id
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
    }

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

    private func attemptSave() {
        let trimmed = categoryName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Give the category a name"
            return
        }
        let normalized = trimmed.lowercased()
        if existingCategoryNames.contains(where: { $0.lowercased() == normalized }) {
            errorMessage = "A category named \"\(trimmed)\" already exists in \(room.name)"
            return
        }
        onSave(trimmed, Array(selectedVariantIds))
    }
}

// MARK: - Variant multi-picker (used when adding variants to an existing category)

private struct VariantMultiPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let roomName: String
    let categoryName: String
    let allItems: [SpecItemFlatRow]
    let catalog: CatalogDataManager
    let onSave: (_ variantIds: [String]) -> Void

    @State private var query: String = ""
    @State private var expandedItemId: String?
    @State private var selectedVariantIds: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    headerCard
                    ForEach(filteredItems, id: \.id) { item in
                        VariantPickerRow(
                            item: item,
                            catalog: catalog,
                            isExpanded: expandedItemId == item.id,
                            selectedVariantIds: $selectedVariantIds,
                            onToggleExpand: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    expandedItemId = expandedItemId == item.id ? nil : item.id
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(.bottom, 40)
            }
            .background(AVIATheme.background)
            .navigationTitle("Add to \(categoryName.isEmpty ? "Untitled" : categoryName)")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search products & variants…")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave(Array(selectedVariantIds))
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedVariantIds.isEmpty)
                }
            }
        }
    }

    private var headerCard: some View {
        BentoCard(cornerRadius: 11) {
            HStack(spacing: 12) {
                Image(systemName: "square.grid.2x2")
                    .font(.neueCorpMedium(14))
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .frame(width: 36, height: 36)
                    .background(AVIATheme.timelessBrown.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(categoryName.isEmpty ? "Untitled" : categoryName)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Adding to \(roomName) — \(selectedVariantIds.count) selected.")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                Spacer()
            }
            .padding(14)
        }
    }

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
}

// MARK: - Shared variant picker row (one product card + expandable variants)

private struct VariantPickerRow: View {
    let item: SpecItemFlatRow
    let catalog: CatalogDataManager
    let isExpanded: Bool
    @Binding var selectedVariantIds: Set<String>
    let onToggleExpand: () -> Void

    var body: some View {
        let productIds = catalog.productsBySpecItem[item.id] ?? []
        let variants: [SpecProductColourRow] = productIds.flatMap { catalog.coloursByProduct[$0] ?? [] }
        BentoCard(cornerRadius: 10) {
            VStack(spacing: 0) {
                Button {
                    onToggleExpand()
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
                                let pickedHere = variants.filter { selectedVariantIds.contains($0.id) }.count
                                if pickedHere > 0 {
                                    Text("• \(pickedHere) picked")
                                        .font(.neueCaption2)
                                        .foregroundStyle(AVIATheme.timelessBrown)
                                }
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .padding(12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                    if variants.isEmpty {
                        Text("This product has no variants yet — add one under All Products first.")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                            .padding(12)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(variants, id: \.id) { v in
                                variantPickRow(v)
                            }
                        }
                        .padding(8)
                    }
                }
            }
        }
    }

    private func variantPickRow(_ v: SpecProductColourRow) -> some View {
        let isSelected = selectedVariantIds.contains(v.id)
        return Button {
            AVIAHaptic.lightTap.trigger()
            if isSelected {
                selectedVariantIds.remove(v.id)
            } else {
                selectedVariantIds.insert(v.id)
            }
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
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.neueCaption)
                    .foregroundStyle(isSelected ? AVIATheme.timelessBrown : AVIATheme.textTertiary)
            }
            .padding(8)
            .background((isSelected ? AVIATheme.timelessBrown.opacity(0.08) : AVIATheme.surfaceElevated.opacity(0.6)))
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

// MARK: - Duplicate Category sheet

private struct DuplicateCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let roomName: String
    let sourceName: String
    let existingNames: [String]
    let onSave: (_ newName: String) -> Void

    @State private var name: String = ""
    @State private var hasInitialised = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    BentoCard(cornerRadius: 11) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Duplicating \"\(sourceName.isEmpty ? "Untitled" : sourceName)\" in \(roomName)")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                            TextField("e.g. Wall Tiles", text: $name)
                                .font(.neueCaption)
                                .padding(10)
                                .background(AVIATheme.surfaceElevated)
                                .clipShape(.rect(cornerRadius: 6))
                            Text("Creates a new category with the same variants. Each new slot gets its own image + price you can tweak independently of the original.")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                            if let msg = errorMessage {
                                Text(msg)
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.destructive)
                            }
                        }
                        .padding(14)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(AVIATheme.background)
            .navigationTitle("Duplicate Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Duplicate") { attemptSave() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .task {
                guard !hasInitialised else { return }
                hasInitialised = true
                let base = sourceName.isEmpty ? "New Category" : sourceName
                name = suggestUnique(base: base)
            }
        }
    }

    private func suggestUnique(base: String) -> String {
        let lower = Set(existingNames.map { $0.lowercased() })
        var attempt = "\(base) Copy"
        if !lower.contains(attempt.lowercased()) { return attempt }
        var i = 2
        while lower.contains("\(base) Copy \(i)".lowercased()) { i += 1 }
        attempt = "\(base) Copy \(i)"
        return attempt
    }

    private func attemptSave() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Give the new category a name"
            return
        }
        let normalized = trimmed.lowercased()
        if existingNames.contains(where: { $0.lowercased() == normalized }) {
            errorMessage = "\"\(trimmed)\" already exists in \(roomName)"
            return
        }
        onSave(trimmed)
    }
}

// MARK: - Reorder Categories sheet

private struct ReorderCategoriesSheet: View {
    @Environment(\.dismiss) private var dismiss

    struct Item: Identifiable, Hashable {
        let id: String          // normalized key
        let displayName: String
        let slotIds: [String]
        let variantCount: Int
    }

    let roomName: String
    let categories: [Item]
    /// Reports the new order as an array of slot id arrays — one entry per
    /// category, top to bottom. Caller persists `sort_order` accordingly.
    let onSave: (_ slotsByCategory: [[String]]) -> Void

    @State private var items: [Item] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(items) { item in
                        HStack(spacing: 10) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(AVIATheme.textTertiary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.displayName)
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text("\(item.variantCount) \(item.variantCount == 1 ? "variant" : "variants")")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                            }
                        }
                    }
                    .onMove { source, destination in
                        items.move(fromOffsets: source, toOffset: destination)
                    }
                } header: {
                    Text("Drag to reorder categories in \(roomName)")
                        .font(.neueCaption2)
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(items.map { $0.slotIds })
                    }
                    .fontWeight(.semibold)
                }
            }
            .task {
                if items.isEmpty { items = categories }
            }
        }
    }
}

// MARK: - Rename Category sheet

private struct RenameCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let roomName: String
    let currentName: String
    let onSave: (_ newName: String) -> Void

    @State private var name: String = ""
    @State private var hasInitialised = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    BentoCard(cornerRadius: 11) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category name in \(roomName)")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                            TextField("e.g. Floor Tiles", text: $name)
                                .font(.neueCaption)
                                .padding(10)
                                .background(AVIATheme.surfaceElevated)
                                .clipShape(.rect(cornerRadius: 6))
                            Text("Renaming applies to every variant currently in this category.")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                        .padding(14)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(AVIATheme.background)
            .navigationTitle(currentName.isEmpty ? "Name Category" : "Rename Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(name) }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .task {
                guard !hasInitialised else { return }
                hasInitialised = true
                name = currentName
            }
        }
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
                Text("Selection category in \(room.name)")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                TextField("e.g. Floor Tiles", text: $displayTitle)
                    .font(.neueCaption)
                    .padding(10)
                    .background(AVIATheme.surfaceElevated)
                    .clipShape(.rect(cornerRadius: 6))
                Text("Renaming here moves this slot into a different selection category. Other slots in the original category keep their title.")
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

        // Guard: prevent two slots in the same room from sharing the same
        // (variant, title) pair. A variant can be added to a room many
        // times — but only once per logical category (e.g. one "Floor
        // Tiles" slot using SKU X). Title comparison is case-insensitive
        // on the trimmed value; empty titles share the "untitled" bucket.
        let normalized = title.lowercased()
        let conflict = CatalogDataManager.shared.allVariantAssignments.contains { row in
            guard row.room_id == room.id, row.facade_id == nil else { return false }
            guard row.variant_id == variantId else { return false }
            guard let otherSlot = row.selection_slot_id, otherSlot != slotId else { return false }
            let otherTitle = (row.display_title ?? "").trimmingCharacters(in: .whitespaces).lowercased()
            return otherTitle == normalized
        }
        if conflict {
            let label = title.isEmpty ? "(no title)" : "\"\(title)\""
            errorMessage = "This variant is already in \(room.name) under category \(label). Use a different selection category to add it again."
            return
        }

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
