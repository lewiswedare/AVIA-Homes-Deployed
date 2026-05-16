import SwiftUI

// MARK: - All Products
//
// Flat, product-first catalogue editor. Replaces the room-grouped "Spec Range
// Items" screen with a list of every item (Product) grouped by Product
// Category. Each row expands to reveal its variants and the rooms each
// variant is assigned to, with per-range image + cost + inclusion sourced
// from `variant_room_assignments`.

struct AdminAllProductsView: View {
    @State private var viewModel = AdminCatalogViewModel()
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "all"
    @State private var expanded: Set<String> = []
    @State private var editingItem: SpecItemFlatRow?
    @State private var showingAddSheet: Bool = false
    @State private var itemToDelete: SpecItemFlatRow?

    private let catalog = CatalogDataManager.shared

    private let rangeIds: [String] = ["volos", "messina", "portobello"]
    private let rangeNames: [String: String] = ["volos": "Volos", "messina": "Messina", "portobello": "Portobello"]
    private let rangeColors: [String: Color] = [
        "volos": AVIATheme.timelessBrown,
        "messina": AVIATheme.warning,
        "portobello": AVIATheme.heritageBlue
    ]

    // MARK: Filtering + grouping

    private var productCategories: [ProductCategoryRow] {
        catalog.allProductCategories
    }

    private var filteredItems: [SpecItemFlatRow] {
        var items = viewModel.specItems
        if selectedCategory != "all" {
            if selectedCategory == "uncategorized" {
                items = items.filter { ($0.product_category_id ?? "").isEmpty || $0.product_category_id == "uncategorized" }
            } else {
                items = items.filter { $0.product_category_id == selectedCategory }
            }
        }
        if !searchText.isEmpty {
            items = items.filter {
                $0.name.localizedStandardContains(searchText) ||
                ($0.supplier ?? "").localizedStandardContains(searchText) ||
                ($0.sku ?? "").localizedStandardContains(searchText) ||
                ($0.description ?? "").localizedStandardContains(searchText)
            }
        }
        return items
    }

