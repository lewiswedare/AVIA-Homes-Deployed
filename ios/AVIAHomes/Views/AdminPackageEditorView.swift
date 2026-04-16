import SwiftUI

struct AdminPackageEditorView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    let existingPackage: HouseLandPackage?

    @State private var title = ""
    @State private var location = ""
    @State private var lotSize = ""
    @State private var lotNumber = ""
    @State private var lotFrontage = ""
    @State private var lotDepth = ""
    @State private var landPrice = ""
    @State private var housePrice = ""
    @State private var totalPrice = ""
    @State private var imageURL = ""
    @State private var selectedDesignId = ""
    @State private var selectedSpecTier: SpecTier = .messina
    @State private var titleDate = ""
    @State private var council = ""
    @State private var zoning = ""
    @State private var buildTimeEstimate = ""
    @State private var isNew = true
    @State private var inclusions: [String] = ["Site costs included", "Driveway & crossover", "Fencing to 3 boundaries", "Floor coverings throughout", "Ducted air conditioning"]
    @State private var newInclusion = ""
    @State private var isCustomHome = false
    @State private var customDesignName = ""
    @State private var customBedrooms = 4
    @State private var customBathrooms = 2
    @State private var customGarages = 2
    @State private var customSquareMeters = ""
    @State private var customStoreys = 1
    @State private var selectedFacadeId = ""

    @State private var selectedClientIds: Set<String> = []
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false
    @State private var showClientPicker = false

    @State private var currentStep = 0

    private var isEditing: Bool { existingPackage != nil }

    private var designs: [HomeDesign] {
        let d = viewModel.allHomeDesigns
        return d
    }

    private var selectedDesign: HomeDesign? {
        designs.first { $0.id == selectedDesignId }
    }

    private var selectedEstateName: String {
        let loc = location.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? location
        return loc
    }

    private var facades: [Facade] {
        let f = viewModel.allFacades
        return f
    }

    private var selectedFacade: Facade? {
        facades.first { $0.id == selectedFacadeId }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !location.trimmingCharacters(in: .whitespaces).isEmpty &&
        !totalPrice.trimmingCharacters(in: .whitespaces).isEmpty &&
        (isCustomHome ? !customDesignName.trimmingCharacters(in: .whitespaces).isEmpty : !selectedDesignId.isEmpty)
    }

    init(existingPackage: HouseLandPackage? = nil) {
        self.existingPackage = existingPackage
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepIndicator
                ScrollView {
                    VStack(spacing: 20) {
                        switch currentStep {
                        case 0: landDetailsStep
                        case 1: houseDetailsStep
                        case 2: pricingStep
                        case 3: assignClientsStep
                        default: EmptyView()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
                bottomBar
            }
            .background(AVIATheme.background)
            .navigationTitle(isEditing ? "Edit Package" : "Create Package")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.neueSubheadline)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                if isEditing {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showDeleteConfirmation = true } label: {
                            Image(systemName: "trash")
                                .font(.neueSubheadline)
                                .foregroundStyle(AVIATheme.destructive)
                        }
                    }
                }
            }
            .alert("Delete Package", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let pkg = existingPackage {
                        viewModel.deletePackage(pkg.id)
                    }
                    dismiss()
                }
            } message: {
                Text("This will permanently remove the package and all its assignments.")
            }
            .onAppear { populateFromExisting() }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Step Indicator

    private let stepTitles = ["Land", "House", "Pricing", "Assign"]

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { step in
                Button {
                    withAnimation(.spring(response: 0.35)) { currentStep = step }
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: stepIcon(step))
                                .font(.system(size: 10, weight: .semibold))
                            Text(stepTitles[step])
                                .font(.neueCaptionMedium)
                        }
                        .foregroundStyle(currentStep == step ? AVIATheme.textPrimary : AVIATheme.textTertiary)

                        Rectangle()
                            .fill(currentStep == step ? AVIATheme.timelessBrown : AVIATheme.surfaceBorder)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func stepIcon(_ step: Int) -> String {
        switch step {
        case 0: "map.fill"
        case 1: "house.fill"
        case 2: "dollarsign.circle.fill"
        case 3: "person.2.fill"
        default: "circle"
        }
    }

    // MARK: - Step 1: Land Details

    private var landDetailsStep: some View {
        VStack(spacing: 16) {
            sectionHeader(icon: "map.fill", title: "Land Details", subtitle: "Lot information and location")

            BentoCard(cornerRadius: 16) {
                VStack(spacing: 0) {
                    editorField(label: "Package Title", text: $title, placeholder: "e.g. Corfu 210 at Harmony", icon: "tag.fill")
                    fieldDivider
                    editorField(label: "Location", text: $location, placeholder: "e.g. Palmview, Sunshine Coast", icon: "mappin.circle.fill")
                    fieldDivider
                    editorField(label: "Lot Number", text: $lotNumber, placeholder: "e.g. Lot 142", icon: "number")
                    fieldDivider
                    editorField(label: "Lot Size", text: $lotSize, placeholder: "e.g. 450m²", icon: "square.dashed")
                    fieldDivider
                    editorField(label: "Lot Frontage", text: $lotFrontage, placeholder: "e.g. 15.0m", icon: "arrow.left.and.right")
                    fieldDivider
                    editorField(label: "Lot Depth", text: $lotDepth, placeholder: "e.g. 30.0m", icon: "arrow.up.and.down")
                }
            }

            BentoCard(cornerRadius: 16) {
                VStack(spacing: 0) {
                    editorField(label: "Title Date", text: $titleDate, placeholder: "e.g. Titled — Ready Now", icon: "calendar")
                    fieldDivider
                    editorField(label: "Council", text: $council, placeholder: "e.g. Sunshine Coast Regional Council", icon: "building.columns.fill")
                    fieldDivider
                    editorField(label: "Zoning", text: $zoning, placeholder: "e.g. Low Density Residential", icon: "doc.text.fill")
                    fieldDivider
                    editorField(label: "Build Time", text: $buildTimeEstimate, placeholder: "e.g. 8–10 months", icon: "clock.fill")
                }
            }

            HStack(spacing: 12) {
                Toggle(isOn: $isNew) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.neueCorp(12))
                            .foregroundStyle(AVIATheme.timelessBrown)
                        Text("Mark as New Listing")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                    }
                }
                .tint(AVIATheme.timelessBrown)
            }
            .padding(16)
            .background(AVIATheme.cardBackground)
            .clipShape(.rect(cornerRadius: 16))
        }
    }

    // MARK: - Step 2: House Design

    private var houseDetailsStep: some View {
        VStack(spacing: 16) {
            sectionHeader(icon: "house.fill", title: "Home Design", subtitle: isCustomHome ? "Enter custom design details" : "Select a home design for this package")

            HStack(spacing: 12) {
                Toggle(isOn: $isCustomHome) {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil.and.ruler.fill")
                            .font(.neueCorp(12))
                            .foregroundStyle(AVIATheme.timelessBrown)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Custom Home")
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Text("Client has their own design — enter details manually")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                    }
                }
                .tint(AVIATheme.timelessBrown)
            }
            .padding(16)
            .background(isCustomHome ? AVIATheme.timelessBrown.opacity(0.06) : AVIATheme.cardBackground)
            .clipShape(.rect(cornerRadius: 16))
            .sensoryFeedback(.impact(weight: .light), trigger: isCustomHome)

            if isCustomHome {
                customDesignSection
            } else {
                standardDesignSection
            }

            specTierSection

            if isCustomHome {
                facadeSelectionSection
            }

            BentoCard(cornerRadius: 16) {
                editorField(label: "Image URL", text: $imageURL, placeholder: "https://... (auto-filled from design)", icon: "photo.fill")
            }
        }
    }

    private var standardDesignSection: some View {
        Group {
            BentoCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("SELECT DESIGN")
                            .font(.neueCaption2Medium)
                            .kerning(1.0)
                            .foregroundStyle(AVIATheme.textTertiary)
                        Spacer()
                        if selectedDesign != nil {
                            Button {
                                withAnimation { selectedDesignId = "" }
                            } label: {
                                Text("Clear")
                                    .font(.neueCaption2Medium)
                                    .foregroundStyle(AVIATheme.destructive)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(designs) { design in
                                let isSelected = selectedDesignId == design.id
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedDesignId = design.id
                                        if title.isEmpty {
                                            title = "\(design.name) \(Int(design.squareMeters)) at \(selectedEstateName)"
                                        }
                                        if imageURL.isEmpty {
                                            imageURL = design.imageURL
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Color(AVIATheme.surfaceElevated)
                                            .frame(width: 48, height: 48)
                                            .overlay {
                                                AsyncImage(url: URL(string: design.imageURL)) { phase in
                                                    if let image = phase.image {
                                                        image.resizable().aspectRatio(contentMode: .fill)
                                                    }
                                                }
                                                .allowsHitTesting(false)
                                            }
                                            .clipShape(.rect(cornerRadius: 8))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(design.name)
                                                .font(.neueCaptionMedium)
                                                .foregroundStyle(AVIATheme.textPrimary)
                                            HStack(spacing: 8) {
                                                Label("\(design.bedrooms)", systemImage: "bed.double.fill")
                                                Label("\(design.bathrooms)", systemImage: "shower.fill")
                                                Label("\(design.garages)", systemImage: "car.fill")
                                                Text("•")
                                                Text(String(format: "%.0fm²", design.squareMeters))
                                            }
                                            .font(.neueCaption2)
                                            .foregroundStyle(AVIATheme.textTertiary)
                                        }

                                        Spacer()

                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 20))
                                            .foregroundStyle(isSelected ? AVIATheme.timelessBrown : AVIATheme.surfaceBorder)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? AVIATheme.timelessBrown.opacity(0.06) : Color.clear)
                                }
                                .sensoryFeedback(.selection, trigger: selectedDesignId)
                            }
                        }
                    }
                    .frame(maxHeight: 360)
                }
                .padding(.bottom, 8)
            }

            if let design = selectedDesign {
                selectedDesignPreview(design)
            }
        }
    }

    private var customDesignSection: some View {
        VStack(spacing: 16) {
            BentoCard(cornerRadius: 16) {
                VStack(spacing: 0) {
                    editorField(label: "Design Name", text: $customDesignName, placeholder: "e.g. Smith Family Residence", icon: "pencil.line")
                    fieldDivider
                    editorField(label: "Square Metres", text: $customSquareMeters, placeholder: "e.g. 280", icon: "square.dashed")
                }
            }

            BentoCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("DESIGN DETAILS")
                        .font(.neueCaption2Medium)
                        .kerning(1.0)
                        .foregroundStyle(AVIATheme.textTertiary)
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                    VStack(spacing: 12) {
                        customStepperRow(icon: "bed.double.fill", label: "Bedrooms", value: $customBedrooms, range: 1...8)
                        customStepperRow(icon: "shower.fill", label: "Bathrooms", value: $customBathrooms, range: 1...6)
                        customStepperRow(icon: "car.fill", label: "Garages", value: $customGarages, range: 0...4)
                        customStepperRow(icon: "arrow.up.arrow.down", label: "Storeys", value: $customStoreys, range: 1...3)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
            }

            if !customDesignName.isEmpty {
                BentoCard(cornerRadius: 16) {
                    HStack(spacing: 14) {
                        Image(systemName: "pencil.and.ruler.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(AVIATheme.timelessBrown)
                            .frame(width: 48, height: 48)
                            .background(AVIATheme.timelessBrown.opacity(0.1))
                            .clipShape(.rect(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(customDesignName)
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text("CUSTOM")
                                    .font(.neueCorpMedium(8))
                                    .kerning(0.4)
                                    .foregroundStyle(AVIATheme.aviaWhite)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AVIATheme.timelessBrown)
                                    .clipShape(Capsule())
                            }
                            HStack(spacing: 10) {
                                Label("\(customBedrooms) bed", systemImage: "bed.double.fill")
                                Label("\(customBathrooms) bath", systemImage: "shower.fill")
                                Label("\(customGarages) car", systemImage: "car.fill")
                            }
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                            if !customSquareMeters.isEmpty {
                                Text("\(customSquareMeters)m² · \(customStoreys) storey")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                            }
                        }
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(AVIATheme.success)
                    }
                    .padding(14)
                }
            }
        }
    }

    private var facadeSelectionSection: some View {
        BentoCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("SELECT FACADE")
                        .font(.neueCaption2Medium)
                        .kerning(1.0)
                        .foregroundStyle(AVIATheme.textTertiary)
                    Spacer()
                    if selectedFacade != nil {
                        Button {
                            withAnimation { selectedFacadeId = "" }
                        } label: {
                            Text("Clear")
                                .font(.neueCaption2Medium)
                                .foregroundStyle(AVIATheme.destructive)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(facades) { facade in
                            let isSelected = selectedFacadeId == facade.id
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedFacadeId = facade.id
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Color(AVIATheme.surfaceElevated)
                                        .frame(width: 48, height: 48)
                                        .overlay {
                                            AsyncImage(url: URL(string: facade.heroImageURL)) { phase in
                                                if let image = phase.image {
                                                    image.resizable().aspectRatio(contentMode: .fill)
                                                }
                                            }
                                            .allowsHitTesting(false)
                                        }
                                        .clipShape(.rect(cornerRadius: 8))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(facade.name)
                                            .font(.neueCaptionMedium)
                                            .foregroundStyle(AVIATheme.textPrimary)
                                        Text(facade.style)
                                            .font(.neueCaption2)
                                            .foregroundStyle(AVIATheme.textTertiary)
                                    }

                                    Spacer()

                                    Text(facade.pricing.displayText)
                                        .font(.neueCaption2)
                                        .foregroundStyle(facade.pricing.isIncluded ? AVIATheme.success : AVIATheme.textSecondary)

                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20))
                                        .foregroundStyle(isSelected ? AVIATheme.timelessBrown : AVIATheme.surfaceBorder)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(isSelected ? AVIATheme.timelessBrown.opacity(0.06) : Color.clear)
                            }
                            .sensoryFeedback(.selection, trigger: selectedFacadeId)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
            .padding(.bottom, 8)
        }
    }

    private var specTierSection: some View {
        BentoCard(cornerRadius: 16) {
            VStack(spacing: 0) {
                HStack {
                    Text("SPECIFICATION RANGE")
                        .font(.neueCaption2Medium)
                        .kerning(1.0)
                        .foregroundStyle(AVIATheme.textTertiary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

                HStack(spacing: 8) {
                    ForEach(SpecTier.allCases) { tier in
                        let isSelected = selectedSpecTier == tier
                        Button {
                            withAnimation(.spring(response: 0.3)) { selectedSpecTier = tier }
                        } label: {
                            VStack(spacing: 4) {
                                Text(tier.displayName)
                                    .font(.neueCaptionMedium)
                                Text(tier.tagline)
                                    .font(.neueCaption2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(isSelected ? AVIATheme.aviaWhite : AVIATheme.textPrimary)
                            .background(isSelected ? AVIATheme.primaryGradient : LinearGradient(colors: [AVIATheme.surfaceElevated], startPoint: .top, endPoint: .bottom))
                            .clipShape(.rect(cornerRadius: 12))
                        }
                        .sensoryFeedback(.selection, trigger: selectedSpecTier)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
    }

    private func customStepperRow(icon: String, label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.neueCorp(12))
                .foregroundStyle(AVIATheme.timelessBrown)
                .frame(width: 28)
            Text(label)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textPrimary)
            Spacer()
            HStack(spacing: 16) {
                Button {
                    if value.wrappedValue > range.lowerBound {
                        value.wrappedValue -= 1
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(value.wrappedValue > range.lowerBound ? AVIATheme.timelessBrown : AVIATheme.surfaceBorder)
                }
                .disabled(value.wrappedValue <= range.lowerBound)

                Text("\(value.wrappedValue)")
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                    .frame(width: 24)

                Button {
                    if value.wrappedValue < range.upperBound {
                        value.wrappedValue += 1
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(value.wrappedValue < range.upperBound ? AVIATheme.timelessBrown : AVIATheme.surfaceBorder)
                }
                .disabled(value.wrappedValue >= range.upperBound)
            }
        }
    }

    private func selectedDesignPreview(_ design: HomeDesign) -> some View {
        BentoCard(cornerRadius: 16) {
            HStack(spacing: 14) {
                Color(AVIATheme.surfaceElevated)
                    .frame(width: 64, height: 64)
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
                    HStack(spacing: 6) {
                        Text(design.name)
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        if design.storeys == 2 {
                            Text("2 STOREY")
                                .font(.neueCorpMedium(8))
                                .kerning(0.4)
                                .foregroundStyle(AVIATheme.aviaWhite)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AVIATheme.timelessBrown)
                                .clipShape(Capsule())
                        }
                    }
                    HStack(spacing: 10) {
                        Label("\(design.bedrooms) bed", systemImage: "bed.double.fill")
                        Label("\(design.bathrooms) bath", systemImage: "shower.fill")
                        Label("\(design.garages) car", systemImage: "car.fill")
                    }
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textSecondary)
                    Text(String(format: "%.0fm² · %.1fm min lot", design.squareMeters, design.lotWidth))
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AVIATheme.success)
            }
            .padding(14)
        }
    }

    // MARK: - Step 3: Pricing & Inclusions

    private var pricingStep: some View {
        VStack(spacing: 16) {
            sectionHeader(icon: "dollarsign.circle.fill", title: "Pricing", subtitle: "Package price breakdown")

            BentoCard(cornerRadius: 16) {
                VStack(spacing: 0) {
                    editorField(label: "Total Package Price", text: $totalPrice, placeholder: "e.g. $685,000", icon: "dollarsign.circle.fill")
                    fieldDivider
                    editorField(label: "Land Price", text: $landPrice, placeholder: "e.g. $295,000", icon: "map.fill")
                    fieldDivider
                    editorField(label: "House Price", text: $housePrice, placeholder: "e.g. $390,000", icon: "house.fill")
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("INCLUSIONS")
                        .font(.neueCaption2Medium)
                        .kerning(1.0)
                        .foregroundStyle(AVIATheme.textTertiary)
                    Spacer()
                    Text("\(inclusions.count) items")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }

                BentoCard(cornerRadius: 16) {
                    VStack(spacing: 0) {
                        ForEach(Array(inclusions.enumerated()), id: \.offset) { item in
                            let index: Int = item.offset
                            let inclusion: String = item.element
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AVIATheme.timelessBrown)
                                Text(inclusion)
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Spacer()
                                Button {
                                    withAnimation { _ = inclusions.remove(at: index) }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(AVIATheme.textTertiary)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)

                            if index < inclusions.count - 1 {
                                Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 38)
                            }
                        }

                        Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(AVIATheme.timelessBrown.opacity(0.5))
                            TextField("Add inclusion...", text: $newInclusion)
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textPrimary)
                                .onSubmit { addInclusion() }
                            if !newInclusion.isEmpty {
                                Button {
                                    addInclusion()
                                } label: {
                                    Text("Add")
                                        .font(.neueCaptionMedium)
                                        .foregroundStyle(AVIATheme.timelessBrown)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                }
            }
        }
    }

    // MARK: - Step 4: Assign to Clients

    private var assignClientsStep: some View {
        VStack(spacing: 16) {
            sectionHeader(icon: "person.2.fill", title: "Assign to Clients", subtitle: "Share this package directly with clients")

            if !selectedClientIds.isEmpty {
                BentoCard(cornerRadius: 16) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("ASSIGNED (\(selectedClientIds.count))")
                                .font(.neueCaption2Medium)
                                .kerning(1.0)
                                .foregroundStyle(AVIATheme.textTertiary)
                            Spacer()
                            Button {
                                withAnimation { selectedClientIds.removeAll() }
                            } label: {
                                Text("Clear All")
                                    .font(.neueCaption2Medium)
                                    .foregroundStyle(AVIATheme.destructive)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 14)
                        .padding(.bottom, 8)

                        let assignedClients: [ClientUser] = viewModel.clientUsers.filter { selectedClientIds.contains($0.id) }
                        ForEach(assignedClients, id: \.id) { client in
                            HStack(spacing: 12) {
                                Text(client.initials.isEmpty ? "?" : client.initials)
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.aviaWhite)
                                    .frame(width: 34, height: 34)
                                    .background(AVIATheme.primaryGradient)
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(client.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? client.email : client.fullName)
                                        .font(.neueCaptionMedium)
                                        .foregroundStyle(AVIATheme.textPrimary)
                                    Text(client.email)
                                        .font(.neueCaption2)
                                        .foregroundStyle(AVIATheme.textTertiary)
                                }

                                Spacer()

                                Button {
                                    withAnimation { _ = selectedClientIds.remove(client.id) }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(AVIATheme.textTertiary)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        }
                        .padding(.bottom, 8)
                    }
                }
            }

            let unassignedClients = viewModel.clientUsers.filter { !selectedClientIds.contains($0.id) }

            BentoCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("AVAILABLE CLIENTS")
                        .font(.neueCaption2Medium)
                        .kerning(1.0)
                        .foregroundStyle(AVIATheme.textTertiary)
                        .padding(.horizontal, 14)
                        .padding(.top, 14)
                        .padding(.bottom, 8)

                    if unassignedClients.isEmpty && viewModel.clientUsers.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "person.slash")
                                .font(.system(size: 28))
                                .foregroundStyle(AVIATheme.textTertiary)
                            Text("No clients registered yet")
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)
                            Text("You can assign clients after creating the package")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    } else if unassignedClients.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AVIATheme.success)
                            Text("All clients assigned")
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        ForEach(unassignedClients, id: \.id) { client in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    _ = selectedClientIds.insert(client.id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Text(client.initials.isEmpty ? "?" : client.initials)
                                        .font(.neueCaptionMedium)
                                        .foregroundStyle(AVIATheme.aviaWhite)
                                        .frame(width: 34, height: 34)
                                        .background(AVIATheme.primaryGradient)
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(client.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? client.email : client.fullName)
                                            .font(.neueCaptionMedium)
                                            .foregroundStyle(AVIATheme.textPrimary)
                                        Text(client.email)
                                            .font(.neueCaption2)
                                            .foregroundStyle(AVIATheme.textTertiary)
                                    }

                                    Spacer()

                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(AVIATheme.timelessBrown)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
            }

            if !selectedClientIds.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.neueCorp(12))
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text("Selected clients will be notified and can review the package in their app.")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                .padding(12)
                .background(AVIATheme.timelessBrown.opacity(0.06))
                .clipShape(.rect(cornerRadius: 12))
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

            HStack(spacing: 12) {
                if currentStep > 0 {
                    Button {
                        withAnimation(.spring(response: 0.35)) { currentStep -= 1 }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.neueCaptionMedium)
                            Text("Back")
                                .font(.neueCaptionMedium)
                        }
                        .foregroundStyle(AVIATheme.textSecondary)
                        .frame(height: 48)
                        .padding(.horizontal, 16)
                        .background(AVIATheme.cardBackground)
                        .clipShape(.rect(cornerRadius: 12))
                    }
                }

                Spacer()

                if currentStep < 3 {
                    Button {
                        withAnimation(.spring(response: 0.35)) { currentStep += 1 }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Next")
                                .font(.neueCaptionMedium)
                            Image(systemName: "chevron.right")
                                .font(.neueCaptionMedium)
                        }
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .frame(height: 48)
                        .padding(.horizontal, 24)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(.rect(cornerRadius: 12))
                    }
                } else {
                    Button {
                        savePackage()
                    } label: {
                        HStack(spacing: 8) {
                            if isSaving {
                                ProgressView()
                                    .tint(AVIATheme.aviaWhite)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: isEditing ? "checkmark.circle.fill" : "plus.circle.fill")
                                    .font(.neueCaptionMedium)
                            }
                            Text(isEditing ? "Save Changes" : "Create & Assign")
                                .font(.neueSubheadlineMedium)
                        }
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .frame(height: 48)
                        .padding(.horizontal, 24)
                        .background(canSave ? AVIATheme.primaryGradient : LinearGradient(colors: [AVIATheme.surfaceElevated], startPoint: .top, endPoint: .bottom))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .disabled(!canSave || isSaving)
                    .sensoryFeedback(.impact(weight: .medium), trigger: isSaving)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AVIATheme.cardBackground)
    }

    // MARK: - Shared Components

    private func sectionHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AVIATheme.timelessBrown)
                .frame(width: 40, height: 40)
                .background(AVIATheme.timelessBrown.opacity(0.1))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Text(subtitle)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            Spacer()
        }
    }

    private func editorField(label: String, text: Binding<String>, placeholder: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.neueCorp(12))
                .foregroundStyle(AVIATheme.timelessBrown)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                TextField(placeholder, text: text)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textPrimary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var fieldDivider: some View {
        Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 54)
    }

    // MARK: - Actions

    private func addInclusion() {
        let trimmed = newInclusion.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        withAnimation { inclusions.append(trimmed) }
        newInclusion = ""
    }

    private func populateFromExisting() {
        guard let pkg = existingPackage else { return }
        title = pkg.title
        location = pkg.location
        lotSize = pkg.lotSize
        lotNumber = pkg.lotNumber
        lotFrontage = pkg.lotFrontage
        lotDepth = pkg.lotDepth
        landPrice = pkg.landPrice
        housePrice = pkg.housePrice
        totalPrice = pkg.price
        imageURL = pkg.imageURL
        selectedSpecTier = pkg.specTier
        titleDate = pkg.titleDate
        council = pkg.council
        zoning = pkg.zoning
        buildTimeEstimate = pkg.buildTimeEstimate
        isNew = pkg.isNew
        inclusions = pkg.inclusions
        isCustomHome = pkg.isCustom
        selectedFacadeId = pkg.selectedFacadeId ?? ""

        if pkg.isCustom {
            customDesignName = pkg.homeDesign
            customBedrooms = pkg.customBedrooms ?? 4
            customBathrooms = pkg.customBathrooms ?? 2
            customGarages = pkg.customGarages ?? 2
            customSquareMeters = pkg.customSquareMeters.map { String(format: "%.0f", $0) } ?? ""
            customStoreys = pkg.customStoreys ?? 1
        } else {
            let designName = pkg.homeDesign.components(separatedBy: " ").first ?? ""
            if let design = designs.first(where: { $0.name.lowercased() == designName.lowercased() }) {
                selectedDesignId = design.id
            }
        }

        if let assignment = viewModel.assignmentForPackage(pkg.id) {
            selectedClientIds = Set(assignment.sharedWithClientIds)
        }
    }

    private func savePackage() {
        guard canSave else { return }
        isSaving = true

        let designDisplay: String
        if isCustomHome {
            designDisplay = customDesignName.trimmingCharacters(in: .whitespaces)
        } else if let design = selectedDesign {
            designDisplay = "\(design.name) \(Int(design.squareMeters))"
        } else {
            designDisplay = title.components(separatedBy: " at").first ?? title
        }

        let imgURL: String
        if !imageURL.isEmpty {
            imgURL = imageURL
        } else if isCustomHome, let facadeImg = selectedFacade?.heroImageURL {
            imgURL = facadeImg
        } else {
            imgURL = selectedDesign?.imageURL ?? ""
        }

        let sqm = Double(customSquareMeters)

        let pkg = HouseLandPackage(
            id: existingPackage?.id ?? UUID().uuidString,
            title: title.trimmingCharacters(in: .whitespaces),
            location: location.trimmingCharacters(in: .whitespaces),
            lotSize: lotSize.trimmingCharacters(in: .whitespaces),
            homeDesign: designDisplay,
            price: totalPrice.trimmingCharacters(in: .whitespaces),
            imageURL: imgURL,
            isNew: isNew,
            lotNumber: lotNumber.trimmingCharacters(in: .whitespaces),
            lotFrontage: lotFrontage.trimmingCharacters(in: .whitespaces),
            lotDepth: lotDepth.trimmingCharacters(in: .whitespaces),
            landPrice: landPrice.trimmingCharacters(in: .whitespaces),
            housePrice: housePrice.trimmingCharacters(in: .whitespaces),
            specTier: selectedSpecTier,
            titleDate: titleDate.trimmingCharacters(in: .whitespaces),
            council: council.trimmingCharacters(in: .whitespaces),
            zoning: zoning.trimmingCharacters(in: .whitespaces),
            buildTimeEstimate: buildTimeEstimate.trimmingCharacters(in: .whitespaces),
            inclusions: inclusions,
            isCustom: isCustomHome,
            customBedrooms: isCustomHome ? customBedrooms : nil,
            customBathrooms: isCustomHome ? customBathrooms : nil,
            customGarages: isCustomHome ? customGarages : nil,
            customSquareMeters: isCustomHome ? sqm : nil,
            customStoreys: isCustomHome ? customStoreys : nil,
            selectedFacadeId: isCustomHome && !selectedFacadeId.isEmpty ? selectedFacadeId : nil
        )

        if isEditing {
            viewModel.updatePackage(pkg)
            let currentAssignment = viewModel.assignmentForPackage(pkg.id)
            let currentClientIds = Set(currentAssignment?.sharedWithClientIds ?? [])

            let toAdd = selectedClientIds.subtracting(currentClientIds)
            let toRemove = currentClientIds.subtracting(selectedClientIds)

            for clientId in toAdd {
                viewModel.sharePackageWithClient(packageId: pkg.id, clientId: clientId)
            }
            for clientId in toRemove {
                viewModel.removeClientFromPackage(packageId: pkg.id, clientId: clientId)
            }
        } else {
            viewModel.createPackageAndAssignClients(pkg, clientIds: Array(selectedClientIds))
        }

        isSaving = false
        dismiss()
    }
}
