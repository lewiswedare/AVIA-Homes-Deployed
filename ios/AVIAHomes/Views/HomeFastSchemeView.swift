import SwiftUI

struct HomeFastSchemeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ColourSelectionViewModel.self) private var viewModel
    @State private var selectedScheme: HomeFastScheme?
    @State private var showConfirmation = false
    @State private var animateTrigger = 0

    private var schemes: [HomeFastScheme] { CatalogDataManager.shared.allSchemes }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard

                    ForEach(schemes) { scheme in
                        SchemeCard(
                            scheme: scheme,
                            isApplied: viewModel.appliedScheme?.id == scheme.id,
                            isSelected: selectedScheme?.id == scheme.id
                        ) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                selectedScheme = scheme
                            }
                            animateTrigger += 1
                        }

                        if selectedScheme?.id == scheme.id {
                            schemeRoomGallery(for: scheme)
                                .transition(.opacity.combined(with: .move(edge: .top)))

                            schemeBreakdown(for: scheme)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                    if selectedScheme != nil {
                        applyButton
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(AVIATheme.background)
            .navigationTitle("HomeFast Schemes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.neueSubheadlineMedium)
                        .tint(AVIATheme.timelessBrown)
                }
            }
            .sensoryFeedback(.selection, trigger: animateTrigger)
            .alert("Apply Colour Scheme?", isPresented: $showConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Apply") {
                    if let scheme = selectedScheme {
                        withAnimation(.spring(response: 0.4)) {
                            viewModel.applyScheme(scheme)
                        }
                        dismiss()
                    }
                }
            } message: {
                if let scheme = selectedScheme {
                    Text("This will replace all your current colour selections with the \(scheme.name) HomeFast scheme.")
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.neueTitle3)
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .frame(width: 44, height: 44)
                    .background(AVIATheme.timelessBrown.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text("HomeFast")
                        .font(.neueHeadline)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Pre-designed colour schemes")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
            }

            Text("Choose from our professionally curated colour schemes, designed by our interior team. Each scheme coordinates all exterior and interior selections for a beautifully harmonised home.")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 18))
    }

    private func schemeBreakdown(for scheme: HomeFastScheme) -> some View {
        let catalog = CatalogDataManager.shared
        let availableIds = catalog.availableColourCategoryIds(for: viewModel.specTier)
        let allCategories = catalog.allColourCategories
        let exteriorItems = allCategories.filter { $0.section == .exterior && availableIds.contains($0.id) && scheme.selections[$0.id] != nil }
        let interiorItems = allCategories.filter { $0.section == .interior && availableIds.contains($0.id) && scheme.selections[$0.id] != nil }

        return VStack(alignment: .leading, spacing: 14) {
            if !exteriorItems.isEmpty {
                sectionBreakdown(title: "Exterior", categories: exteriorItems, scheme: scheme)
            }
            if !interiorItems.isEmpty {
                sectionBreakdown(title: "Interior", categories: interiorItems, scheme: scheme)
            }
        }
        .padding(16)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 18))
    }

    private func sectionBreakdown(title: String, categories: [ColourCategory], scheme: HomeFastScheme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.neueCaption2Medium)
                .kerning(1.2)
                .foregroundStyle(AVIATheme.textTertiary)

            ForEach(categories) { category in
                if let sel = scheme.selections[category.id] {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: sel.hexColor))
                            .frame(width: 28, height: 28)
                            .overlay {
                                Circle().stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                            }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(category.name)
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Text(sel.optionName)
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textSecondary)
                        }

                        Spacer()

                        if viewModel.selections[category.id]?.optionId == sel.optionId {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.success)
                        }
                    }

                    if category.id != categories.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func schemeRoomGallery(for scheme: HomeFastScheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PREVIEW".uppercased())
                .font(.neueCaption2Medium)
                .kerning(1.2)
                .foregroundStyle(AVIATheme.textTertiary)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(scheme.roomImages, id: \.room) { roomImage in
                        VStack(spacing: 8) {
                            Color(.secondarySystemBackground)
                                .frame(width: 240, height: 160)
                                .overlay {
                                    Image(roomImage.assetName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .allowsHitTesting(false)
                                }
                                .clipShape(.rect(cornerRadius: 12))

                            Text(roomImage.label)
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .contentMargins(.horizontal, 0)
            .padding(.bottom, 16)
        }
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 18))
    }

    private var applyButton: some View {
        Button {
            showConfirmation = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "paintpalette.fill")
                Text("Apply \(selectedScheme?.name ?? "") Scheme")
            }
            .font(.neueSubheadlineMedium)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(.white)
            .background(AVIATheme.primaryGradient)
            .clipShape(.rect(cornerRadius: 16))
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

struct SchemeCard: View {
    let scheme: HomeFastScheme
    let isApplied: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(Array(scheme.previewColors.enumerated()), id: \.offset) { _, hex in
                        Color(hex: hex)
                    }
                }
                .frame(height: 56)
                .clipShape(.rect(topLeadingRadius: 18, topTrailingRadius: 18))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(scheme.name)
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Text(scheme.subtitle)
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)
                        }
                        Spacer()

                        if isApplied {
                            Label("Applied", systemImage: "checkmark.circle.fill")
                                .font(.neueCaption2Medium)
                                .foregroundStyle(AVIATheme.success)
                        }
                    }

                    HStack(spacing: 6) {
                        Text("\(scheme.selections.count) selections")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)

                        Text("·")
                            .foregroundStyle(AVIATheme.textTertiary)

                        Text("Exterior & Interior")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: -6) {
                            ForEach(Array(scheme.previewColors.prefix(8).enumerated()), id: \.offset) { _, hex in
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 26, height: 26)
                                    .overlay {
                                        Circle().stroke(AVIATheme.cardBackground, lineWidth: 2)
                                    }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(AVIATheme.cardBackground)
            .clipShape(.rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isSelected ? AVIATheme.timelessBrown : (isApplied ? AVIATheme.success.opacity(0.3) : Color.clear),
                        lineWidth: isSelected ? 2.5 : 1
                    )
            }
            .shadow(color: isSelected ? AVIATheme.timelessBrown.opacity(0.12) : .clear, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}
