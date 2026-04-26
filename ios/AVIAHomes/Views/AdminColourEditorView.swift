import SwiftUI
import PhotosUI

struct AdminColourEditorView: View {
    @State private var viewModel = AdminCatalogViewModel()
    @State private var searchText = ""
    @State private var selectedSection: SelectionSection? = nil
    @State private var editingCategory: ColourCategory?
    @State private var showingAddSheet = false
    @State private var categoryToDelete: ColourCategory?

    private var filteredCategories: [ColourCategory] {
        var cats = viewModel.colourCategories
        if let section = selectedSection {
            cats = cats.filter { $0.section == section }
        }
        if !searchText.isEmpty {
            cats = cats.filter {
                $0.name.localizedStandardContains(searchText) ||
                $0.options.contains { $0.name.localizedStandardContains(searchText) }
            }
        }
        return cats
    }

    private var exteriorCats: [ColourCategory] { filteredCategories.filter { $0.section == .exterior } }
    private var interiorCats: [ColourCategory] { filteredCategories.filter { $0.section == .interior } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                sectionFilter
                statsBar

                if viewModel.isLoading {
                    ProgressView()
                        .tint(AVIATheme.timelessBrown)
                        .padding(.vertical, 60)
                } else if filteredCategories.isEmpty {
                    AdminEmptyState(
                        icon: "paintpalette",
                        title: "No Colour Categories",
                        subtitle: "Add your first colour category to get started"
                    )
                } else {
                    if !exteriorCats.isEmpty && selectedSection != .interior {
                        colourSection("Exterior", categories: exteriorCats)
                    }
                    if !interiorCats.isEmpty && selectedSection != .exterior {
                        colourSection("Interior", categories: interiorCats)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .navigationTitle("Colour Categories")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search colours...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddSheet = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            ColourCategoryEditSheet(category: nil) { cat in
                let idx = viewModel.colourCategories.count
                Task { await viewModel.saveColourCategory(cat, sortOrder: idx) }
            }
        }
        .sheet(item: $editingCategory) { cat in
            ColourCategoryEditSheet(category: cat) { updated in
                let idx = viewModel.colourCategories.firstIndex(where: { $0.id == updated.id }) ?? 0
                Task { await viewModel.saveColourCategory(updated, sortOrder: idx) }
            }
        }
        .alert("Delete Category", isPresented: .init(
            get: { categoryToDelete != nil },
            set: { if !$0 { categoryToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { categoryToDelete = nil }
            Button("Delete", role: .destructive) {
                if let cat = categoryToDelete {
                    Task { await viewModel.deleteColourCategory(id: cat.id) }
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(categoryToDelete?.name ?? "")\"? All colour options within it will also be removed.")
        }
        .overlay(alignment: .bottom) { toastOverlay }
        .task { await viewModel.loadColourCategories() }
    }

    private var sectionFilter: some View {
        HStack(spacing: 6) {
            sectionChip("All", section: nil)
            sectionChip("Exterior", section: .exterior)
            sectionChip("Interior", section: .interior)
            Spacer()
        }
    }

    private func sectionChip(_ label: String, section: SelectionSection?) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) { selectedSection = section }
        } label: {
            Text(label)
                .font(.neueCaptionMedium)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .foregroundStyle(selectedSection == section ? AVIATheme.aviaWhite : AVIATheme.textSecondary)
                .background(selectedSection == section ? AVIATheme.timelessBrown : AVIATheme.cardBackground)
                .clipShape(Capsule())
                .overlay {
                    if selectedSection != section {
                        Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                    }
                }
        }
    }

    private var statsBar: some View {
        HStack(spacing: 12) {
            AdminMiniStat(value: "\(viewModel.colourCategories.count)", label: "Categories", color: AVIATheme.timelessBrown)
            AdminMiniStat(value: "\(viewModel.colourCategories.flatMap(\.options).count)", label: "Options", color: AVIATheme.warning)
            AdminMiniStat(value: "\(viewModel.colourCategories.flatMap(\.options).filter(\.isUpgrade).count)", label: "Upgrades", color: AVIATheme.heritageBlue)
        }
    }

    private func colourSection(_ title: String, categories: [ColourCategory]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
                Text("\(categories.count) categories")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }

            ForEach(categories, id: \.id) { category in
                colourCategoryCard(category)
            }
        }
    }