    private var groupedItems: [(category: ProductCategoryRow, items: [SpecItemFlatRow])] {
        let grouped = Dictionary(grouping: filteredItems) { ($0.product_category_id ?? "uncategorized") }
        var result: [(category: ProductCategoryRow, items: [SpecItemFlatRow])] = []
        for cat in productCategories {
            if let items = grouped[cat.id], !items.isEmpty {
                result.append((cat, items.sorted { ($0.sort_order ?? 0) < ($1.sort_order ?? 0) }))
            }
        }
        // Uncategorized bucket
        let uncategorized = (grouped["uncategorized"] ?? []) + (grouped[""] ?? [])
        if !uncategorized.isEmpty {
            let placeholder = ProductCategoryRow(
                id: "uncategorized",
                name: "Uncategorized",
                icon: "questionmark.circle",
                sort_order: Int.max,
                image_url: nil
            )
            result.append((placeholder, uncategorized.sorted { ($0.sort_order ?? 0) < ($1.sort_order ?? 0) }))
        }
        return result
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                categoryFilter
                statsBar

                if viewModel.isLoading {
                    ProgressView()
                        .tint(AVIATheme.timelessBrown)
                        .padding(.vertical, 60)
                } else if groupedItems.isEmpty {
                    AdminEmptyState(
                        icon: "shippingbox",
                        title: "No Products",
                        subtitle: "Add your first product or seed default items."
                    )
                    Button { Task { await viewModel.seedSpecItemsFromDefaults(); await reload() } } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc.fill")
                            Text("Seed Default Products")
                        }
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(.rect(cornerRadius: 11))
                    }
                } else {
                    ForEach(groupedItems, id: \.category.id) { group in
                        categorySection(group.category, items: group.items)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
            .padding(.top, 12)
        }
        .background(AVIATheme.background)
        .navigationTitle("All Products")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search by name, supplier or SKU…")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddSheet = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            SpecItemEditSheet(item: nil, categories: viewModel.specCategoryOrder) { row, tierImages, swatches in
                Task {
                    await viewModel.saveSpecItem(row, tierImages: tierImages, productSwatches: swatches)
                    await reload()
                }
            }
        }
        .sheet(item: $editingItem) { item in
            SpecItemEditSheet(item: item, categories: viewModel.specCategoryOrder) { row, tierImages, swatches in
                Task {
                    await viewModel.saveSpecItem(row, tierImages: tierImages, productSwatches: swatches)
                    await reload()
                }
            }
        }
        .alert("Delete Product", isPresented: .init(
            get: { itemToDelete != nil },
            set: { if !$0 { itemToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { itemToDelete = nil }
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    Task { await viewModel.deleteSpecItem(id: item.id); await reload() }
                }
            }
        } message: {
            Text("Delete \"\(itemToDelete?.name ?? "")\"? This cannot be undone.")
        }
        .overlay(alignment: .bottom) { toastOverlay }
        .task { await reload() }
    }

    // MARK: - Filter + stats

    private var categoryFilter: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                filterChip("All", id: "all", icon: "square.grid.2x2")
                ForEach(productCategories, id: \.id) { cat in
                    filterChip(cat.name, id: cat.id, icon: cat.icon)
                }
                filterChip("Uncategorized", id: "uncategorized", icon: "questionmark.circle")
            }
        }
        .contentMargins(.horizontal, 0)
        .scrollIndicators(.hidden)
    }

    private func filterChip(_ label: String, id: String, icon: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) { selectedCategory = id }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.neueCaption2)
                Text(label).font(.neueCaptionMedium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(selectedCategory == id ? AVIATheme.aviaWhite : AVIATheme.textSecondary)
            .background(selectedCategory == id ? AVIATheme.timelessBrown : AVIATheme.cardBackground)
            .clipShape(Capsule())
            .overlay {
                if selectedCategory != id {
                    Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                }
            }
        }
    }

    private var statsBar: some View {
        let totalVariants = viewModel.specItems.reduce(0) { acc, item in
            acc + (catalog.productsBySpecItem[item.id]?.reduce(0) { sub, pid in
                sub + (catalog.coloursByProduct[pid]?.count ?? 0)
            } ?? 0)
        }
        let assignedRooms = Set(catalog.allVariantAssignments.filter { $0.facade_id == nil }.map(\.room_id)).count
        return HStack(spacing: 12) {
            AdminMiniStat(value: "\(viewModel.specItems.count)", label: "Products", color: AVIATheme.timelessBrown)
            AdminMiniStat(value: "\(totalVariants)", label: "Variants", color: AVIATheme.warning)
            AdminMiniStat(value: "\(assignedRooms)", label: "Rooms In Use", color: AVIATheme.success)
        }
    }

    // MARK: - Category section

    private func categorySection(_ category: ProductCategoryRow, items: [SpecItemFlatRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.warning)
                Text(category.name)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
                Text("\(items.count) \(items.count == 1 ? "product" : "products")")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }

            VStack(spacing: 10) {
                ForEach(items, id: \.id) { item in
                    productCard(item)
                }
            }
        }
    }

    // MARK: - Product card

    private func productCard(_ item: SpecItemFlatRow) -> some View {
        let isOpen = expanded.contains(item.id)
        let productIds = catalog.productsBySpecItem[item.id] ?? []
        let variants: [SpecProductColourRow] = productIds.flatMap { catalog.coloursByProduct[$0] ?? [] }
        let roomCount = Set(catalog.allVariantAssignments
            .filter { vra in variants.contains(where: { $0.id == vra.variant_id }) }
            .map(\.room_id)).count

        return BentoCard(cornerRadius: 12) {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        if isOpen { expanded.remove(item.id) } else { expanded.insert(item.id) }
                    }
                } label: {
                    HStack(spacing: 12) {
                        productThumb(item)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                                .lineLimit(1)
                            HStack(spacing: 6) {
                                if let supplier = item.supplier, !supplier.isEmpty {
                                    metaPill(icon: "shippingbox", text: supplier)
                                }
                                if !variants.isEmpty {
                                    metaPill(icon: "circle.hexagongrid.fill", text: "\(variants.count) variants")
                                }
                                if roomCount > 0 {
                                    metaPill(icon: "house.lodge", text: "\(roomCount) rooms")
                                }
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                            .rotationEffect(.degrees(isOpen ? 180 : 0))
                    }
                    .padding(14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isOpen {
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                    expandedBody(item: item, variants: variants)
                }
            }
        }
        .contextMenu {
            Button { editingItem = item } label: { Label("Edit details", systemImage: "pencil") }
            Button(role: .destructive) { itemToDelete = item } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func productThumb(_ item: SpecItemFlatRow) -> some View {
        Color(.secondarySystemBackground)
            .frame(width: 52, height: 52)
            .overlay {
                if let urlString = item.image_url, !urlString.isEmpty, let url = URL(string: urlString) {
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
                        .allowsHitTesting(false)
                }
            }
            .clipShape(.rect(cornerRadius: 9))
    }

    private func metaPill(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.neueCaption2)
            Text(text).font(.neueCaption2)
        }
        .foregroundStyle(AVIATheme.textTertiary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(AVIATheme.surfaceElevated.opacity(0.6), in: Capsule())
    }

    // MARK: - Expanded body

    @ViewBuilder
    private func expandedBody(item: SpecItemFlatRow, variants: [SpecProductColourRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Meta row + actions
            HStack(spacing: 10) {
                if let sku = item.sku, !sku.isEmpty {
                    Text("SKU \(sku)")
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                if let dims = item.dimensions, !dims.isEmpty {
                    Text(dims)
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                Spacer()
                NavigationLink {
                    AdminSpecProductsView(specItemId: item.id, specItemName: item.name)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "circle.hexagongrid.fill")
                        Text("Manage variants")
                    }
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.timelessBrown)
                }
                Button { editingItem = item } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("Edit")
                    }
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.heritageBlue)
                }
            }

            if let desc = item.description, !desc.isEmpty {
                Text(desc)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textSecondary)
            }

            if variants.isEmpty {
                emptyVariantsState(itemId: item.id, itemName: item.name)
            } else {
                VStack(spacing: 8) {
                    ForEach(variants, id: \.id) { variant in
                        variantBlock(variant)
                    }
                }
            }
        }
        .padding(14)
    }

    private func emptyVariantsState(itemId: String, itemName: String) -> some View {
        NavigationLink {
            AdminSpecProductsView(specItemId: itemId, specItemName: itemName)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text("Add a variant")
                    .font(.neueCaption2Medium)
                Spacer()
                Image(systemName: "chevron.right").font(.neueCaption2)
            }
            .foregroundStyle(AVIATheme.timelessBrown)
            .padding(10)
            .background(AVIATheme.timelessBrown.opacity(0.1))
            .clipShape(.rect(cornerRadius: 8))
        }
    }

    // MARK: - Variant block

    @ViewBuilder
    private func variantBlock(_ variant: SpecProductColourRow) -> some View {
        // Hide facade-scoped rows from the All Products view; they are
        // surfaced in a separate facade-specific products editor.
        let assignments = catalog.allVariantAssignments.filter { $0.variant_id == variant.id && $0.facade_id == nil }
        let roomsForVariant = roomGroups(from: assignments)

        VStack(alignment: .leading, spacing: 8) {
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
                    } else if variant.is_default == true {
                        Text("Default")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.success)
                    }
                }
                Spacer()
                Text(roomsForVariant.isEmpty ? "Not assigned" : "\(roomsForVariant.count) \(roomsForVariant.count == 1 ? "room" : "rooms")")
                    .font(.neueCaption2)
                    .foregroundStyle(roomsForVariant.isEmpty ? AVIATheme.textTertiary : AVIATheme.heritageBlue)
            }

            if roomsForVariant.isEmpty {
                Text("No room assignments yet — open Manage variants to set per-room image, cost & inclusion.")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            } else {
                VStack(spacing: 6) {
                    ForEach(roomsForVariant, id: \.roomId) { group in
                        roomRow(group: group)
                    }
                }
            }
        }
        .padding(10)
        .background(AVIATheme.surfaceElevated.opacity(0.6))
        .clipShape(.rect(cornerRadius: 9))
    }

    private func variantSwatch(_ variant: SpecProductColourRow) -> some View {
        Group {
            if let urlString = variant.image_url, !urlString.isEmpty, let url = URL(string: urlString) {
                Color(.secondarySystemBackground)
                    .frame(width: 28, height: 28)
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
                    .frame(width: 28, height: 28)
                    .overlay { Circle().stroke(AVIATheme.surfaceBorder, lineWidth: 1) }
            }
        }
    }

    // MARK: - Room row

    private struct RoomGroup {
        let roomId: String
        let assignments: [VariantRoomAssignmentRow]
    }

    private func roomGroups(from assignments: [VariantRoomAssignmentRow]) -> [RoomGroup] {
        let byRoom = Dictionary(grouping: assignments, by: { $0.room_id })
        // Order rooms by the canonical category sort_order if known.
        let orderedRoomIds = catalog.allSpecCategories.map(\.id)
        var seen: Set<String> = []
        var result: [RoomGroup] = []
        for rid in orderedRoomIds {
            if let items = byRoom[rid] {
                result.append(RoomGroup(roomId: rid, assignments: items))
                seen.insert(rid)
            }
        }
        for (rid, items) in byRoom where !seen.contains(rid) {
            result.append(RoomGroup(roomId: rid, assignments: items))
        }
        return result
    }

    private func roomRow(group: RoomGroup) -> some View {
        let roomName = catalog.allSpecCategories.first { $0.id == group.roomId }?.name ?? group.roomId
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "house.lodge.fill")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.heritageBlue)
                Text(roomName)
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
            }

            HStack(spacing: 6) {
                ForEach(rangeIds, id: \.self) { rangeId in
                    rangeAssignmentBadge(rangeId: rangeId, assignments: group.assignments)
                }
            }
        }
        .padding(8)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 7))
    }

    private func rangeAssignmentBadge(rangeId: String, assignments: [VariantRoomAssignmentRow]) -> some View {
        // All Products only surfaces facade-agnostic assignments. Facade-
        // specific items are managed in a dedicated editor.
        let inRange = assignments.filter { $0.range_id == rangeId && $0.facade_id == nil }
        let primary = inRange.first
        let color = rangeColors[rangeId] ?? AVIATheme.textTertiary
        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(rangeNames[rangeId] ?? rangeId)
                .font(.neueCaption2Medium)
                .foregroundStyle(color)
            if let p = primary {
                Image(systemName: p.inclusionValue == .included ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                    .font(.neueCaption2)
                    .foregroundStyle(p.inclusionValue == .included ? AVIATheme.success : AVIATheme.warning)
                if p.inclusionValue == .upgrade && p.cost > 0 {
                    Text("+$\(Int(p.cost))")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.warning)
                }
            } else {
                Image(systemName: "minus.circle")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(color.opacity(0.08), in: Capsule())
    }

    // MARK: - Toast

    @ViewBuilder
    private var toastOverlay: some View {
        if let msg = viewModel.successMessage {
            Text(msg)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.aviaWhite)
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(AVIATheme.success, in: Capsule())
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { viewModel.successMessage = nil }
                    }
                }
        }
        if let msg = viewModel.errorMessage {
            Text(msg)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.aviaWhite)
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(AVIATheme.destructive, in: Capsule())
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { viewModel.errorMessage = nil }
                    }
                }
        }
    }

    // MARK: - Data

    private func reload() async {
        await viewModel.loadSpecItems()
        await catalog.loadAll()
    }
}
