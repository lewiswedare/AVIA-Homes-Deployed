import SwiftUI

struct AdminProductCategoriesEditorView: View {
    @State private var categories: [ProductCategoryRow] = []
    @State private var isLoading = false
    @State private var editing: ProductCategoryRow?
    @State private var showingAdd = false
    @State private var toDelete: ProductCategoryRow?
    @State private var successMessage: String?
    @State private var errorMessage: String?
    @State private var searchText = ""

    private var sorted: [ProductCategoryRow] {
        let base = categories.sorted { $0.sort_order < $1.sort_order }
        if searchText.isEmpty { return base }
        return base.filter { $0.name.localizedStandardContains(searchText) }
    }

    private func itemCount(for id: String) -> Int {
        CatalogDataManager.shared.allSpecCategories
            .flatMap(\.items)
            .compactMap { _ in nil as Int? } // placeholder; items live in flat rows
            .count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading && categories.isEmpty {
                    ProgressView().tint(AVIATheme.timelessBrown).padding(.vertical, 60)
                } else if categories.isEmpty {
                    AdminEmptyState(
                        icon: "square.stack.3d.down.right",
                        title: "No Product Categories",
                        subtitle: "Add Tile, Stone, Tapware, Cabinetry and any other product groups your items belong to."
                    )
                    addButton
                } else {
                    BentoCard(cornerRadius: 11) {
                        VStack(spacing: 0) {
                            ForEach(Array(sorted.enumerated()), id: \.element.id) { index, cat in
                                row(cat)
                                if index < sorted.count - 1 {
                                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 60)
                                }
                            }
                        }
                    }
                    addButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .navigationTitle("Product Categories")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search product categories...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            ProductCategoryEditSheet(category: nil, defaultSortOrder: categories.count) { row in
                Task { await save(row) }
            }
        }
        .sheet(item: $editing) { cat in
            ProductCategoryEditSheet(category: cat, defaultSortOrder: cat.sort_order) { row in
                Task { await save(row) }
            }
        }
        .alert("Delete Product Category", isPresented: .init(
            get: { toDelete != nil },
            set: { if !$0 { toDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { toDelete = nil }
            Button("Delete", role: .destructive) {
                if let c = toDelete {
                    Task { await delete(c.id) }
                }
            }
        } message: {
            Text("Delete \"\(toDelete?.name ?? "")\"? Items in this category will become Uncategorized.")
        }
        .overlay(alignment: .bottom) { toastOverlay }
        .task { await load() }
    }

    private func row(_ cat: ProductCategoryRow) -> some View {
        Button { editing = cat } label: {
            HStack(spacing: 12) {
                Image(systemName: cat.icon)
                    .font(.neueCorp(14))
                    .foregroundStyle(AVIATheme.warning)
                    .frame(width: 38, height: 38)
                    .background(AVIATheme.warning.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 3) {
                    Text(cat.name)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("#\(cat.sort_order) · \(cat.id)")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .contextMenu {
            Button { editing = cat } label: { Label("Edit", systemImage: "pencil") }
            if cat.id != "uncategorized" {
                Button(role: .destructive) { toDelete = cat } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var addButton: some View {
        Button { showingAdd = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text("Add Product Category")
                    .font(.neueCaptionMedium)
            }
            .foregroundStyle(AVIATheme.aviaWhite)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(AVIATheme.primaryGradient)
            .clipShape(.rect(cornerRadius: 11))
        }
    }

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

    private func load() async {
        isLoading = true
        categories = await SupabaseService.shared.fetchProductCategories()
        isLoading = false
    }

    private func save(_ row: ProductCategoryRow) async {
        let ok = await SupabaseService.shared.upsertProductCategory(row)
        if ok {
            successMessage = "Product category saved"
            await load()
            await CatalogDataManager.shared.loadAll()
        } else {
            errorMessage = "Failed to save product category"
        }
    }

    private func delete(_ id: String) async {
        let ok = await SupabaseService.shared.deleteProductCategory(id: id)
        if ok {
            successMessage = "Product category deleted"
            await load()
            await CatalogDataManager.shared.loadAll()
        } else {
            errorMessage = "Failed to delete product category"
        }
    }
}

private struct ProductCategoryEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let category: ProductCategoryRow?
    let defaultSortOrder: Int
    let onSave: (ProductCategoryRow) -> Void

    @State private var idText: String = ""
    @State private var name: String = ""
    @State private var icon: String = "square.stack.3d.down.right.fill"
    @State private var sortOrder: Int = 0
    @State private var imageURL: String = ""
    @State private var iconSearch: String = ""

    private var isNew: Bool { category == nil }

    private static let iconLibrary: [String] = [
        "square.grid.2x2.fill", "square.stack.3d.down.right.fill", "drop.fill",
        "spigot.fill", "shower.fill", "bathtub.fill", "sink.fill", "stove.fill",
        "lightbulb.fill", "lightswitch.on.fill", "fan.fill", "wind",
        "rectangle.split.2x1.fill", "door.left.hand.open", "cabinet.fill",
        "countertop.fill", "refrigerator.fill", "dishwasher.fill",
        "paintpalette.fill", "paintbrush.fill", "hammer.fill",
        "wrench.and.screwdriver.fill", "bolt.fill", "leaf.fill",
        "square.grid.3x3.fill", "rectangle.fill", "shippingbox.fill"
    ]

    private var filtered: [String] {
        if iconSearch.isEmpty { return Self.iconLibrary }
        return Self.iconLibrary.filter { $0.localizedStandardContains(iconSearch) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    BentoCard(cornerRadius: 11) {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader("Basic Info")
                            if isNew {
                                fieldRow("ID (snake_case)") {
                                    TextField("e.g. internal_tile", text: $idText)
                                        .font(.neueCaption)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                }
                            } else {
                                fieldRow("ID (locked)") {
                                    Text(idText)
                                        .font(.neueCaption)
                                        .foregroundStyle(AVIATheme.textTertiary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            fieldRow("Display Name") {
                                TextField("Internal Tile", text: $name).font(.neueCaption)
                            }
                            fieldRow("Sort Order") {
                                TextField("0", value: $sortOrder, format: .number)
                                    .font(.neueCaption)
                                    .keyboardType(.numberPad)
                            }
                        }
                        .padding(.vertical, 14)
                    }

                    BentoCard(cornerRadius: 11) {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader("Icon")
                            HStack(spacing: 12) {
                                Image(systemName: icon)
                                    .font(.neueCorp(20))
                                    .foregroundStyle(AVIATheme.warning)
                                    .frame(width: 56, height: 56)
                                    .background(AVIATheme.warning.opacity(0.12))
                                    .clipShape(.rect(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Selected")
                                        .font(.neueCaption2)
                                        .foregroundStyle(AVIATheme.textTertiary)
                                    Text(icon)
                                        .font(.neueCaptionMedium)
                                        .foregroundStyle(AVIATheme.textPrimary)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14)

                            TextField("Search icons...", text: $iconSearch)
                                .font(.neueCaption)
                                .padding(10)
                                .background(AVIATheme.surfaceElevated)
                                .clipShape(.rect(cornerRadius: 6))
                                .padding(.horizontal, 14)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 8)], spacing: 8) {
                                ForEach(filtered, id: \.self) { sym in
                                    Button { icon = sym } label: {
                                        Image(systemName: sym)
                                            .font(.neueCorp(16))
                                            .foregroundStyle(icon == sym ? AVIATheme.aviaWhite : AVIATheme.textSecondary)
                                            .frame(width: 44, height: 44)
                                            .background(icon == sym ? AVIATheme.warning : AVIATheme.surfaceElevated)
                                            .clipShape(.rect(cornerRadius: 9))
                                    }
                                }
                            }
                            .padding(.horizontal, 14)

                            TextField("Custom SF Symbol", text: $icon)
                                .font(.neueCaption)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(10)
                                .background(AVIATheme.surfaceElevated)
                                .clipShape(.rect(cornerRadius: 6))
                                .padding(.horizontal, 14)
                        }
                        .padding(.vertical, 14)
                    }

                    BentoCard(cornerRadius: 11) {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader("Cover Image (optional)")
                            AdminImagePickerField(
                                label: "",
                                imageURL: $imageURL,
                                folder: "product-categories",
                                itemId: idText.isEmpty ? "category" : idText
                            )
                        }
                        .padding(.vertical, 14)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(AVIATheme.background)
            .navigationTitle(isNew ? "New Product Category" : "Edit Product Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedId = idText.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedImage = imageURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedId.isEmpty, !trimmedName.isEmpty, !trimmedIcon.isEmpty else { return }
                        let row = ProductCategoryRow(
                            id: trimmedId,
                            name: trimmedName,
                            icon: trimmedIcon,
                            sort_order: sortOrder,
                            image_url: trimmedImage.isEmpty ? nil : trimmedImage
                        )
                        onSave(row)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(idText.isEmpty || name.isEmpty || icon.isEmpty)
                }
            }
        }
        .onAppear { populate() }
        .presentationDetents([.large])
    }

    private func populate() {
        if let category {
            idText = category.id
            name = category.name
            icon = category.icon
            sortOrder = category.sort_order
            imageURL = category.image_url ?? ""
        } else {
            sortOrder = defaultSortOrder
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.neueCaptionMedium)
            .foregroundStyle(AVIATheme.textSecondary)
            .textCase(.uppercase)
            .kerning(0.5)
            .padding(.horizontal, 14)
    }

    private func fieldRow(_ label: String, @ViewBuilder field: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
            field()
                .padding(10)
                .background(AVIATheme.surfaceElevated)
                .clipShape(.rect(cornerRadius: 6))
        }
        .padding(.horizontal, 14)
    }
}
