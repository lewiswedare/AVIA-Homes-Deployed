import SwiftUI

private let kRangeIds: [String] = ["volos", "messina", "portobello"]
private let kRangeNames: [String: String] = ["volos": "Volos", "messina": "Messina", "portobello": "Portobello"]
private let kRangeColors: [String: Color] = [
    "volos": AVIATheme.timelessBrown,
    "messina": AVIATheme.warning,
    "portobello": AVIATheme.heritageBlue
]

// MARK: - Products list inside a spec slot

struct AdminSpecProductsView: View {
    let specItemId: String
    let specItemName: String

    @State private var products: [SpecProductRow] = []
    @State private var memberships: [SpecRangeItemProductRow] = []
    @State private var isLoading = false
    @State private var editingProduct: SpecProductRow?
    @State private var showingAdd = false
    @State private var productToDelete: SpecProductRow?
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                headerCard

                if isLoading {
                    ProgressView()
                        .tint(AVIATheme.timelessBrown)
                        .padding(.vertical, 60)
                } else if products.isEmpty {
                    AdminEmptyState(
                        icon: "shippingbox",
                        title: "No Products",
                        subtitle: "Add the first product for this slot. Each product can be Included or an Upgrade in different ranges."
                    )
                    addButton
                } else {
                    ForEach(products) { product in
                        productCard(product)
                    }
                    addButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
            .padding(.top, 12)
        }
        .background(AVIATheme.background)
        .navigationTitle(specItemName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AdminSpecProductEditorView(
                specItemId: specItemId,
                product: nil,
                memberships: [],
                onSaved: { Task { await reload() } }
            )
        }
        .sheet(item: $editingProduct) { product in
            AdminSpecProductEditorView(
                specItemId: specItemId,
                product: product,
                memberships: memberships.filter { $0.product_id == product.id },
                onSaved: { Task { await reload() } }
            )
        }
        .alert("Delete Product", isPresented: .init(
            get: { productToDelete != nil },
            set: { if !$0 { productToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { productToDelete = nil }
            Button("Delete", role: .destructive) {
                if let p = productToDelete {
                    Task { await delete(p) }
                }
            }
        } message: {
            Text("Delete \"\(productToDelete?.name ?? "")\"? This removes its colours and range memberships and cannot be undone.")
        }
        .overlay(alignment: .bottom) { toastOverlay }
        .task { await reload() }
    }

    // MARK: - Subviews

    private var headerCard: some View {
        BentoCard(cornerRadius: 11) {
            HStack(spacing: 14) {
                Image(systemName: "shippingbox.fill")
                    .font(.neueCorpMedium(16))
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .frame(width: 44, height: 44)
                    .background(AVIATheme.timelessBrown.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Products in this slot")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Tag each product with which ranges include it, and what it costs to upgrade.")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                Spacer()
            }
            .padding(14)
        }
    }

    private func productCard(_ product: SpecProductRow) -> some View {
        let mems = memberships.filter { $0.product_id == product.id }
        return Button { editingProduct = product } label: {
            BentoCard(cornerRadius: 11) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        if let url = product.image_url, !url.isEmpty {
                            AsyncImage(url: URL(string: url)) { phase in
                                switch phase {
                                case .success(let img): img.resizable().scaledToFill()
                                default:
                                    Color(.secondarySystemBackground)
                                        .overlay {
                                            Image(systemName: "photo")
                                                .foregroundStyle(AVIATheme.textTertiary)
                                        }
                                }
                            }
                            .frame(width: 56, height: 56)
                            .clipShape(.rect(cornerRadius: 8))
                        } else {
                            Color(.secondarySystemBackground)
                                .frame(width: 56, height: 56)
                                .overlay {
                                    Image(systemName: "shippingbox")
                                        .foregroundStyle(AVIATheme.textTertiary)
                                }
                                .clipShape(.rect(cornerRadius: 8))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(product.name)
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                            if let brand = product.brand, !brand.isEmpty {
                                Text(brand)
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }

                    HStack(spacing: 6) {
                        ForEach(kRangeIds, id: \.self) { rangeId in
                            rangeBadge(rangeId: rangeId, membership: mems.first { $0.range_id == rangeId })
                        }
                    }
                }
                .padding(14)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { editingProduct = product } label: { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) { productToDelete = product } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func rangeBadge(rangeId: String, membership: SpecRangeItemProductRow?) -> some View {
        let inclusion = ProductRangeInclusion(rawValue: membership?.inclusion_override ?? "unavailable") ?? .unavailable
        let color: Color = {
            switch inclusion {
            case .included: return AVIATheme.success
            case .upgrade: return AVIATheme.warning
            case .unavailable: return AVIATheme.textTertiary
            }
        }()
        let icon: String = {
            switch inclusion {
            case .included: return "checkmark.circle.fill"
            case .upgrade: return "arrow.up.circle.fill"
            case .unavailable: return "minus.circle"
            }
        }()
        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.neueCaption2)
                .foregroundStyle(color)
            Text(kRangeNames[rangeId] ?? rangeId)
                .font(.neueCaption2Medium)
                .foregroundStyle(color)
            if inclusion == .upgrade, let cost = membership?.upgrade_price_override, cost > 0 {
                Text("+$\(Int(cost))")
                    .font(.neueCaption2)
                    .foregroundStyle(color.opacity(0.8))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1), in: Capsule())
    }

    private var addButton: some View {
        Button { showingAdd = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text("Add Product")
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

    // MARK: - Data

    private func reload() async {
        isLoading = true
        let p = await SupabaseService.shared.fetchSpecProducts(forSpecItem: specItemId)
        let m = await SupabaseService.shared.fetchRangeItemProducts(forSpecItem: specItemId)
        products = p
        memberships = m
        isLoading = false
    }

    private func delete(_ product: SpecProductRow) async {
        let ok = await SupabaseService.shared.deleteSpecProduct(id: product.id)
        if ok {
            successMessage = "Deleted"
            await reload()
        } else {
            errorMessage = "Couldn't delete product"
        }
    }
}

// MARK: - Product editor

struct AdminSpecProductEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let specItemId: String
    let product: SpecProductRow?
    let memberships: [SpecRangeItemProductRow]
    let onSaved: () -> Void

    @State private var productId: String = ""
    @State private var name: String = ""
    @State private var brand: String = ""
    @State private var model: String = ""
    @State private var sku: String = ""
    @State private var description: String = ""
    @State private var imageURL: String = ""
    @State private var dimensions: String = ""
    @State private var sortOrder: Int = 0

    @State private var rangeRows: [EditableProductRangeMembership] = []
    @State private var colours: [EditableProductColour] = []
    @State private var initialColourIds: Set<String> = []

    @State private var isSaving = false
    @State private var saveError: String?

    private var isNew: Bool { product == nil }
    private var canSave: Bool { !name.isEmpty && (!isNew || !productId.isEmpty) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    basicInfoCard
                    imageCard
                    rangeMatrixCard
                    coloursCard
                    if let saveError {
                        Text(saveError)
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.destructive)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(AVIATheme.background)
            .navigationTitle(isNew ? "New Product" : "Edit Product")
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
                            .disabled(!canSave)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear { populate() }
    }

    // MARK: - Cards

    private var basicInfoCard: some View {
        BentoCard(cornerRadius: 11) {
            VStack(alignment: .leading, spacing: 12) {
                cardHeader("Basic Info")
                if isNew {
                    field("ID (snake_case)") {
                        TextField("e.g. caesarstone_cloudburst", text: $productId)
                            .font(.neueCaption)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
                field("Product Name") {
                    TextField("e.g. Caesarstone Cloudburst", text: $name)
                        .font(.neueCaption)
                }
                HStack(spacing: 8) {
                    field("Brand") {
                        TextField("Caesarstone", text: $brand).font(.neueCaption)
                    }
                    field("Model") {
                        TextField("4011", text: $model).font(.neueCaption)
                    }
                }
                .padding(.horizontal, 14)
                HStack(spacing: 8) {
                    field("SKU") {
                        TextField("Optional", text: $sku).font(.neueCaption)
                    }
                    field("Sort Order") {
                        TextField("0", value: $sortOrder, format: .number)
                            .font(.neueCaption)
                            .keyboardType(.numberPad)
                    }
                }
                .padding(.horizontal, 14)
                field("Description") {
                    TextField("Short description", text: $description, axis: .vertical)
                        .font(.neueCaption)
                        .lineLimit(2...5)
                }
                field("Dimensions / Spec Notes") {
                    TextField("e.g. 20mm thickness", text: $dimensions)
                        .font(.neueCaption)
                }
            }
            .padding(.vertical, 14)
        }
    }

    private var imageCard: some View {
        BentoCard(cornerRadius: 11) {
            VStack(alignment: .leading, spacing: 12) {
                cardHeader("Product Image")
                AdminImagePickerField(
                    label: "Hero Image",
                    imageURL: $imageURL,
                    folder: "spec-products",
                    itemId: isNew ? productId : (product?.id ?? "")
                )
            }
            .padding(.vertical, 14)
        }
    }

    private var rangeMatrixCard: some View {
        BentoCard(cornerRadius: 11) {
            VStack(alignment: .leading, spacing: 12) {
                cardHeader("Range Availability")
                Text("For each range, choose whether this product is included for free, available as an upgrade, or not offered.")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                    .padding(.horizontal, 14)

                VStack(spacing: 10) {
                    ForEach($rangeRows) { $row in
                        rangeRow(row: $row)
                    }
                }
                .padding(.horizontal, 14)
            }
            .padding(.vertical, 14)
        }
    }

    private func rangeRow(row: Binding<EditableProductRangeMembership>) -> some View {
        let rangeId = row.wrappedValue.rangeId
        let color = kRangeColors[rangeId] ?? AVIATheme.timelessBrown
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 10, height: 10)
                Text(kRangeNames[rangeId] ?? rangeId)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
            }
            Picker("", selection: row.inclusion) {
                ForEach(ProductRangeInclusion.allCases, id: \.self) { inc in
                    Text(inc.displayName).tag(inc)
                }
            }
            .pickerStyle(.segmented)

            if row.wrappedValue.inclusion == .upgrade {
                HStack(spacing: 6) {
                    Text("Upgrade cost").font(.neueCaption2).foregroundStyle(AVIATheme.textSecondary)
                    Spacer()
                    Text("$").font(.neueCaption2).foregroundStyle(AVIATheme.textTertiary)
                    TextField("0.00", text: row.upgradeCost)
                        .font(.neueCaption)
                        .keyboardType(.decimalPad)
                        .frame(width: 100)
                        .padding(8)
                        .background(AVIATheme.surfaceElevated)
                        .clipShape(.rect(cornerRadius: 6))
                    Text("AUD").font(.neueCaption2).foregroundStyle(AVIATheme.textTertiary)
                }
            }

            if row.wrappedValue.inclusion == .included {
                Toggle(isOn: row.isDefault) {
                    Text("Default product for this range")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                .tint(color)
            }
        }
        .padding(10)
        .background(AVIATheme.surfaceElevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 8))
    }

    private var coloursCard: some View {
        BentoCard(cornerRadius: 11) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    cardHeader("Colours")
                    Spacer()
                    Button { addColour() } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AVIATheme.timelessBrown)
                    }
                    .padding(.trailing, 14)
                }
                Text("Each colour swatch can carry an extra cost on top of the range upgrade price.")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                    .padding(.horizontal, 14)

