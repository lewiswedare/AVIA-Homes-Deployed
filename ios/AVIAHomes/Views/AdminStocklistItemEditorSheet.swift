import SwiftUI

struct AdminStocklistItemEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let item: StocklistItemRow?
    let estateId: String
    let viewModel: StocklistViewModel

    @State private var lotNumber: String = ""
    @State private var stage: String = ""
    @State private var street: String = ""
    @State private var landSize: String = ""
    @State private var landPrice: String = ""
    @State private var registered: String = ""
    @State private var designFacade: String = ""
    @State private var buildSize: String = ""
    @State private var bedrooms: String = ""
    @State private var bathrooms: String = ""
    @State private var garages: String = ""
    @State private var theatre: String = ""
    @State private var buildPrice: String = ""
    @State private var packagePrice: String = ""
    @State private var specification: String = "Volos"
    @State private var status: String = "Available"
    @State private var ownerOccInvestor: String = "Owner Occ & Investor"
    @State private var availability: String = ""
    @State private var salesPackageLink: String = ""
    @State private var isComingSoon: Bool = false
    @State private var sortOrder: Int = 0
    @State private var isSaving = false
    @State private var showDeleteConfirm = false

    private var isNew: Bool { item == nil }

    private static let statusOptions = ["Available", "EOI", "ON HOLD", "COMING SOON", "Available (Exclusive)", "Sold"]
    private static let ownerOccOptions = ["Owner Occ & Investor", "Owner Occ Only", "Investor Only"]

    init(item: StocklistItemRow?, estateId: String, viewModel: StocklistViewModel) {
        self.item = item
        self.estateId = estateId
        self.viewModel = viewModel
        if let item = item {
            _lotNumber = State(initialValue: item.lot_number)
            _stage = State(initialValue: item.stage ?? "")
            _street = State(initialValue: item.street ?? "")
            _landSize = State(initialValue: item.land_size ?? "")
            _landPrice = State(initialValue: item.land_price ?? "")
            _registered = State(initialValue: item.registered ?? "")
            _designFacade = State(initialValue: item.design_facade ?? "")
            _buildSize = State(initialValue: item.build_size ?? "")
            _bedrooms = State(initialValue: item.bedrooms ?? "")
            _bathrooms = State(initialValue: item.bathrooms ?? "")
            _garages = State(initialValue: item.garages ?? "")
            _theatre = State(initialValue: item.theatre ?? "")
            _buildPrice = State(initialValue: item.build_price ?? "")
            _packagePrice = State(initialValue: item.package_price ?? "")
            _specification = State(initialValue: item.specification ?? "Volos")
            _status = State(initialValue: item.status)
            _ownerOccInvestor = State(initialValue: item.owner_occ_investor ?? "Owner Occ & Investor")
            _availability = State(initialValue: item.availability ?? "")
            _salesPackageLink = State(initialValue: item.sales_package_link ?? "")
            _isComingSoon = State(initialValue: item.is_coming_soon)
            _sortOrder = State(initialValue: item.sort_order)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Lot number (required)
                    fieldSection(title: "Lot Number *") {
                        TextField("Lot number", text: $lotNumber)
                            .font(.neueCaption)
                            .padding(12)
                            .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Stage & Street
                    HStack(spacing: 12) {
                        fieldSection(title: "Stage") {
                            TextField("Stage", text: $stage)
                                .font(.neueCaption)
                                .padding(12)
                                .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                        }
                        fieldSection(title: "Street") {
                            TextField("Street", text: $street)
                                .font(.neueCaption)
                                .padding(12)
                                .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    // Land size & Land price
                    HStack(spacing: 12) {
                        fieldSection(title: "Land Size") {
                            TextField("e.g. 375m²", text: $landSize)
                                .font(.neueCaption)
                                .padding(12)
                                .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                        }
                        fieldSection(title: "Land Price") {
                            TextField("e.g. $250,000", text: $landPrice)
                                .font(.neueCaption)
                                .padding(12)
                                .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    // Registered
                    fieldSection(title: "Registered") {
                        TextField("e.g. Registered, Q2 2026", text: $registered)
                            .font(.neueCaption)
                            .padding(12)
                            .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Design & Facade
                    fieldSection(title: "Design & Facade") {
                        TextField("e.g. Aria 25 / Modern", text: $designFacade)
                            .font(.neueCaption)
                            .padding(12)
                            .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Build size & specs
                    HStack(spacing: 12) {
                        fieldSection(title: "Build Size") {
                            TextField("e.g. 190.8m²", text: $buildSize)
                                .font(.neueCaption)
                                .padding(12)
                                .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                        }
                        fieldSection(title: "Bedrooms") {
                            TextField("e.g. 4", text: $bedrooms)
                                .font(.neueCaption)
                                .keyboardType(.numberPad)
                                .padding(12)
                                .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    HStack(spacing: 12) {
                        fieldSection(title: "Bathrooms") {
                            TextField("e.g. 2", text: $bathrooms)
                                .font(.neueCaption)
                                .keyboardType(.numberPad)
                                .padding(12)
                                .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                        }
                        fieldSection(title: "Garages") {
                            TextField("e.g. 2", text: $garages)
                                .font(.neueCaption)
                                .keyboardType(.numberPad)
                                .padding(12)
                                .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    fieldSection(title: "Theatre") {
                        TextField("e.g. 1 or 0", text: $theatre)
                            .font(.neueCaption)
                            .keyboardType(.numberPad)
                            .padding(12)
                            .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Pricing
                    HStack(spacing: 12) {
                        fieldSection(title: "Build Price") {
                            TextField("e.g. $280,000", text: $buildPrice)
                                .font(.neueCaption)
                                .padding(12)
                                .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                        }
                        fieldSection(title: "Package Price") {
                            TextField("e.g. $530,000", text: $packagePrice)
                                .font(.neueCaption)
                                .padding(12)
                                .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    // Specification
                    fieldSection(title: "Specification") {
                        TextField("e.g. Volos", text: $specification)
                            .font(.neueCaption)
                            .padding(12)
                            .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Status picker
                    fieldSection(title: "Status") {
                        Picker("Status", selection: $status) {
                            ForEach(Self.statusOptions, id: \.self) { s in
                                Text(s).tag(s)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Owner Occ / Investor picker
                    fieldSection(title: "Owner Occ / Investor") {
                        Picker("Owner Occ / Investor", selection: $ownerOccInvestor) {
                            ForEach(Self.ownerOccOptions, id: \.self) { o in
                                Text(o).tag(o)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Availability
                    fieldSection(title: "Availability") {
                        TextField("e.g. Immediate, Q3 2026", text: $availability)
                            .font(.neueCaption)
                            .padding(12)
                            .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Sales Package Link
                    fieldSection(title: "Sales Package Link") {
                        TextField("https://...", text: $salesPackageLink)
                            .font(.neueCaption)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .padding(12)
                            .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Is Coming Soon toggle
                    Toggle(isOn: $isComingSoon) {
                        Text("Coming Soon")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                    }
                    .tint(AVIATheme.timelessBrown)
                    .padding(12)
                    .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))

                    // Sort order
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sort Order")
                            .font(.neueCaption2Medium)
                            .foregroundStyle(AVIATheme.textTertiary)
                        Stepper("Sort Order: \(sortOrder)", value: $sortOrder, in: 0...999)
                            .font(.neueCaption)
                            .padding(12)
                            .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Save button
                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(AVIATheme.aviaWhite)
                            }
                            Text(isNew ? "Create Lot" : "Save Changes")
                                .font(.neueCaptionMedium)
                        }
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AVIATheme.primaryGradient, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(lotNumber.isEmpty || isSaving)

                    // Delete button (edit mode only)
                    if !isNew {
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Lot")
                                    .font(.neueCaptionMedium)
                            }
                            .foregroundStyle(AVIATheme.destructive)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AVIATheme.destructive.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(AVIATheme.background)
            .navigationTitle(isNew ? "Add Lot" : "Edit Lot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(AVIATheme.timelessBrown)
                }
            }
            .alert("Delete Lot", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    Task {
                        if let item = item {
                            await viewModel.deleteLot(item.id)
                            dismiss()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure? This will permanently delete Lot \(lotNumber) and cannot be undone.")
            }
        }
    }

    private func fieldSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.neueCaption2Medium)
                .foregroundStyle(AVIATheme.textTertiary)
            content()
        }
    }

    private func save() async {
        isSaving = true
        let row = StocklistItemRow(
            id: item?.id ?? UUID().uuidString,
            estate_id: estateId,
            lot_number: lotNumber,
            stage: stage.isEmpty ? nil : stage,
            street: street.isEmpty ? nil : street,
            land_size: landSize.isEmpty ? nil : landSize,
            land_price: landPrice.isEmpty ? nil : landPrice,
            registered: registered.isEmpty ? nil : registered,
            design_facade: designFacade.isEmpty ? nil : designFacade,
            build_size: buildSize.isEmpty ? nil : buildSize,
            bedrooms: bedrooms.isEmpty ? nil : bedrooms,
            bathrooms: bathrooms.isEmpty ? nil : bathrooms,
            garages: garages.isEmpty ? nil : garages,
            theatre: theatre.isEmpty ? nil : theatre,
            build_price: buildPrice.isEmpty ? nil : buildPrice,
            package_price: packagePrice.isEmpty ? nil : packagePrice,
            specification: specification.isEmpty ? nil : specification,
            status: status,
            owner_occ_investor: ownerOccInvestor.isEmpty ? nil : ownerOccInvestor,
            availability: availability.isEmpty ? nil : availability,
            sales_package_link: salesPackageLink.isEmpty ? nil : salesPackageLink,
            is_coming_soon: isComingSoon,
            sort_order: sortOrder,
            created_at: item?.created_at,
            updated_at: nil
        )
        await viewModel.saveLot(row)
        isSaving = false
        dismiss()
    }
}
