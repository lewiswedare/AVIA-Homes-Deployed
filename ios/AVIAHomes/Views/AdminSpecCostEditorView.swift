import SwiftUI

struct AdminSpecCostEditorView: View {
    @State private var viewModel = AdminCatalogViewModel()
    @State private var searchText = ""
    @State private var selectedCategory: String = "all"
    @State private var costEdits: [String: SpecItemCostEdit] = [:]
    @State private var isSaving = false
    @State private var successMessage: String?
    @State private var errorMessage: String?

    struct SpecItemCostEdit {
        var volosCost: String
        var messinaCost: String
        var portobelloCost: String
        var volosToMessinaCost: String
        var volosToPortobelloCost: String
        var messinaToPortobelloCost: String
    }

    private var filteredItems: [SpecItemFlatRow] {
        var items = viewModel.specItems
        if selectedCategory != "all" {
            items = items.filter { $0.category_id == selectedCategory }
        }
        if !searchText.isEmpty {
            items = items.filter { $0.name.localizedStandardContains(searchText) }
        }
        return items
    }

    private var groupedItems: [(category: String, categoryId: String, items: [SpecItemFlatRow])] {
        let grouped = Dictionary(grouping: filteredItems, by: { $0.category_id })
        return viewModel.specCategoryOrder.compactMap { cat in
            guard let items = grouped[cat.id], !items.isEmpty else { return nil }
            return (category: cat.name, categoryId: cat.id, items: items.sorted { ($0.sort_order ?? 0) < ($1.sort_order ?? 0) })
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                categoryFilter
                statsBar

                if viewModel.isLoading {
                    ProgressView()
                        .tint(AVIATheme.teal)
                        .padding(.vertical, 60)
                } else if groupedItems.isEmpty {
                    AdminEmptyState(
                        icon: "dollarsign.circle",
                        title: "No Spec Items",
                        subtitle: "Add spec items first before setting prices"
                    )
                } else {
                    ForEach(groupedItems, id: \.categoryId) { group in
                        costCategorySection(group.category, items: group.items)
                    }

                    saveButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .navigationTitle("Cost Library")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search spec items...")
        .task {
            await viewModel.loadSpecItems()
            populateCostEdits()
        }
        .overlay(alignment: .bottom) { toastOverlay }
    }

    private var headerCard: some View {
        BentoCard(cornerRadius: 16) {
            HStack(spacing: 14) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.neueCorpMedium(18))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(AVIATheme.tealGradient)
                    .clipShape(.rect(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Spec Item Pricing")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Set base costs and upgrade costs for each tier. All prices in AUD.")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(16)
        }
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
                .background(selectedCategory == id ? AVIATheme.teal : AVIATheme.cardBackground)
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
            AdminMiniStat(value: "\(viewModel.specItems.count)", label: "Items", color: AVIATheme.teal)
            let pricedCount = viewModel.specItems.filter { $0.volos_cost != nil || $0.messina_cost != nil || $0.portobello_cost != nil }.count
            AdminMiniStat(value: "\(pricedCount)", label: "Priced", color: AVIATheme.success)
            let unpricedCount = viewModel.specItems.count - pricedCount
            AdminMiniStat(value: "\(unpricedCount)", label: "Unpriced", color: AVIATheme.warning)
        }
    }

    private func costCategorySection(_ name: String, items: [SpecItemFlatRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name.uppercased())
                    .font(.neueCaption2Medium)
                    .kerning(1.0)
                    .foregroundStyle(AVIATheme.textTertiary)
                Spacer()
                Text("\(items.count) items")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }

            ForEach(items, id: \.id) { item in
                costItemCard(item)
            }
        }
    }

    private func costItemCard(_ item: SpecItemFlatRow) -> some View {
        BentoCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: (item.is_upgradeable ?? false) ? "arrow.up.circle.fill" : "circle.fill")
                        .font(.neueCorp(12))
                        .foregroundStyle((item.is_upgradeable ?? false) ? AVIATheme.warning : AVIATheme.teal)
                        .frame(width: 28, height: 28)
                        .background(((item.is_upgradeable ?? false) ? AVIATheme.warning : AVIATheme.teal).opacity(0.12))
                        .clipShape(Circle())

                    Text(item.name)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)

                    Spacer()

                    if item.is_upgradeable ?? false {
                        Text("UPGRADEABLE")
                            .font(.neueCorpMedium(7))
                            .foregroundStyle(AVIATheme.warning)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AVIATheme.warning.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Text("BASE COSTS")
                    .font(.neueCorpMedium(9))
                    .kerning(0.5)
                    .foregroundStyle(AVIATheme.textTertiary)

                HStack(spacing: 8) {
                    costField("Volos", text: bindCost(item.id, \.volosCost), color: AVIATheme.teal)
                    costField("Messina", text: bindCost(item.id, \.messinaCost), color: AVIATheme.warning)
                    costField("Portobello", text: bindCost(item.id, \.portobelloCost), color: Color(hex: "8B5CF6"))
                }

                if item.is_upgradeable ?? false {
                    Text("UPGRADE COSTS")
                        .font(.neueCorpMedium(9))
                        .kerning(0.5)
                        .foregroundStyle(AVIATheme.textTertiary)

                    VStack(spacing: 6) {
                        upgradeCostField("Volos \u{2192} Messina", text: bindCost(item.id, \.volosToMessinaCost))
                        upgradeCostField("Volos \u{2192} Portobello", text: bindCost(item.id, \.volosToPortobelloCost))
                        upgradeCostField("Messina \u{2192} Portobello", text: bindCost(item.id, \.messinaToPortobelloCost))
                    }
                }
            }
            .padding(14)
        }
    }

    private func costField(_ tier: String, text: Binding<String>, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(tier)
                    .font(.neueCorpMedium(9))
                    .foregroundStyle(AVIATheme.textSecondary)
            }
            HStack(spacing: 2) {
                Text("$")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                TextField("0.00", text: text)
                    .font(.neueCaption)
                    .keyboardType(.decimalPad)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(AVIATheme.surfaceElevated)
            .clipShape(.rect(cornerRadius: 6))
        }
        .frame(maxWidth: .infinity)
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

    private func bindCost(_ itemId: String, _ keyPath: WritableKeyPath<SpecItemCostEdit, String>) -> Binding<String> {
        Binding(
            get: { costEdits[itemId]?[keyPath: keyPath] ?? "" },
            set: { costEdits[itemId]?[keyPath: keyPath] = $0 }
        )
    }

    private var saveButton: some View {
        Button {
            Task { await saveCosts() }
        } label: {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Save All Pricing")
                }
            }
            .font(.neueSubheadlineMedium)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(.white)
            .background(AVIATheme.tealGradient)
            .clipShape(.rect(cornerRadius: 14))
        }
        .disabled(isSaving)
    }

    private func populateCostEdits() {
        for item in viewModel.specItems {
            costEdits[item.id] = SpecItemCostEdit(
                volosCost: item.volos_cost.map { formatCost($0) } ?? "",
                messinaCost: item.messina_cost.map { formatCost($0) } ?? "",
                portobelloCost: item.portobello_cost.map { formatCost($0) } ?? "",
                volosToMessinaCost: item.volos_to_messina_cost.map { formatCost($0) } ?? "",
                volosToPortobelloCost: item.volos_to_portobello_cost.map { formatCost($0) } ?? "",
                messinaToPortobelloCost: item.messina_to_portobello_cost.map { formatCost($0) } ?? ""
            )
        }
    }

    private func formatCost(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func saveCosts() async {
        isSaving = true
        var failures = 0
        for item in viewModel.specItems {
            guard let edit = costEdits[item.id] else { continue }
            let updated = SpecItemFlatRow(
                id: item.id,
                category_id: item.category_id,
                name: item.name,
                volos_description: item.volos_description,
                messina_description: item.messina_description,
                portobello_description: item.portobello_description,
                is_upgradeable: item.is_upgradeable,
                image_url: item.image_url,
                sort_order: item.sort_order,
                volos_cost: Double(edit.volosCost),
                messina_cost: Double(edit.messinaCost),
                portobello_cost: Double(edit.portobelloCost),
                volos_to_messina_cost: Double(edit.volosToMessinaCost),
                volos_to_portobello_cost: Double(edit.volosToPortobelloCost),
                messina_to_portobello_cost: Double(edit.messinaToPortobelloCost)
            )
            let ok = await SupabaseService.shared.updateSpecItemCosts(updated)
            if !ok { failures += 1 }
        }
        isSaving = false

        if failures == 0 {
            withAnimation { successMessage = "All pricing saved" }
            await viewModel.loadSpecItems()
            await CatalogDataManager.shared.loadAll()
        } else {
            withAnimation { errorMessage = "\(failures) item(s) failed to save" }
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let msg = successMessage {
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
                        withAnimation { successMessage = nil }
                    }
                }
        }
        if let msg = errorMessage {
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
                        withAnimation { errorMessage = nil }
                    }
                }
        }
    }
}