                if colours.isEmpty {
                    Text("No colours yet. Tap + to add the first one.")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textTertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                } else {
                    ForEach($colours) { $colour in
                        colourRow(colour: $colour)
                    }
                }
            }
            .padding(.vertical, 14)
        }
    }

    private func colourRow(colour: Binding<EditableProductColour>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(hex: colour.wrappedValue.hex))
                    .frame(width: 28, height: 28)
                    .overlay { Circle().stroke(AVIATheme.surfaceBorder, lineWidth: 1) }

                VStack(spacing: 6) {
                    TextField("Colour name", text: colour.name)
                        .font(.neueCaption)
                    HStack(spacing: 6) {
                        TextField("#Hex", text: colour.hex)
                            .font(.neueCaption2)
                            .textInputAutocapitalization(.never)
                            .frame(maxWidth: 80)
                        Text("$").font(.neueCaption2).foregroundStyle(AVIATheme.textTertiary)
                        TextField("Extra cost", text: colour.extraCost)
                            .font(.neueCaption2)
                            .keyboardType(.decimalPad)
                            .frame(maxWidth: 80)
                        Text("AUD").font(.neueCaption2).foregroundStyle(AVIATheme.textTertiary)
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 6) {
                        Toggle("", isOn: colour.isDefault)
                            .labelsHidden()
                            .scaleEffect(0.7)
                        Text("Default colour")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                        Spacer(minLength: 0)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    withAnimation { colours.removeAll { $0.id == colour.wrappedValue.id } }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AVIATheme.destructive.opacity(0.6))
                }
            }

            AdminCompactImagePicker(
                imageURL: colour.imageURL,
                folder: "spec-products/colours",
                itemId: colour.wrappedValue.id
            )
        }
        .padding(10)
        .background(AVIATheme.surfaceElevated)
        .clipShape(.rect(cornerRadius: 8))
        .padding(.horizontal, 14)
    }

    // MARK: - Helpers

    private func cardHeader(_ title: String) -> some View {
        Text(title)
            .font(.neueCaptionMedium)
            .foregroundStyle(AVIATheme.textSecondary)
            .textCase(.uppercase)
            .kerning(0.5)
            .padding(.horizontal, 14)
    }

    private func field(_ label: String, @ViewBuilder field: () -> some View) -> some View {
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

    private func addColour() {
        let baseId = isNew ? productId : (product?.id ?? "")
        let safeBase = baseId.isEmpty ? "swatch" : "\(baseId)_c"
        let newId = "\(safeBase)_\(colours.count + 1)"
        colours.append(EditableProductColour(
            id: newId,
            name: "",
            hex: "CCCCCC",
            imageURL: "",
            isDefault: colours.isEmpty,
            extraCost: "",
            sortOrder: colours.count
        ))
    }

    private func populate() {
        if rangeRows.isEmpty {
            rangeRows = kRangeIds.map { rangeId in
                if let m = memberships.first(where: { $0.range_id == rangeId }) {
                    let inc = ProductRangeInclusion(rawValue: m.inclusion_override ?? "unavailable") ?? .unavailable
                    return EditableProductRangeMembership(
                        rangeId: rangeId,
                        inclusion: inc,
                        upgradeCost: m.upgrade_price_override.map { String(format: "%.2f", $0) } ?? "",
                        isDefault: m.is_default ?? false
                    )
                } else {
                    return EditableProductRangeMembership(
                        rangeId: rangeId,
                        inclusion: .unavailable,
                        upgradeCost: "",
                        isDefault: false
                    )
                }
            }
        }
        guard let product else { return }
        productId = product.id
        name = product.name
        brand = product.brand ?? ""
        model = product.model ?? ""
        sku = product.sku ?? ""
        description = product.description ?? ""
        imageURL = product.image_url ?? ""
        dimensions = product.dimensions ?? ""
        sortOrder = product.sort_order ?? 0
        Task {
            let existing = await SupabaseService.shared.fetchSpecProductColours(forProduct: product.id)
            colours = existing.map {
                EditableProductColour(
                    id: $0.id,
                    name: $0.name,
                    hex: $0.hex ?? "CCCCCC",
                    imageURL: $0.image_url ?? "",
                    isDefault: $0.is_default ?? false,
                    extraCost: $0.extra_cost.map { String(format: "%.2f", $0) } ?? "",
                    sortOrder: $0.sort_order ?? 0
                )
            }
            initialColourIds = Set(existing.map(\.id))
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        saveError = nil

        let finalId = isNew ? productId : (product?.id ?? productId)
        let row = SpecProductRow(
            id: finalId,
            spec_item_id: specItemId,
            brand: brand.isEmpty ? nil : brand,
            model: model.isEmpty ? nil : model,
            sku: sku.isEmpty ? nil : sku,
            name: name,
            description: description.isEmpty ? nil : description,
            image_url: imageURL.isEmpty ? nil : imageURL,
            dimensions: dimensions.isEmpty ? nil : dimensions,
            is_active: true,
            sort_order: sortOrder
        )

        let svc = SupabaseService.shared
        guard await svc.upsertSpecProduct(row) else {
            saveError = svc.lastUpsertError ?? "Couldn't save product"
            return
        }

        // Save range memberships — upsert chosen ranges, delete rows for "unavailable".
        for membership in rangeRows {
            switch membership.inclusion {
            case .unavailable:
                _ = await svc.deleteRangeItemProduct(rangeId: membership.rangeId, specItemId: specItemId, productId: finalId)
            case .included, .upgrade:
                let cost: Double? = membership.inclusion == .upgrade ? Double(membership.upgradeCost) : nil
                let mRow = SpecRangeItemProductRow(
                    id: nil,
                    range_id: membership.rangeId,
                    spec_item_id: specItemId,
                    product_id: finalId,
                    is_default: membership.isDefault,
                    inclusion_override: membership.inclusion.rawValue,
                    upgrade_price_override: cost,
                    sort_order: 0
                )
                if !(await svc.upsertRangeItemProduct(mRow)) {
                    saveError = svc.lastUpsertError ?? "Couldn't save range membership"
                    return
                }
            }
        }

        // Save colours — upsert all, delete removed.
        let kept = Set(colours.map(\.id))
        let removed = initialColourIds.subtracting(kept)
        if !removed.isEmpty {
            _ = await svc.deleteSpecProductColours(ids: Array(removed))
        }
        if !colours.isEmpty {
            let colourRows: [SpecProductColourRow] = colours.enumerated().map { idx, c in
                SpecProductColourRow(
                    id: c.id,
                    product_id: finalId,
                    name: c.name,
                    hex: c.hex,
                    image_url: c.imageURL.isEmpty ? nil : c.imageURL,
                    is_default: c.isDefault,
                    is_active: true,
                    sort_order: idx,
                    extra_cost: Double(c.extraCost)
                )
            }.filter { !$0.name.isEmpty }
            if !colourRows.isEmpty, !(await svc.upsertSpecProductColours(colourRows)) {
                saveError = svc.lastUpsertError ?? "Couldn't save colours"
                return
            }
        }

        onSaved()
        dismiss()
    }
}
