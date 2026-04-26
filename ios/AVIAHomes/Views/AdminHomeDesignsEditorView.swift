import SwiftUI
import PhotosUI

struct AdminHomeDesignsEditorView: View {
    @State private var viewModel = AdminCatalogViewModel()
    @State private var searchText = ""
    @State private var filterStoreys: Int? = nil
    @State private var editingDesign: HomeDesign?
    @State private var showingAddSheet = false
    @State private var designToDelete: HomeDesign?

    private var filteredDesigns: [HomeDesign] {
        var designs = viewModel.homeDesigns
        if let storeys = filterStoreys {
            designs = designs.filter { $0.storeys == storeys }
        }
        if !searchText.isEmpty {
            designs = designs.filter {
                $0.name.localizedStandardContains(searchText) ||
                $0.description.localizedStandardContains(searchText)
            }
        }
        return designs.sorted { $0.name < $1.name }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                storeyFilter
                statsBar

                if viewModel.isLoading {
                    ProgressView()
                        .tint(AVIATheme.timelessBrown)
                        .padding(.vertical, 60)
                } else if filteredDesigns.isEmpty {
                    AdminEmptyState(
                        icon: "house",
                        title: "No Home Designs",
                        subtitle: "Add your first home design to get started"
                    )
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredDesigns, id: \.id) { design in
                            designCard(design)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .navigationTitle("Home Designs")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search designs...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddSheet = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            HomeDesignEditSheet(design: nil) { design in
                Task { await viewModel.saveHomeDesign(design) }
            }
        }
        .sheet(item: $editingDesign) { design in
            HomeDesignEditSheet(design: design) { updated in
                Task { await viewModel.saveHomeDesign(updated) }
            }
        }
        .alert("Delete Design", isPresented: .init(
            get: { designToDelete != nil },
            set: { if !$0 { designToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { designToDelete = nil }
            Button("Delete", role: .destructive) {
                if let design = designToDelete {
                    Task { await viewModel.deleteHomeDesign(id: design.id) }
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(designToDelete?.name ?? "")\"? This cannot be undone.")
        }
        .overlay(alignment: .bottom) { toastOverlay }
        .task { await viewModel.loadHomeDesigns() }
    }

    private var storeyFilter: some View {
        HStack(spacing: 6) {
            storeyChip("All", value: nil)
            storeyChip("Single Storey", value: 1)
            storeyChip("Double Storey", value: 2)
            Spacer()
        }
    }

    private func storeyChip(_ label: String, value: Int?) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) { filterStoreys = value }
        } label: {
            Text(label)
                .font(.neueCaptionMedium)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .foregroundStyle(filterStoreys == value ? AVIATheme.aviaWhite : AVIATheme.textSecondary)
                .background(filterStoreys == value ? AVIATheme.timelessBrown : AVIATheme.cardBackground)
                .clipShape(Capsule())
                .overlay {
                    if filterStoreys != value {
                        Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                    }
                }
        }
    }

    private var statsBar: some View {
        HStack(spacing: 12) {
            AdminMiniStat(value: "\(viewModel.homeDesigns.count)", label: "Total", color: AVIATheme.timelessBrown)
            AdminMiniStat(value: "\(viewModel.homeDesigns.filter { $0.storeys == 1 }.count)", label: "Single", color: AVIATheme.success)
            AdminMiniStat(value: "\(viewModel.homeDesigns.filter { $0.storeys == 2 }.count)", label: "Double", color: AVIATheme.warning)
        }
    }

    private func designCard(_ design: HomeDesign) -> some View {
        Button { editingDesign = design } label: {
            BentoCard(cornerRadius: 14) {
                HStack(spacing: 14) {
                    Color(.secondarySystemBackground)
                        .frame(width: 72, height: 72)
                        .overlay {
                            AsyncImage(url: URL(string: design.imageURL)) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                }
                            }
                            .allowsHitTesting(false)
                        }
                        .clipShape(.rect(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(design.name)
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)

                        HStack(spacing: 10) {
                            designStat(icon: "bed.double.fill", value: "\(design.bedrooms)")
                            designStat(icon: "shower.fill", value: "\(design.bathrooms)")
                            designStat(icon: "car.fill", value: "\(design.garages)")
                            designStat(icon: "ruler.fill", value: "\(Int(design.squareMeters))m²")
                        }

                        HStack(spacing: 6) {
                            Text("\(design.storeys == 1 ? "Single" : "Double") Storey")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                            if design.lotWidth > 0 {
                                Text("•")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                                Text("\(String(format: "%.1f", design.lotWidth))m lot")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                .padding(12)
            }
        }
        .contextMenu {
            Button { editingDesign = design } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) { designToDelete = design } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func designStat(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(AVIATheme.timelessBrown)
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

struct HomeDesignEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let design: HomeDesign?
    let onSave: (HomeDesign) -> Void

    @State private var designId: String = ""
    @State private var name: String = ""
    @State private var bedrooms: Int = 4
    @State private var bathrooms: Int = 2
    @State private var garages: Int = 2
    @State private var squareMeters: Double = 200
    @State private var imageURL: String = ""
    @State private var priceFrom: String = ""
    @State private var storeys: Int = 1
    @State private var lotWidth: Double = 12.5
    @State private var slug: String = ""
    @State private var descriptionText: String = ""
    @State private var houseWidth: Double = 12.0
    @State private var houseLength: Double = 20.0
    @State private var livingAreas: Int = 1
    @State private var floorplanImageURL: String = ""
    @State private var floorplanPDFURL: String = ""
    @State private var floorplanPDFImageURL: String = ""
    @State private var roomHighlightsText: String = ""
    @State private var inclusionsText: String = ""

    private var isNew: Bool { design == nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    BentoCard(cornerRadius: 14) {
                        VStack(alignment: .leading, spacing: 14) {
                            sheetSectionHeader("Basic Info")
                            if isNew {
                                sheetField("ID (lowercase)") {
                                    TextField("e.g. corfu", text: $designId)
                                        .font(.neueCaption)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                }
                            }
                            sheetField("Name") {
                                TextField("Design name", text: $name)
                                    .font(.neueCaption)
                            }
                            sheetField("Slug") {
                                TextField("URL-friendly name", text: $slug)
                                    .font(.neueCaption)
                                    .textInputAutocapitalization(.never)
                            }
                            sheetField("Price From") {
                                TextField("e.g. $385,000", text: $priceFrom)
                                    .font(.neueCaption)
                            }
                            sheetField("Description") {
                                TextField("Design description", text: $descriptionText, axis: .vertical)
                                    .font(.neueCaption)
                                    .lineLimit(3...6)
                            }
                        }
                        .padding(.vertical, 14)
                    }

                    BentoCard(cornerRadius: 14) {
                        VStack(alignment: .leading, spacing: 14) {
                            sheetSectionHeader("Specifications")
                            HStack(spacing: 12) {
                                compactCounter("Beds", value: $bedrooms, icon: "bed.double.fill")
                                compactCounter("Baths", value: $bathrooms, icon: "shower.fill")
                                compactCounter("Garage", value: $garages, icon: "car.fill")
                                compactCounter("Living", value: $livingAreas, icon: "sofa.fill")
                            }
                            .padding(.horizontal, 14)

                            sheetField("Square Metres") {
                                TextField("200", value: $squareMeters, format: .number)
                                    .font(.neueCaption)
                                    .keyboardType(.decimalPad)
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
                            sheetSectionHeader("Dimensions")
                            HStack(spacing: 12) {
                                sheetField("Lot Width (m)") {
                                    TextField("12.5", value: $lotWidth, format: .number)
                                        .font(.neueCaption)
                                        .keyboardType(.decimalPad)
                                }
                                sheetField("House Width (m)") {
                                    TextField("12.0", value: $houseWidth, format: .number)
                                        .font(.neueCaption)
                                        .keyboardType(.decimalPad)
                                }
                            }
                            sheetField("House Length (m)") {
                                TextField("20.0", value: $houseLength, format: .number)
                                    .font(.neueCaption)
                                    .keyboardType(.decimalPad)
                            }
                        }
                        .padding(.vertical, 14)
                    }

                    BentoCard(cornerRadius: 14) {
                        VStack(alignment: .leading, spacing: 14) {
                            sheetSectionHeader("Images")
                            AdminImagePickerField(
                                label: "Hero Image",
                                imageURL: $imageURL,
                                folder: "home-designs",
                                itemId: isNew ? designId : (design?.id ?? designId)
                            )
                            AdminImagePickerField(
                                label: "Floorplan Image",
                                imageURL: $floorplanImageURL,
                                folder: "home-designs/floorplans",
                                itemId: isNew ? designId : (design?.id ?? designId)
                            )
                            AdminPDFPickerField(
                                label: "Floorplan PDF",
                                pdfURL: $floorplanPDFURL,
                                folder: "home-designs/floorplan-pdfs",
                                itemId: isNew ? designId : (design?.id ?? designId)
                            )
                            AdminImagePickerField(
                                label: "Floorplan PDF Block Image",
                                imageURL: $floorplanPDFImageURL,
                                folder: "home-designs/floorplan-pdf-images",
                                itemId: isNew ? designId : (design?.id ?? designId)
                            )
                        }
                        .padding(.vertical, 14)
                    }

                    BentoCard(cornerRadius: 14) {
                        VStack(alignment: .leading, spacing: 14) {
                            sheetSectionHeader("Highlights & Inclusions")
                            sheetField("Room Highlights (one per line)") {
                                TextField("Master suite with ensuite & WIR\nOpen-plan living...", text: $roomHighlightsText, axis: .vertical)
                                    .font(.neueCaption)
                                    .lineLimit(4...8)
                            }
                            sheetField("Inclusions (one per line)") {
                                TextField("Stone benchtops\n900mm appliances...", text: $inclusionsText, axis: .vertical)
                                    .font(.neueCaption)
                                    .lineLimit(4...8)
                            }
                        }
                        .padding(.vertical, 14)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(AVIATheme.background)
            .navigationTitle(isNew ? "New Home Design" : "Edit Design")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.isEmpty || (isNew && designId.isEmpty))
                }
            }
        }
        .onAppear { populateFields() }
        .presentationDetents([.large])
    }

    private func sheetSectionHeader(_ title: String) -> some View {
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

    private func compactCounter(_ label: String, value: Binding<Int>, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(AVIATheme.timelessBrown)
            HStack(spacing: 8) {
                Button { if value.wrappedValue > 0 { value.wrappedValue -= 1 } } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                Text("\(value.wrappedValue)")
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                    .frame(minWidth: 16)
                Button { value.wrappedValue += 1 } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }
            Text(label)
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(AVIATheme.surfaceElevated)
        .clipShape(.rect(cornerRadius: 10))
    }

    private func populateFields() {
        guard let design else { return }
        designId = design.id
        name = design.name
        bedrooms = design.bedrooms
        bathrooms = design.bathrooms
        garages = design.garages
        squareMeters = design.squareMeters
        imageURL = design.imageURL
        priceFrom = design.priceFrom
        storeys = design.storeys
        lotWidth = design.lotWidth
        slug = design.slug
        descriptionText = design.description
        houseWidth = design.houseWidth
        houseLength = design.houseLength
        livingAreas = design.livingAreas
        floorplanImageURL = design.floorplanImageURL
        floorplanPDFURL = design.floorplanPDFURL
        floorplanPDFImageURL = design.floorplanPDFImageURL
        roomHighlightsText = design.roomHighlights.joined(separator: "\n")
        inclusionsText = design.inclusions.joined(separator: "\n")
    }

    private func save() {
        let highlights = roomHighlightsText.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let incl = inclusionsText.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        let result = HomeDesign(
            id: isNew ? designId : (design?.id ?? designId),
            name: name,
            bedrooms: bedrooms,
            bathrooms: bathrooms,
            garages: garages,
            squareMeters: squareMeters,
            imageURL: imageURL,
            priceFrom: priceFrom,
            storeys: storeys,
            lotWidth: lotWidth,
            slug: slug,
            description: descriptionText,
            houseWidth: houseWidth,
            houseLength: houseLength,
            livingAreas: livingAreas,
            floorplanImageURL: floorplanImageURL,
            floorplanPDFURL: floorplanPDFURL,
            floorplanPDFImageURL: floorplanPDFImageURL,
            roomHighlights: highlights,
            inclusions: incl
        )
        onSave(result)
        dismiss()
    }
}
