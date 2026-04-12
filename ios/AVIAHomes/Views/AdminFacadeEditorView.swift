import SwiftUI
import PhotosUI

struct AdminFacadeEditorView: View {
    @State private var viewModel = AdminCatalogViewModel()
    @State private var searchText = ""
    @State private var filterPricing: String = "all"
    @State private var editingFacade: Facade?
    @State private var showingAddSheet = false
    @State private var facadeToDelete: Facade?

    private var filteredFacades: [Facade] {
        var facades = viewModel.facades
        switch filterPricing {
        case "included":
            facades = facades.filter { $0.pricing.isIncluded }
        case "upgrade":
            facades = facades.filter { !$0.pricing.isIncluded }
        default:
            break
        }
        if !searchText.isEmpty {
            facades = facades.filter {
                $0.name.localizedStandardContains(searchText) ||
                $0.style.localizedStandardContains(searchText) ||
                $0.description.localizedStandardContains(searchText)
            }
        }
        return facades.sorted { $0.name < $1.name }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                pricingFilter
                statsBar

                if viewModel.isLoading {
                    ProgressView()
                        .tint(AVIATheme.teal)
                        .padding(.vertical, 60)
                } else if filteredFacades.isEmpty {
                    AdminEmptyState(
                        icon: "building.columns",
                        title: "No Facades",
                        subtitle: "Add your first facade to get started"
                    )
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredFacades, id: \.id) { facade in
                            facadeCard(facade)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .navigationTitle("Facades")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search facades...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddSheet = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AVIATheme.teal)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            FacadeEditSheet(facade: nil) { facade in
                Task { await viewModel.saveFacade(facade) }
            }
        }
        .sheet(item: $editingFacade) { facade in
            FacadeEditSheet(facade: facade) { updated in
                Task { await viewModel.saveFacade(updated) }
            }
        }
        .alert("Delete Facade", isPresented: .init(
            get: { facadeToDelete != nil },
            set: { if !$0 { facadeToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { facadeToDelete = nil }
            Button("Delete", role: .destructive) {
                if let facade = facadeToDelete {
                    Task { await viewModel.deleteFacade(id: facade.id) }
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(facadeToDelete?.name ?? "")\"? This cannot be undone.")
        }
        .overlay(alignment: .bottom) { toastOverlay }
        .task { await viewModel.loadFacades() }
    }

    private var pricingFilter: some View {
        HStack(spacing: 6) {
            pricingChip("All", value: "all")
            pricingChip("Included", value: "included")
            pricingChip("Upgrade", value: "upgrade")
            Spacer()
        }
    }

    private func pricingChip(_ label: String, value: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) { filterPricing = value }
        } label: {
            Text(label)
                .font(.neueCaptionMedium)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .foregroundStyle(filterPricing == value ? .white : AVIATheme.textSecondary)
                .background(filterPricing == value ? AVIATheme.teal : AVIATheme.cardBackground)
                .clipShape(Capsule())
                .overlay {
                    if filterPricing != value {
                        Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                    }
                }
        }
    }

    private var statsBar: some View {
        HStack(spacing: 12) {
            AdminMiniStat(value: "\(viewModel.facades.count)", label: "Total", color: AVIATheme.teal)
            AdminMiniStat(value: "\(viewModel.facades.filter { $0.pricing.isIncluded }.count)", label: "Included", color: AVIATheme.success)
            AdminMiniStat(value: "\(viewModel.facades.filter { !$0.pricing.isIncluded }.count)", label: "Upgrades", color: AVIATheme.warning)
        }
    }

    private func facadeCard(_ facade: Facade) -> some View {
        Button { editingFacade = facade } label: {
            BentoCard(cornerRadius: 14) {
                VStack(spacing: 0) {
                    Color(.secondarySystemBackground)
                        .frame(height: 140)
                        .overlay {
                            AsyncImage(url: URL(string: facade.heroImageURL)) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else if phase.error != nil {
                                    Image(systemName: "photo")
                                        .font(.title)
                                        .foregroundStyle(AVIATheme.textTertiary)
                                }
                            }
                            .allowsHitTesting(false)
                        }
                        .clipShape(.rect(cornerRadii: .init(topLeading: 14, topTrailing: 14)))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(facade.name)
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Spacer()
                            Text(facade.pricing.displayText)
                                .font(.neueCaption2Medium)
                                .foregroundStyle(facade.pricing.isIncluded ? AVIATheme.success : AVIATheme.warning)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background((facade.pricing.isIncluded ? AVIATheme.success : AVIATheme.warning).opacity(0.12))
                                .clipShape(Capsule())
                        }

                        Text(facade.style)
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.teal)

                        Text(facade.description)
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                            .lineLimit(2)

                        HStack(spacing: 12) {
                            facadeStat(icon: "photo.on.rectangle", value: "\(facade.galleryImageURLs.count) imgs")
                            facadeStat(icon: "list.bullet", value: "\(facade.features.count) features")
                            facadeStat(icon: "building.2", value: facade.storeys == 1 ? "Single" : "Double")
                        }
                        .padding(.top, 2)
                    }
                    .padding(12)
                }
            }
        }
        .contextMenu {
            Button { editingFacade = facade } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) { facadeToDelete = facade } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func facadeStat(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(AVIATheme.teal)
            Text(value)
                .font(.neueCaption2Medium)
                .foregroundStyle(AVIATheme.textSecondary)
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

struct FacadeEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let facade: Facade?
    let onSave: (Facade) -> Void

    @State private var facadeId: String = ""
    @State private var name: String = ""
    @State private var style: String = ""
    @State private var descriptionText: String = ""
    @State private var heroImageURL: String = ""
    @State private var galleryURLs: [String] = []
    @State private var featuresText: String = ""
    @State private var pricingType: String = "included"
    @State private var pricingAmount: String = ""
    @State private var storeys: Int = 1

    private var isNew: Bool { facade == nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !heroImageURL.isEmpty {
                        Color(.secondarySystemBackground)
                            .frame(height: 180)
                            .overlay {
                                AsyncImage(url: URL(string: heroImageURL)) { phase in
                                    if let image = phase.image {
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } else {
                                        Image(systemName: "photo")
                                            .font(.title2)
                                            .foregroundStyle(AVIATheme.textTertiary)
                                    }
                                }
                                .allowsHitTesting(false)
                            }
                            .clipShape(.rect(cornerRadius: 14))
                            .padding(.horizontal, 16)
                    }

                    BentoCard(cornerRadius: 14) {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader("Basic Info")
                            if isNew {
                                sheetField("ID (lowercase)") {
                                    TextField("e.g. airlie", text: $facadeId)
                                        .font(.neueCaption)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                }
                            }
                            sheetField("Name") {
                                TextField("Facade name", text: $name)
                                    .font(.neueCaption)
                            }
                            sheetField("Style") {
                                TextField("e.g. Modern & Refined", text: $style)
                                    .font(.neueCaption)
                            }
                            sheetField("Description") {
                                TextField("Facade description", text: $descriptionText, axis: .vertical)
                                    .font(.neueCaption)
                                    .lineLimit(3...8)
                            }
                        }
                        .padding(.vertical, 14)
                    }

                    BentoCard(cornerRadius: 14) {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader("Pricing & Type")
                            sheetField("Pricing") {
                                Picker("", selection: $pricingType) {
                                    Text("Included").tag("included")
                                    Text("Upgrade").tag("upgrade")
                                }
                                .pickerStyle(.segmented)
                            }
                            if pricingType == "upgrade" {
                                sheetField("Upgrade Cost") {
                                    TextField("e.g. $7,500", text: $pricingAmount)
                                        .font(.neueCaption)
                                }
                            }
                            sheetField("Storeys") {
                                Picker("", selection: $storeys) {
                                    Text("Single").tag(1)
                                    Text("Double").tag(2)
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        .padding(.vertical, 14)
                    }

                    BentoCard(cornerRadius: 14) {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader("Images")
                            AdminImagePickerField(
                                label: "Hero Image",
                                imageURL: $heroImageURL,
                                folder: "facades",
                                itemId: isNew ? facadeId : (facade?.id ?? facadeId)
                            )

                            galleryImagesSection
                        }
                        .padding(.vertical, 14)
                    }

                    BentoCard(cornerRadius: 14) {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader("Features")
                            sheetField("Features (one per line)") {
                                TextField("Render & cladding material mix\nClean modern lines...", text: $featuresText, axis: .vertical)
                                    .font(.neueCaption)
                                    .lineLimit(4...10)
                            }
                        }
                        .padding(.vertical, 14)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(AVIATheme.background)
            .navigationTitle(isNew ? "New Facade" : "Edit Facade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.isEmpty || (isNew && facadeId.isEmpty))
                }
            }
        }
        .onAppear { populateFields() }
        .presentationDetents([.large])
    }

    private var galleryImagesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gallery Images")
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.textSecondary)
                .padding(.horizontal, 14)

            ForEach(galleryURLs.indices, id: \.self) { index in
                galleryRow(at: index)
            }

            Button {
                galleryURLs.append("")
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Gallery Image")
                        .font(.neueCaptionMedium)
                }
                .foregroundStyle(AVIATheme.teal)
            }
            .padding(.horizontal, 14)
        }
    }

    @ViewBuilder
    private func galleryRow(at index: Int) -> some View {
        let url = galleryURLs[index]
        HStack(spacing: 8) {
            if !url.isEmpty {
                Color(.secondarySystemBackground)
                    .frame(width: 40, height: 40)
                    .overlay {
                        AsyncImage(url: URL(string: url)) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 6))
            }

            AdminCompactImagePicker(
                imageURL: $galleryURLs[index],
                folder: "facades/gallery",
                itemId: "\(isNew ? facadeId : (facade?.id ?? facadeId))_\(index)"
            )

            Button {
                let idx = index
                withAnimation { galleryURLs.remove(at: idx) }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(AVIATheme.destructive.opacity(0.6))
            }
        }
        .padding(.horizontal, 14)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.neueCaptionMedium)
            .foregroundStyle(AVIATheme.textSecondary)
            .textCase(.uppercase)
            .kerning(0.5)
            .padding(.horizontal, 14)
    }

    private func sheetField(_ label: String, @ViewBuilder field: () -> some View) -> some View {
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

    private func populateFields() {
        guard let facade else { return }
        facadeId = facade.id
        name = facade.name
        style = facade.style
        descriptionText = facade.description
        heroImageURL = facade.heroImageURL
        galleryURLs = facade.galleryImageURLs
        featuresText = facade.features.joined(separator: "\n")
        storeys = facade.storeys
        switch facade.pricing {
        case .included:
            pricingType = "included"
            pricingAmount = ""
        case .upgrade(let amount):
            pricingType = "upgrade"
            pricingAmount = amount
        }
    }

    private func save() {
        let filteredGallery = galleryURLs
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let features = featuresText
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let pricing: FacadePricing = pricingType == "included"
            ? .included
            : .upgrade(pricingAmount.isEmpty ? "$0" : pricingAmount)

        let result = Facade(
            id: isNew ? facadeId : (facade?.id ?? facadeId),
            name: name,
            style: style,
            description: descriptionText,
            heroImageURL: heroImageURL,
            galleryImageURLs: filteredGallery.isEmpty ? [heroImageURL] : filteredGallery,
            features: features,
            pricing: pricing,
            storeys: storeys
        )
        onSave(result)
        dismiss()
    }
}
