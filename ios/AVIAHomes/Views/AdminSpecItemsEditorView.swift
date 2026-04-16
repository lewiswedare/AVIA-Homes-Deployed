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
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(.rect(cornerRadius: 14))
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
            SpecItemEditSheet(item: nil, categories: viewModel.specCategoryOrder) { row, tierImages in
                Task { await viewModel.saveSpecItem(row, tierImages: tierImages) }
            }
        }
        .sheet(item: $editingItem) { item in
            SpecItemEditSheet(item: item, categories: viewModel.specCategoryOrder) { row, tierImages in
                Task { await viewModel.saveSpecItem(row, tierImages: tierImages) }
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
                .foregroundStyle(selectedCategory == id ? .white : AVIATheme.textSecondary)
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

            BentoCard(cornerRadius: 14) {
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
        Button { editingItem = item } label: {
            HStack(spacing: 12) {
                Image(systemName: (item.is_upgradeable ?? false) ? "arrow.up.circle.fill" : "circle.fill")
                    .font(.neueCorp(12))
                    .foregroundStyle((item.is_upgradeable ?? false) ? AVIATheme.warning : AVIATheme.timelessBrown)
                    .frame(width: 32, height: 32)
                    .background(((item.is_upgradeable ?? false) ? AVIATheme.warning : AVIATheme.timelessBrown).opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text(item.volos_description)
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
            Button { editingItem = item } label: {
                Label("Edit", systemImage: "pencil")
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
                .foregroundStyle(.white)
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
                .foregroundStyle(.white)
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
    let onSave: (SpecItemFlatRow, [String: String]) -> Void

    @State private var itemId: String = ""
    @State private var name: String = ""
    @State private var categoryId: String = "structure"
    @State private var volosDesc: String = ""
    @State private var messinaDesc: String = ""
    @State private var portobelloDesc: String = ""
    @State private var isUpgradeable: Bool = false
    @State private var imageURL: String = ""
    @State private var sortOrder: Int = 0
    @State private var volosImageURL: String = ""
    @State private var messinaImageURL: String = ""
    @State private var portobelloImageURL: String = ""
    @State private var isLoadingTierImages: Bool = false

    // Pricing fields (upgrade costs only)
    @State private var volosToMessinaCost: String = ""
    @State private var volosToPortobelloCost: String = ""
    @State private var messinaToPortobelloCost: String = ""

    private var isNew: Bool { item == nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    BentoCard(cornerRadius: 14) {
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
                            fieldRow("Category") {
                                Picker("", selection: $categoryId) {
                                    ForEach(categories, id: \.id) { cat in
                                        Text(cat.name).tag(cat.id)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(AVIATheme.timelessBrown)
                            }
                            fieldRow("Sort Order") {
                                TextField("0", value: $sortOrder, format: .number)
                                    .font(.neueCaption)
                                    .keyboardType(.numberPad)
                            }
                            Toggle(isOn: $isUpgradeable) {
                                Text("Upgradeable")
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                            }
                            .tint(AVIATheme.warning)
                            .padding(.horizontal, 14)
                        }
                        .padding(.vertical, 14)
                    }

                    BentoCard(cornerRadius: 14) {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader("Tier Descriptions")
                            tierField("Volos", text: $volosDesc, color: AVIATheme.timelessBrown)
                            tierField("Messina", text: $messinaDesc, color: AVIATheme.warning)
                            tierField("Portobello", text: $portobelloDesc, color: Color(hex: "8B5CF6"))
                        }
                        .padding(.vertical, 14)
                    }

                    BentoCard(cornerRadius: 14) {
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

                    BentoCard(cornerRadius: 14) {
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
                                tierImageField("Portobello", imageURL: $portobelloImageURL, color: Color(hex: "8B5CF6"), tierKey: "portobello")
                            }
                        }
                        .padding(.vertical, 14)
                    }

                    if isUpgradeable {
                        BentoCard(cornerRadius: 14) {
                            VStack(alignment: .leading, spacing: 14) {
                                sectionHeader("Upgrade Costs")
                                Text("Set upgrade costs between tiers. All prices in AUD.")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                                    .padding(.horizontal, 14)

                                VStack(spacing: 6) {
                                    upgradeCostField("Volos \u{2192} Messina", text: $volosToMessinaCost)
                                    upgradeCostField("Volos \u{2192} Portobello", text: $volosToPortobelloCost)
                                    upgradeCostField("Messina \u{2192} Portobello", text: $messinaToPortobelloCost)
                                }
                                .padding(.horizontal, 14)
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
        .presentationDetents([.large])
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
                .clipShape(.rect(cornerRadius: 8))
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
                .clipShape(.rect(cornerRadius: 8))
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

    private func upgradeCostField(_ label: String, text: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 2) {
                Text("$")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                TextField("0.00", text: text)
                    .font(.neueCaption)
                    .keyboardType(.decimalPad)
                    .frame(width: 80)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(AVIATheme.surfaceElevated)
            .clipShape(.rect(cornerRadius: 6))
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
        volosDesc = item.volos_description
        messinaDesc = item.messina_description
        portobelloDesc = item.portobello_description
        isUpgradeable = item.is_upgradeable ?? false
        imageURL = item.image_url ?? ""
        sortOrder = item.sort_order ?? 0
        volosToMessinaCost = item.volos_to_messina_cost.map { formatCost($0) } ?? ""
        volosToPortobelloCost = item.volos_to_portobello_cost.map { formatCost($0) } ?? ""
        messinaToPortobelloCost = item.messina_to_portobello_cost.map { formatCost($0) } ?? ""
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
        let row = SpecItemFlatRow(
            id: isNew ? itemId : (item?.id ?? itemId),
            category_id: categoryId,
            name: name,
            volos_description: volosDesc,
            messina_description: messinaDesc,
            portobello_description: portobelloDesc,
            is_upgradeable: isUpgradeable,
            image_url: imageURL.isEmpty ? nil : imageURL,
            sort_order: sortOrder,
            volos_to_messina_cost: Double(volosToMessinaCost),
            volos_to_portobello_cost: Double(volosToPortobelloCost),
            messina_to_portobello_cost: Double(messinaToPortobelloCost)
        )
        var tierImages: [String: String] = [:]
        if !volosImageURL.isEmpty { tierImages["volos"] = volosImageURL }
        if !messinaImageURL.isEmpty { tierImages["messina"] = messinaImageURL }
        if !portobelloImageURL.isEmpty { tierImages["portobello"] = portobelloImageURL }
        onSave(row, tierImages)
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
        .clipShape(.rect(cornerRadius: 12))
    }
}

extension SpecItemFlatRow: Identifiable {}
