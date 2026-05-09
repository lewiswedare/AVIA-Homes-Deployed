import SwiftUI

struct AdminSpecCategoriesEditorView: View {
    @State private var viewModel = AdminCatalogViewModel()
    @State private var editingCategory: SpecCategoryRow?
    @State private var showingAddSheet = false
    @State private var categoryToDelete: SpecCategoryRow?
    @State private var searchText = ""

    private var sortedCategories: [SpecCategoryRow] {
        let cats = viewModel.specCategoriesDB.sorted { $0.sort_order < $1.sort_order }
        if searchText.isEmpty { return cats }
        return cats.filter { $0.name.localizedStandardContains(searchText) }
    }

    private func itemCount(for id: String) -> Int {
        viewModel.specItems.filter { $0.category_id == id }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                statsBar

                if viewModel.isLoading && viewModel.specCategoriesDB.isEmpty {
                    ProgressView()
                        .tint(AVIATheme.timelessBrown)
                        .padding(.vertical, 60)
                } else if viewModel.specCategoriesDB.isEmpty {
                    AdminEmptyState(
                        icon: "square.stack.3d.up",
                        title: "No Spec Categories",
                        subtitle: "Add your first spec category, or seed the defaults to get started."
                    )
                    Button {
                        Task { await viewModel.seedDefaultSpecCategories() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.neueSubheadlineMedium)
                            Text("Seed Default Categories")
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
                    BentoCard(cornerRadius: 11) {
                        VStack(spacing: 0) {
                            ForEach(Array(sortedCategories.enumerated()), id: \.element.id) { index, cat in
                                categoryRow(cat)
                                if index < sortedCategories.count - 1 {
                                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 60)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .navigationTitle("Spec Categories")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search categories...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddSheet = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            SpecCategoryEditSheet(
                category: nil,
                defaultSortOrder: viewModel.specCategoriesDB.count
            ) { id, name, icon, sort in
                Task { await viewModel.saveSpecCategory(id: id, name: name, icon: icon, sortOrder: sort) }
            }
        }
        .sheet(item: $editingCategory) { cat in
            SpecCategoryEditSheet(
                category: cat,
                defaultSortOrder: cat.sort_order
            ) { id, name, icon, sort in
                Task { await viewModel.saveSpecCategory(id: id, name: name, icon: icon, sortOrder: sort) }
            }
        }
        .alert("Delete Category", isPresented: .init(
            get: { categoryToDelete != nil },
            set: { if !$0 { categoryToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { categoryToDelete = nil }
            Button("Delete", role: .destructive) {
                if let cat = categoryToDelete {
                    Task { await viewModel.deleteSpecCategory(id: cat.id) }
                }
            }
        } message: {
            let cat = categoryToDelete
            let count = cat.map { itemCount(for: $0.id) } ?? 0
            if count > 0 {
                Text("\(cat?.name ?? "") has \(count) item(s). Move or delete those items first.")
            } else {
                Text("Delete \"\(cat?.name ?? "")\"? This cannot be undone.")
            }
        }
        .overlay(alignment: .bottom) { toastOverlay }
        .task { await viewModel.loadSpecItems() }
    }

    private var statsBar: some View {
        HStack(spacing: 12) {
            AdminMiniStat(value: "\(viewModel.specCategoriesDB.count)", label: "Categories", color: AVIATheme.timelessBrown)
            AdminMiniStat(value: "\(viewModel.specItems.count)", label: "Total Items", color: AVIATheme.warning)
            AdminMiniStat(
                value: "\(viewModel.specCategoriesDB.filter { itemCount(for: $0.id) == 0 }.count)",
                label: "Empty",
                color: AVIATheme.heritageBlue
            )
        }
    }

    private func categoryRow(_ cat: SpecCategoryRow) -> some View {
        Button { editingCategory = cat } label: {
            HStack(spacing: 12) {
                Image(systemName: cat.icon)
                    .font(.neueCorp(14))
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .frame(width: 38, height: 38)
                    .background(AVIATheme.timelessBrown.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 3) {
                    Text(cat.name)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    HStack(spacing: 6) {
                        Text("#\(cat.sort_order)")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                        Text("•")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                        Text(cat.id)
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                let count = itemCount(for: cat.id)
                Text("\(count) \(count == 1 ? "item" : "items")")
                    .font(.neueCaption2Medium)
                    .foregroundStyle(count == 0 ? AVIATheme.textTertiary : AVIATheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AVIATheme.surfaceElevated)
                    .clipShape(Capsule())

                Image(systemName: "chevron.right")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .contextMenu {
            Button { editingCategory = cat } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) { categoryToDelete = cat } label: {
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

// MARK: - Edit Sheet

private struct SpecCategoryEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let category: SpecCategoryRow?
    let defaultSortOrder: Int
    let onSave: (_ id: String, _ name: String, _ icon: String, _ sortOrder: Int) -> Void

    @State private var idText: String = ""
    @State private var name: String = ""
    @State private var icon: String = "square.grid.2x2.fill"
    @State private var sortOrder: Int = 0
    @State private var iconSearch: String = ""

    private var isNew: Bool { category == nil }

    private static let iconLibrary: [String] = [
        "doc.text.fill", "hammer.fill", "thermometer.medium", "map.fill",
        "square.split.bottomrightquarter.fill", "house.fill", "rectangle.split.2x1.fill",
        "door.left.hand.open", "lightbulb.fill", "sofa.fill", "fork.knife",
        "shower.fill", "washer.fill", "square.grid.3x3.fill", "paintbrush.fill",
        "archivebox.fill", "paintpalette.fill", "leaf.fill", "car.fill",
        "checkmark.seal.fill", "shield.lefthalf.filled", "bed.double.fill",
        "tv.fill", "wifi", "bolt.fill", "drop.fill", "flame.fill",
        "wind", "snowflake", "wrench.and.screwdriver.fill", "key.fill",
        "lock.fill", "ruler.fill", "pencil", "scissors", "cabinet.fill",
        "countertop.fill", "stove.fill", "oven.fill", "refrigerator.fill",
        "dishwasher.fill", "microwave.fill", "toilet.fill", "bathtub.fill",
        "sink.fill", "window.vertical.open", "lightswitch.on.fill",
        "fan.fill", "speaker.wave.2.fill", "camera.fill", "tree.fill",
        "building.2.fill", "square.stack.3d.up.fill", "square.grid.2x2",
    ]

    private var filteredIcons: [String] {
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
                                    TextField("e.g. exterior_finishes", text: $idText)
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
                                TextField("Category name", text: $name)
                                    .font(.neueCaption)
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
                                    .foregroundStyle(AVIATheme.timelessBrown)
                                    .frame(width: 56, height: 56)
                                    .background(AVIATheme.timelessBrown.opacity(0.12))
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

                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 48), spacing: 8)],
                                spacing: 8
                            ) {
                                ForEach(filteredIcons, id: \.self) { sym in
                                    Button { icon = sym } label: {
                                        Image(systemName: sym)
                                            .font(.neueCorp(16))
                                            .foregroundStyle(icon == sym ? AVIATheme.aviaWhite : AVIATheme.textSecondary)
                                            .frame(width: 44, height: 44)
                                            .background(icon == sym ? AVIATheme.timelessBrown : AVIATheme.surfaceElevated)
                                            .clipShape(.rect(cornerRadius: 9))
                                    }
                                }
                            }
                            .padding(.horizontal, 14)

                            Text("Use any SF Symbol name. Type a custom symbol below if it's not in the library.")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
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
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(AVIATheme.background)
            .navigationTitle(isNew ? "New Category" : "Edit Category")
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
                        guard !trimmedId.isEmpty, !trimmedName.isEmpty, !trimmedIcon.isEmpty else { return }
                        onSave(trimmedId, trimmedName, trimmedIcon, sortOrder)
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

extension SpecCategoryRow: Identifiable {}
