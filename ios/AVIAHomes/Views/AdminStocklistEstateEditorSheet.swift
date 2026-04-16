import SwiftUI

struct AdminStocklistEstateEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let estate: StocklistEstateRow?
    let viewModel: StocklistViewModel

    @State private var name: String = ""
    @State private var region: String = "Brisbane"
    @State private var subRegion: String? = nil
    @State private var depositTerms: String = ""
    @State private var sortOrder: Int = 0
    @State private var isActive: Bool = true
    @State private var isSaving = false
    @State private var showDeleteConfirm = false

    private var isNew: Bool { estate == nil }

    private static let regionOptions = ["Brisbane", "Gold Coast", "Sunshine Coast", "Toowoomba"]
    private static let brisbaneSubRegions = ["North Brisbane", "West Brisbane", "South Brisbane"]

    init(estate: StocklistEstateRow?, viewModel: StocklistViewModel) {
        self.estate = estate
        self.viewModel = viewModel
        if let estate = estate {
            _name = State(initialValue: estate.name)
            _region = State(initialValue: estate.region)
            _subRegion = State(initialValue: estate.sub_region)
            _depositTerms = State(initialValue: estate.deposit_terms ?? "")
            _sortOrder = State(initialValue: estate.sort_order)
            _isActive = State(initialValue: estate.is_active)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Estate Name")
                            .font(.neueCaption2Medium)
                            .foregroundStyle(AVIATheme.textTertiary)
                        TextField("Estate name", text: $name)
                            .font(.neueCaption)
                            .padding(12)
                            .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Region picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Region")
                            .font(.neueCaption2Medium)
                            .foregroundStyle(AVIATheme.textTertiary)
                        Picker("Region", selection: $region) {
                            ForEach(Self.regionOptions, id: \.self) { r in
                                Text(r).tag(r)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Sub-region picker (Brisbane only)
                    if region == "Brisbane" {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sub-Region")
                                .font(.neueCaption2Medium)
                                .foregroundStyle(AVIATheme.textTertiary)
                            Picker("Sub-Region", selection: Binding(
                                get: { subRegion ?? Self.brisbaneSubRegions[0] },
                                set: { subRegion = $0 }
                            )) {
                                ForEach(Self.brisbaneSubRegions, id: \.self) { sr in
                                    Text(sr).tag(sr)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    // Deposit terms
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Deposit Terms")
                            .font(.neueCaption2Medium)
                            .foregroundStyle(AVIATheme.textTertiary)
                        TextEditor(text: $depositTerms)
                            .font(.neueCaption)
                            .frame(minHeight: 80)
                            .padding(8)
                            .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                            .scrollContentBackground(.hidden)
                    }

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

                    // Is Active toggle
                    Toggle(isOn: $isActive) {
                        Text("Active")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                    }
                    .tint(AVIATheme.timelessBrown)
                    .padding(12)
                    .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))

                    // Save button
                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(AVIATheme.aviaWhite)
                            }
                            Text(isNew ? "Create Estate" : "Save Changes")
                                .font(.neueCaptionMedium)
                        }
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AVIATheme.primaryGradient, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(name.isEmpty || isSaving)

                    // Delete button (edit mode only)
                    if !isNew {
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Estate")
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
            .navigationTitle(isNew ? "Add Estate" : "Edit Estate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(AVIATheme.timelessBrown)
                }
            }
            .alert("Delete Estate", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    Task {
                        if let estate = estate {
                            await viewModel.deleteEstate(estate.id)
                            dismiss()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure? This will permanently delete \"\(name)\" and cannot be undone.")
            }
        }
    }

    private func save() async {
        isSaving = true
        let row = StocklistEstateRow(
            id: estate?.id ?? UUID().uuidString,
            name: name,
            region: region,
            sub_region: region == "Brisbane" ? (subRegion ?? Self.brisbaneSubRegions[0]) : nil,
            deposit_terms: depositTerms.isEmpty ? nil : depositTerms,
            estate_brochure_url: estate?.estate_brochure_url,
            rental_appraisal_url: estate?.rental_appraisal_url,
            eoi_form_url: estate?.eoi_form_url,
            sort_order: sortOrder,
            is_active: isActive,
            created_at: estate?.created_at,
            updated_at: nil
        )
        await viewModel.saveEstate(row)
        isSaving = false
        dismiss()
    }
}