    private func colourCategoryCard(_ category: ColourCategory) -> some View {
        Button { editingCategory = category } label: {
            BentoCard(cornerRadius: 11) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Image(systemName: category.icon)
                            .font(.neueCorp(12))
                            .foregroundStyle(AVIATheme.timelessBrown)
                            .frame(width: 32, height: 32)
                            .background(AVIATheme.timelessBrown.opacity(0.12))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.name)
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                            if let note = category.note {
                                Text(note)
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        if let tiers = category.applicableTiers, !tiers.isEmpty {
                            HStack(spacing: 2) {
                                ForEach(tiers.sorted(), id: \.self) { t in
                                    Text(String(t.prefix(1)).uppercased())
                                        .font(.neueCorpMedium(8))
                                        .foregroundStyle(AVIATheme.aviaWhite)
                                        .frame(width: 16, height: 16)
                                        .background(AVIATheme.timelessBrown)
                                        .clipShape(Circle())
                                }
                            }
                        }

                        Text("\(category.options.count)")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AVIATheme.surfaceElevated)
                            .clipShape(Capsule())

                        Image(systemName: "chevron.right")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }

                    ScrollView(.horizontal) {
                        HStack(spacing: 4) {
                            ForEach(category.options.prefix(12), id: \.id) { option in
                                Circle()
                                    .fill(Color(hex: option.hexColor))
                                    .frame(width: 22, height: 22)
                                    .overlay {
                                        Circle().stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                                    }
                            }
                            if category.options.count > 12 {
                                Text("+\(category.options.count - 12)")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                                    .padding(.leading, 4)
                            }
                        }
                    }
                    .contentMargins(.horizontal, 0)
                    .scrollIndicators(.hidden)
                }
                .padding(14)
            }
        }
        .contextMenu {
            Button { editingCategory = category } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) { categoryToDelete = category } label: {
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

struct ColourCategoryEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let category: ColourCategory?
    let onSave: (ColourCategory) -> Void

    @State private var catId: String = ""
    @State private var name: String = ""
    @State private var icon: String = "paintbrush.fill"
    @State private var section: SelectionSection = .exterior
    @State private var note: String = ""
    @State private var imageURL: String = ""
    @State private var options: [EditableColourOption] = []
    @State private var defaultCostText: String = ""
    @State private var showingAddOption = false
    @State private var applicableTiers: Set<String> = []

    private var isNew: Bool { category == nil }

    private var catalog: CatalogDataManager { CatalogDataManager.shared }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    BentoCard(cornerRadius: 11) {
                        VStack(alignment: .leading, spacing: 14) {
                            editSectionHeader("Category Details")
                            if isNew {
                                editFieldRow("ID (snake_case)") {
                                    TextField("e.g. roof", text: $catId)
                                        .font(.neueCaption)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                }
                            }
                            editFieldRow("Name") {
                                TextField("Category name", text: $name)
                                    .font(.neueCaption)
                            }
                            editFieldRow("SF Symbol Icon") {
                                TextField("e.g. house.fill", text: $icon)
                                    .font(.neueCaption)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                            editFieldRow("Section") {
                                Picker("", selection: $section) {
                                    Text("Exterior").tag(SelectionSection.exterior)
                                    Text("Interior").tag(SelectionSection.interior)
                                }
                                .pickerStyle(.segmented)
                            }
                            editFieldRow("Note (Optional)") {
                                TextField("e.g. Colorbond steel roofing", text: $note)
                                    .font(.neueCaption)
                            }
                            editFieldRow("Default Option Cost (AUD)") {
                                HStack(spacing: 4) {
                                    Text("$")
                                        .font(.neueCaptionMedium)
                                        .foregroundStyle(AVIATheme.textSecondary)
                                    TextField("0.00", text: $defaultCostText)
                                        .font(.neueCaption)
                                        .keyboardType(.decimalPad)
                                }
                            }
                            AdminImagePickerField(
                                label: "Category Image (Optional)",
                                imageURL: $imageURL,
                                folder: "colours",
                                itemId: isNew ? catId : (category?.id ?? catId)
                            )

                            editSectionHeader("Tier Availability")

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Applicable Tiers")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                                Text("Leave empty for all tiers")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary.opacity(0.7))
                                HStack(spacing: 8) {
                                    ForEach(SpecTier.allCases) { tier in
                                        let isActive = applicableTiers.contains(tier.rawValue)
                                        Button {
                                            withAnimation(.spring(response: 0.2)) {
                                                if isActive {
                                                    applicableTiers.remove(tier.rawValue)
                                                } else {
                                                    applicableTiers.insert(tier.rawValue)
                                                }
                                            }
                                        } label: {
                                            Text(tier.displayName)
                                                .font(.neueCaption2Medium)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .foregroundStyle(isActive ? AVIATheme.aviaWhite : AVIATheme.textSecondary)
                                                .background(isActive ? AVIATheme.timelessBrown : AVIATheme.surfaceElevated)
                                                .clipShape(Capsule())
                                                .overlay {
                                                    if !isActive {
                                                        Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                                                    }
                                                }
                                        }
                                    }

                                    Spacer()

                                    Button {
                                        withAnimation(.spring(response: 0.2)) {
                                            if applicableTiers.count == SpecTier.allCases.count {
                                                applicableTiers.removeAll()
                                            } else {
                                                applicableTiers = Set(SpecTier.allCases.map(\.rawValue))
                                            }
                                        }
                                    } label: {
                                        Text(applicableTiers.count == SpecTier.allCases.count ? "Clear" : "All")
                                            .font(.neueCaption2Medium)
                                            .foregroundStyle(AVIATheme.timelessBrown)
                                    }
                                }
                            }
                            .padding(.horizontal, 14)

                            // NOTE: Spec-item linkage is now managed from the
                            // Spec Items editor via `spec_to_colour_mapping`
                            // (many-to-many). The old single-picker was misleading
                            // and the backing column is scheduled for removal.
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Linked Spec Items")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                                Text("Managed in Catalog → Spec Items. Open a spec item and toggle the colour categories it unlocks.")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary.opacity(0.7))
                            }
                            .padding(.horizontal, 14)
                        }
                        .padding(.vertical, 14)
                    }

                    BentoCard(cornerRadius: 11) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                editSectionHeader("Colour Options (\(options.count))")
                                Spacer()
                                Button { addNewOption() } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(AVIATheme.timelessBrown)
                                }
                                .padding(.trailing, 14)
                            }

                            if options.isEmpty {
                                Text("No colour options yet. Tap + to add.")
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textTertiary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                            } else {
                                ForEach($options) { $option in
                                    colourOptionEditor(option: $option)
                                }
                            }
                        }
                        .padding(.vertical, 14)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(AVIATheme.background)
            .navigationTitle(isNew ? "New Colour Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.isEmpty || (isNew && catId.isEmpty))
                }
            }
        }
        .onAppear { populateFields() }
        .presentationDetents([.large])
    }

    private func editSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.neueCaptionMedium)
            .foregroundStyle(AVIATheme.textSecondary)
            .textCase(.uppercase)
            .kerning(0.5)
            .padding(.horizontal, 14)
    }

    private func editFieldRow(_ label: String, @ViewBuilder field: () -> some View) -> some View {
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

    private func colourOptionEditor(option: Binding<EditableColourOption>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                if let url = URL(string: option.wrappedValue.imageURL), !option.wrappedValue.imageURL.isEmpty {
                    Color(.secondarySystemBackground)
                        .frame(width: 36, height: 36)
                        .overlay {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    Circle()
                                        .fill(Color(hex: option.wrappedValue.hexColor))
                                        .padding(4)
                                }
                            }
                            .allowsHitTesting(false)
                        }
                        .clipShape(.rect(cornerRadius: 5))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                        }
                } else {
                    Circle()
                        .fill(Color(hex: option.wrappedValue.hexColor))
                        .frame(width: 28, height: 28)
                        .overlay { Circle().stroke(AVIATheme.surfaceBorder, lineWidth: 1) }
                }

                VStack(spacing: 4) {
                    TextField("Name", text: option.name)
                        .font(.neueCaption)
                    HStack(spacing: 6) {
                        TextField("#Hex", text: option.hexColor)
                            .font(.neueCaption2)
                            .textInputAutocapitalization(.never)
                            .frame(maxWidth: 80)
                        TextField("Brand", text: option.brand)
                            .font(.neueCaption2)
                            .frame(maxWidth: 80)
                        Toggle("", isOn: option.isUpgrade)
                            .labelsHidden()
                            .scaleEffect(0.7)
                        Text("Upgrade")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                    HStack(spacing: 4) {
                        Text("$")
                            .font(.neueCaption2Medium)
                            .foregroundStyle(AVIATheme.textTertiary)
                        TextField("Cost", text: option.cost)
                            .font(.neueCaption2)
                            .keyboardType(.decimalPad)
                            .frame(maxWidth: 80)
                        Text("AUD")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    withAnimation { options.removeAll { $0.id == option.wrappedValue.id } }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AVIATheme.destructive.opacity(0.6))
                }
            }

            HStack(spacing: 6) {
                AdminCompactImagePicker(
                    imageURL: option.imageURL,
                    folder: "colours/options",
                    itemId: option.wrappedValue.id
                )
            }
            .padding(8)
            .background(AVIATheme.surfaceElevated)
            .clipShape(.rect(cornerRadius: 5))

            tierAvailabilityRow(option: option)
            optionApplicableTiersRow(option: option)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private func optionApplicableTiersRow(option: Binding<EditableColourOption>) -> some View {
        HStack(spacing: 6) {
            Text("Tier Filter")
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)

            ForEach(SpecTier.allCases) { tier in
                let isActive = option.wrappedValue.optionApplicableTiers.contains(tier.rawValue)
                Button {
                    withAnimation(.spring(response: 0.2)) {
                        if isActive {
                            option.wrappedValue.optionApplicableTiers.remove(tier.rawValue)
                        } else {
                            option.wrappedValue.optionApplicableTiers.insert(tier.rawValue)
                        }
                    }
                } label: {
                    Text(String(tier.displayName.prefix(1)))
                        .font(.neueCorpMedium(10))
                        .frame(width: 26, height: 22)
                        .foregroundStyle(isActive ? AVIATheme.aviaWhite : AVIATheme.textTertiary)
                        .background(isActive ? AVIATheme.heritageBlue : Color.clear)
                        .clipShape(.rect(cornerRadius: 4))
                        .overlay {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isActive ? AVIATheme.heritageBlue : AVIATheme.surfaceBorder, lineWidth: 1)
                        }
                }
            }

            Spacer(minLength: 0)

            Button {
                withAnimation(.spring(response: 0.2)) {
                    let allTiers = Set(SpecTier.allCases.map(\.rawValue))
                    if option.wrappedValue.optionApplicableTiers == allTiers {
                        option.wrappedValue.optionApplicableTiers.removeAll()
                    } else {
                        option.wrappedValue.optionApplicableTiers = allTiers
                    }
                }
            } label: {
                Text("All")
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.heritageBlue)
            }
        }
        .padding(8)
        .background(AVIATheme.surfaceElevated)
        .clipShape(.rect(cornerRadius: 5))
    }

    private func tierAvailabilityRow(option: Binding<EditableColourOption>) -> some View {
        HStack(spacing: 6) {
            Text("Spec Ranges")
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)

            ForEach(SpecTier.allCases) { tier in
                let isActive = option.wrappedValue.availableTiers.contains(tier.imageKeySuffix)
                Button {
                    withAnimation(.spring(response: 0.2)) {
                        if isActive {
                            option.wrappedValue.availableTiers.remove(tier.imageKeySuffix)
                        } else {
                            option.wrappedValue.availableTiers.insert(tier.imageKeySuffix)
                        }
                    }
                } label: {
                    Text(String(tier.displayName.prefix(1)))
                        .font(.neueCorpMedium(10))
                        .frame(width: 26, height: 22)
                        .foregroundStyle(isActive ? AVIATheme.aviaWhite : AVIATheme.textTertiary)
                        .background(isActive ? AVIATheme.timelessBrown : Color.clear)
                        .clipShape(.rect(cornerRadius: 4))
                        .overlay {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isActive ? AVIATheme.timelessBrown : AVIATheme.surfaceBorder, lineWidth: 1)
                        }
                }
            }

            Spacer(minLength: 0)

            Button {
                withAnimation(.spring(response: 0.2)) {
                    let allTiers: Set<String> = Set(SpecTier.allCases.map(\.imageKeySuffix))
                    if option.wrappedValue.availableTiers == allTiers {
                        option.wrappedValue.availableTiers.removeAll()
                    } else {
                        option.wrappedValue.availableTiers = allTiers
                    }
                }
            } label: {
                Text("All")
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.timelessBrown)
            }
        }
        .padding(8)
        .background(AVIATheme.surfaceElevated)
        .clipShape(.rect(cornerRadius: 5))
    }

    private func addNewOption() {
        let newId = "\(catId.isEmpty ? "opt" : catId)\(options.count + 1)"
        options.append(EditableColourOption(id: newId, name: "", hexColor: "CCCCCC", brand: "", isUpgrade: false, imageURL: "", availableTiers: [], cost: "", optionApplicableTiers: []))
    }

    private func populateFields() {
        guard let category else { return }
        catId = category.id
        name = category.name
        icon = category.icon
        section = category.section
        note = category.note ?? ""
        imageURL = category.imageURL ?? ""
        defaultCostText = category.defaultOptionCost.map { String(format: "%.2f", $0) } ?? ""
        applicableTiers = Set(category.applicableTiers ?? [])
        options = category.options.map {
            EditableColourOption(id: $0.id, name: $0.name, hexColor: $0.hexColor, brand: $0.brand ?? "", isUpgrade: $0.isUpgrade, imageURL: $0.imageURL ?? "", availableTiers: $0.availableTiers, cost: $0.cost.map { String(format: "%.2f", $0) } ?? "", optionApplicableTiers: Set($0.applicableTiers ?? []))
        }
    }

    private func save() {
        let colourOptions = options.filter { !$0.name.isEmpty }.map {
            ColourOption(id: $0.id, name: $0.name, hexColor: $0.hexColor, brand: $0.brand.isEmpty ? nil : $0.brand, isUpgrade: $0.isUpgrade, imageURL: $0.imageURL.isEmpty ? nil : $0.imageURL, availableTiers: $0.availableTiers, cost: Double($0.cost), applicableTiers: $0.optionApplicableTiers.isEmpty ? nil : Array($0.optionApplicableTiers).sorted())
        }
        let result = ColourCategory(
            id: isNew ? catId : (category?.id ?? catId),
            name: name,
            icon: icon,
            section: section,
            options: colourOptions,
            note: note.isEmpty ? nil : note,
            imageURL: imageURL.isEmpty ? nil : imageURL,
            defaultOptionCost: Double(defaultCostText),
            applicableTiers: applicableTiers.isEmpty ? nil : Array(applicableTiers).sorted(),
            // Deprecated: spec-item linkage now lives in spec_to_colour_mapping.
            // Preserve the existing value if editing (pass it through) so the field
            // isn't accidentally cleared during partial edits.
            specItemId: category?.specItemId
        )
        onSave(result)
        dismiss()
    }
}

struct EditableColourOption: Identifiable {
    let id: String
    var name: String
    var hexColor: String
    var brand: String
    var isUpgrade: Bool
    var imageURL: String
    var availableTiers: Set<String>
    var cost: String
    var optionApplicableTiers: Set<String>
}
