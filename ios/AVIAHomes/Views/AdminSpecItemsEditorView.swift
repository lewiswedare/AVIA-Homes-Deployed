import SwiftUI
import PhotosUI

struct AdminSpecItemsEditorView: View {
    @State private var viewModel = AdminCatalogViewModel()
    @State private var searchText = ""
    @State private var selectedCategory: String = "all"
    @State private var editingItem: SpecItemFlatRow?
    @State private var showingAddSheet = false
    @State private var itemToDelete: SpecItemFlatRow?

    private var filteredItems: [SpecItemFlatRow] {
        var items = viewModel.specItems
        if selectedCategory != "all" {
            items = items.filter { $0.category_id == selectedCategory }
        }
        if !searchText.isEmpty {
            items = items.filter {
                $0.name.localizedStandardContains(searchText) ||
                $0.volos_description.localizedStandardContains(searchText) ||
                $0.messina_description.localizedStandardContains(searchText) ||
                $0.portobello_description.localizedStandardContains(searchText)
            }
        }
        return items
    }

    private var groupedItems: [(category: String, items: [SpecItemFlatRow])] {
        let grouped = Dictionary(grouping: filteredItems, by: { $0.category_id })
        return viewModel.specCategoryOrder.compactMap { cat in
            guard let items = grouped[cat.id], !items.isEmpty else { return nil }
            return (category: cat.name, items: items.sorted { ($0.sort_order ?? 0) < ($1.sort_order ?? 0) })
        }
    }

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
                        icon: "list.clipboard",
                        title: "No Spec Items",
                        subtitle: "Add your first spec item or seed from defaults"
                    )
                    Button {
                        Task { await viewModel.seedSpecItemsFromDefaults() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.neueSubheadlineMedium)
                            Text("Seed Default Spec Items")
                                .font(.neueSubheadlineMedium)
                        }
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(.rect(cornerRadius: 11))
                    }
                    .disabled(viewModel.isLoading)
                } else {
                    ForEach(groupedItems, id: \.category) { group in
                        specCategorySection(group.category, items: group.items)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .navigationTitle("Spec Items")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search spec items...")
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
                Task { await viewModel.saveSpecItem(row, tierImages: tierImages, productSwatches: swatches) }
            }
        }
        .sheet(item: $editingItem) { item in
            SpecItemEditSheet(item: item, categories: viewModel.specCategoryOrder) { row, tierImages, swatches in
                Task { await viewModel.saveSpecItem(row, tierImages: tierImages, productSwatches: swatches) }
            }
        }
        .alert("Delete Item", isPresented: .init(
            get: { itemToDelete != nil },
            set: { if !$0 { itemToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { itemToDelete = nil }
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    Task { await viewModel.deleteSpecItem(id: item.id) }
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(itemToDelete?.name ?? "")\"? This cannot be undone.")
        }
        .overlay(alignment: .bottom) { toastOverlay }
        .task { await viewModel.loadSpecItems() }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                filterChip("All", id: "all")
                ForEach(viewModel.specCategoryOrder, id: \.id) { cat in
                    filterChip(cat.name, id: cat.id)
                }
            }
        }
        .contentMargins(.horizontal, 0)
        .scrollIndicators(.hidden)
    }

    private func filterChip(_ label: String, id: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) { selectedCategory = id }
        } label: {
            Text(label)
                .font(.neueCaptionMedium)
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
        HStack(spacing: 12) {
            AdminMiniStat(value: "\(viewModel.specItems.count)", label: "Total Items", color: AVIATheme.timelessBrown)
            AdminMiniStat(value: "\(viewModel.specItems.filter { $0.is_upgradeable ?? false }.count)", label: "Upgradeable", color: AVIATheme.warning)
            AdminMiniStat(value: "\(Set(viewModel.specItems.map { $0.category_id }).count)", label: "Categories", color: AVIATheme.success)
        }
    }

    private func specCategorySection(_ name: String, items: [SpecItemFlatRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
                Text("\(items.count) items")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }

            BentoCard(cornerRadius: 11) {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        specItemRow(item)
                        if index < items.count - 1 {
                            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 52)
                        }
                    }
                }
            }
        }
    }

    private func specItemRow(_ item: SpecItemFlatRow) -> some View {
        NavigationLink {
            AdminSpecProductsView(specItemId: item.id, specItemName: item.name)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "shippingbox.fill")
                    .font(.neueCorp(12))
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .frame(width: 32, height: 32)
                    .background(AVIATheme.timelessBrown.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Manage products & colours")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    editingItem = item
                } label: {
                    Image(systemName: "pencil.circle")
                        .font(.neueCorp(16))
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                .buttonStyle(.plain)

                Image(systemName: "chevron.right")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { editingItem = item } label: {
                Label("Edit slot details", systemImage: "pencil")
            }
            Button(role: .destructive) { itemToDelete = item } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let msg = viewModel.successMessage {
            Text(msg)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.aviaWhite)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
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
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
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
}

struct SpecItemEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: SpecItemFlatRow?
    let categories: [(id: String, name: String, icon: String)]
    let onSave: (SpecItemFlatRow, [String: String], [EditableColourOption]) -> Void

    @State private var itemId: String = ""
    @State private var name: String = ""
    @State private var categoryId: String = "structure"
    @State private var productCategoryId: String = "uncategorized"
    @State private var supplier: String = ""
    @State private var dimensions: String = ""
    @State private var itemDescription: String = ""
    @State private var skuText: String = ""
    @State private var productCategories: [ProductCategoryRow] = []
    @State private var volosDesc: String = ""
    @State private var messinaDesc: String = ""
    @State private var portobelloDesc: String = ""
    @State private var isUpgradeable: Bool = false
    @State private var isFixedInclusion: Bool = false
    @State private var imageURL: String = ""
    @State private var sortOrder: Int = 0
    @State private var volosImageURL: String = ""
    @State private var messinaImageURL: String = ""
    @State private var portobelloImageURL: String = ""
    @State private var isLoadingTierImages: Bool = false

    // Per-product colour swatches — stored as a dedicated ColourCategory per spec item.
    @State private var swatches: [EditableColourOption] = []

    private var isNew: Bool { item == nil }

    static func productColourCategoryId(for specItemId: String) -> String {
        "spec_\(specItemId)_colours"
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
                                    TextField("e.g. ceiling_height", text: $itemId)
                                        .font(.neueCaption)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                }
                            }
                            fieldRow("Name") {
                                TextField("Item name", text: $name)
                                    .font(.neueCaption)
                            }
                            fieldRow("Product Category") {
                                Picker("", selection: $productCategoryId) {
                                    if productCategories.isEmpty {
                                        Text("Uncategorized").tag("uncategorized")
                                    }
                                    ForEach(productCategories, id: \.id) { pc in
                                        Text(pc.name).tag(pc.id)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(AVIATheme.warning)
                            }
                            fieldRow("Supplier") {
                                TextField("e.g. Beaumont Tiles", text: $supplier).font(.neueCaption)
                            }
                            fieldRow("Dimensions") {
                                TextField("e.g. 600 × 600 mm", text: $dimensions).font(.neueCaption)
                            }
                            fieldRow("Item SKU") {
                                TextField("Optional master SKU", text: $skuText)
                                    .font(.neueCaption)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                            }
                            fieldRow("Description") {
                                TextField("Short description", text: $itemDescription, axis: .vertical)
                                    .font(.neueCaption)
                                    .lineLimit(2...5)
                            }
                            fieldRow("Sort Order") {
                                TextField("0", value: $sortOrder, format: .number)
                                    .font(.neueCaption)
                                    .keyboardType(.numberPad)
                            }
                            Toggle(isOn: $isFixedInclusion) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Fixed inclusion (no variants)")
                                        .font(.neueCaptionMedium)
                                        .foregroundStyle(AVIATheme.textPrimary)
                                    Text("End user can’t choose anything — shown as Included only")
                                        .font(.neueCaption2)
                                        .foregroundStyle(AVIATheme.textTertiary)
                                }
                            }
                            .tint(AVIATheme.heritageBlue)
                            .padding(.horizontal, 14)
                            .onChange(of: isFixedInclusion) { _, newValue in
                                if newValue {
                                    isUpgradeable = false
                                    swatches.removeAll()
                                }
                            }

                            if !isFixedInclusion {
                                Toggle(isOn: $isUpgradeable) {
                                    Text("Upgradeable")
                                        .font(.neueCaptionMedium)
                                        .foregroundStyle(AVIATheme.textPrimary)
                                }
                                .tint(AVIATheme.warning)
                                .padding(.horizontal, 14)
                            }
                        }
                        .padding(.vertical, 14)
                    }

                    BentoCard(cornerRadius: 11) {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader("Tier Descriptions")
                            tierField("Volos", text: $volosDesc, color: AVIATheme.timelessBrown)
                            tierField("Messina", text: $messinaDesc, color: AVIATheme.warning)
                            tierField("Portobello", text: $portobelloDesc, color: AVIATheme.heritageBlue)
                        }
                        .padding(.vertical, 14)
                    }

                    BentoCard(cornerRadius: 11) {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader("Base Image (Optional)")
                            AdminImagePickerField(
                                label: "Default / Base Image",
                                imageURL: $imageURL,
                                folder: "spec-items",
                                itemId: isNew ? itemId : (item?.id ?? itemId)
                            )
                        }
                        .padding(.vertical, 14)
                    }

                    BentoCard(cornerRadius: 11) {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader("Tier-Specific Images")
                            Text("Upload a different image for each spec range. These override the base image when viewing a specific tier.")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                                .padding(.horizontal, 14)

                            if isLoadingTierImages {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .tint(AVIATheme.timelessBrown)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            } else {
                                tierImageField("Volos", imageURL: $volosImageURL, color: AVIATheme.timelessBrown, tierKey: "volos")
                                tierImageField("Messina", imageURL: $messinaImageURL, color: AVIATheme.warning, tierKey: "messina")
                                tierImageField("Portobello", imageURL: $portobelloImageURL, color: AVIATheme.heritageBlue, tierKey: "portobello")
                            }
                        }
                        .padding(.vertical, 14)
                    }

                    if isUpgradeable && !isFixedInclusion {
                        BentoCard(cornerRadius: 11) {
                            VStack(alignment: .leading, spacing: 10) {
                                sectionHeader("Upgrade Pricing")
                                Text("Upgrade prices are now set per variant + room from the Variant editor (Room Assignments). Open the variant for this item to set cost & inclusion per (room, range).")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                                    .padding(.horizontal, 14)
                            }
                            .padding(.vertical, 14)
                        }
                    }

                    if !isFixedInclusion {
                        BentoCard(cornerRadius: 11) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    sectionHeader("Colours")
                                    Spacer()
                                    Button { addSwatch() } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(AVIATheme.timelessBrown)
                                    }
                                    .padding(.trailing, 14)
                                }
                                Text("Add colour swatches the client can choose from for this product. Toggle Upgrade for swatches that cost extra. Leave empty if this product has no colour variants.")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                                    .padding(.horizontal, 14)

                                if swatches.isEmpty {
                                    Text("No colour swatches yet. Tap + to add one.")
                                        .font(.neueCaption)
                                        .foregroundStyle(AVIATheme.textTertiary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                } else {
                                    ForEach($swatches) { $swatch in
                                        swatchEditor(swatch: $swatch)
                                    }
                                }
                            }
                            .padding(.vertical, 14)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(AVIATheme.background)
            .navigationTitle(isNew ? "New Spec Item" : "Edit Spec Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.isEmpty || (isNew && itemId.isEmpty))
                }
            }
        }
        .onAppear { populateFields() }
        .task {
            productCategories = await SupabaseService.shared.fetchProductCategories()
            if !productCategories.contains(where: { $0.id == productCategoryId }) {
                productCategoryId = productCategories.first?.id ?? "uncategorized"
            }
        }
        .presentationDetents([.large])
    }

    private func swatchEditor(swatch: Binding<EditableColourOption>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(hex: swatch.wrappedValue.hexColor))
                    .frame(width: 28, height: 28)
                    .overlay { Circle().stroke(AVIATheme.surfaceBorder, lineWidth: 1) }

                VStack(spacing: 6) {
                    TextField("Colour name", text: swatch.name)
                        .font(.neueCaption)
                    HStack(spacing: 6) {
                        TextField("#Hex", text: swatch.hexColor)
                            .font(.neueCaption2)
                            .textInputAutocapitalization(.never)
                            .frame(maxWidth: 80)
                        TextField("Brand / finish", text: swatch.brand)
                            .font(.neueCaption2)
                    }
                    HStack(spacing: 6) {
                        Toggle("", isOn: swatch.isUpgrade)
                            .labelsHidden()
                            .scaleEffect(0.7)
                        Text("Upgrade")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                        if swatch.wrappedValue.isUpgrade {
                            Text("$")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                            TextField("Cost", text: swatch.cost)
                                .font(.neueCaption2)
                                .keyboardType(.decimalPad)
                                .frame(maxWidth: 70)
                            Text("AUD")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                        Spacer(minLength: 0)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    withAnimation { swatches.removeAll { $0.id == swatch.wrappedValue.id } }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AVIATheme.destructive.opacity(0.6))
                }
            }

            AdminCompactImagePicker(
                imageURL: swatch.imageURL,
                folder: "spec-items/swatches",
                itemId: swatch.wrappedValue.id
            )
        }
        .padding(10)
        .background(AVIATheme.surfaceElevated)
        .clipShape(.rect(cornerRadius: 8))
        .padding(.horizontal, 14)
    }

    private func addSwatch() {
        let baseId = isNew ? itemId : (item?.id ?? itemId)
        let prefix = baseId.isEmpty ? "swatch" : "\(baseId)_swatch"
        let newId = "\(prefix)_\(swatches.count + 1)"
        swatches.append(EditableColourOption(
            id: newId,
            name: "",
            hexColor: "CCCCCC",
            brand: "",
            isUpgrade: false,
            imageURL: "",
            availableTiers: Set(SpecTier.allCases.map(\.imageKeySuffix)),
            cost: "",
            optionApplicableTiers: []
        ))
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

    private func tierField(_ tier: String, text: Binding<String>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(tier)
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.textSecondary)
            }
            TextField("Description for \(tier)", text: text, axis: .vertical)
                .font(.neueCaption)
                .lineLimit(2...4)
                .padding(10)
                .background(AVIATheme.surfaceElevated)
                .clipShape(.rect(cornerRadius: 6))
        }
        .padding(.horizontal, 14)
    }

    private func tierImageField(_ tier: String, imageURL: Binding<String>, color: Color, tierKey: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(tier)
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.textSecondary)
            }
            .padding(.horizontal, 14)

            AdminImagePickerField(
                label: "\(tier) Image",
                imageURL: imageURL,
                folder: "spec-items/\(tierKey)",
                itemId: isNew ? itemId : (item?.id ?? itemId)
            )
        }
    }

    private func formatCost(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func populateFields() {
        guard let item else { return }
        itemId = item.id
        name = item.name
        categoryId = item.category_id
        productCategoryId = item.product_category_id ?? "uncategorized"
        supplier = item.supplier ?? ""
        dimensions = item.dimensions ?? ""
        itemDescription = item.description ?? ""
        skuText = item.sku ?? ""
        volosDesc = item.volos_description
        messinaDesc = item.messina_description
        portobelloDesc = item.portobello_description
        isUpgradeable = item.is_upgradeable ?? false
        isFixedInclusion = item.is_fixed_inclusion ?? false
        imageURL = item.image_url ?? ""
        sortOrder = item.sort_order ?? 0
        // Load per-product swatches from the dedicated colour category (id: spec_<itemId>_colours).
        let perProductId = SpecItemEditSheet.productColourCategoryId(for: item.id)
        if let cat = CatalogDataManager.shared.allColourCategories.first(where: { $0.id == perProductId }) {
            swatches = cat.options.map {
                EditableColourOption(
                    id: $0.id,
                    name: $0.name,
                    hexColor: $0.hexColor,
                    brand: $0.brand ?? "",
                    isUpgrade: $0.isUpgrade,
                    imageURL: $0.imageURL ?? "",
                    availableTiers: $0.availableTiers,
                    cost: $0.cost.map { String(format: "%.2f", $0) } ?? "",
                    optionApplicableTiers: Set($0.applicableTiers ?? [])
                )
            }
        } else {
            swatches = []
        }
        loadTierImages()
    }

    private func loadTierImages() {
        isLoadingTierImages = true
        Task {
            if let row = await SupabaseService.shared.fetchSpecItemImageRow(specItemId: item?.id ?? "") {
                if let tiers = row.tier_images {
                    volosImageURL = tiers["volos"] ?? ""
                    messinaImageURL = tiers["messina"] ?? ""
                    portobelloImageURL = tiers["portobello"] ?? ""
                }
            }
            isLoadingTierImages = false
        }
    }

    private func save() {
        let trimmedSupplier = supplier.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDimensions = dimensions.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = itemDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSku = skuText.trimmingCharacters(in: .whitespacesAndNewlines)
        let row = SpecItemFlatRow(
            id: isNew ? itemId : (item?.id ?? itemId),
            category_id: categoryId,
            name: name,
            volos_description: volosDesc,
            messina_description: messinaDesc,
            portobello_description: portobelloDesc,
            is_upgradeable: isFixedInclusion ? false : isUpgradeable,
            is_fixed_inclusion: isFixedInclusion,
            image_url: imageURL.isEmpty ? nil : imageURL,
            sort_order: sortOrder,
            volos_to_messina_cost: item?.volos_to_messina_cost,
            volos_to_portobello_cost: item?.volos_to_portobello_cost,
            messina_to_portobello_cost: item?.messina_to_portobello_cost,
            product_category_id: productCategoryId.isEmpty ? nil : productCategoryId,
            supplier: trimmedSupplier.isEmpty ? nil : trimmedSupplier,
            dimensions: trimmedDimensions.isEmpty ? nil : trimmedDimensions,
            description: trimmedDescription.isEmpty ? nil : trimmedDescription,
            sku: trimmedSku.isEmpty ? nil : trimmedSku
        )
        var tierImages: [String: String] = [:]
        if !volosImageURL.isEmpty { tierImages["volos"] = volosImageURL }
        if !messinaImageURL.isEmpty { tierImages["messina"] = messinaImageURL }
        if !portobelloImageURL.isEmpty { tierImages["portobello"] = portobelloImageURL }
        let payload = isFixedInclusion ? [] : swatches.filter { !$0.name.isEmpty }
        onSave(row, tierImages, payload)
        dismiss()
    }
}

struct AdminMiniStat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.neueCorpMedium(20))
                .foregroundStyle(color)
            Text(label)
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 10))
    }
}

extension SpecItemFlatRow: Identifiable {}
