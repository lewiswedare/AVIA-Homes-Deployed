import SwiftUI

struct ColourDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ColourSelectionViewModel.self) private var viewModel
    let category: ColourCategory
    @State private var animateTrigger = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    categoryImage

                    tierInfoBanner

                    if let note = category.note {
                        noteCard(note)
                    }

                    currentSelectionBanner

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Available Options")
                            .font(.neueHeadline)
                            .foregroundStyle(AVIATheme.textPrimary)

                        if let brand = category.options.first?.brand {
                            Text(brand)
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)
                        }
                    }

                    optionsGrid
                }
                .padding(20)
            }
            .background(AVIATheme.background)
            .navigationTitle(category.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.neueSubheadlineMedium)
                        .tint(AVIATheme.teal)
                }
            }
            .sensoryFeedback(.selection, trigger: animateTrigger)
        }
        .presentationBackground(AVIATheme.background)
    }

    private var selectedColour: SelectionChoice? {
        viewModel.selection(for: category.id)
    }

    @ViewBuilder
    private var categoryImage: some View {
        if let imageURL = category.imageURL {
            Color(AVIATheme.surfaceElevated)
                .frame(height: 220)
                .overlay {
                    if imageURL.hasPrefix("http") {
                        AsyncImage(url: URL(string: imageURL)) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else if phase.error != nil {
                                Image(systemName: category.icon)
                                    .font(.system(size: 32))
                                    .foregroundStyle(AVIATheme.textTertiary)
                            } else {
                                ProgressView()
                            }
                        }
                        .allowsHitTesting(false)
                    } else {
                        Image(imageURL)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
                }
                .overlay {
                    if let selection = selectedColour {
                        Color(hex: selection.hexColor)
                            .opacity(0.45)
                            .blendMode(.multiply)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                }
                .clipShape(.rect(cornerRadius: 14))
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 10) {
                        if let selection = selectedColour {
                            Circle()
                                .fill(Color(hex: selection.hexColor))
                                .frame(width: 28, height: 28)
                                .overlay {
                                    Circle().stroke(.white.opacity(0.5), lineWidth: 1.5)
                                }
                                .transition(.scale.combined(with: .opacity))
                        }
                        Text(selectedColour?.optionName ?? category.name)
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.5))
                    .clipShape(.rect(cornerRadius: 8))
                    .padding(10)
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedColour?.optionId)
        }
    }

    private func noteCard(_ note: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(AVIATheme.teal)
            Text(note)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AVIATheme.teal.opacity(0.08))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var selectedOption: ColourOption? {
        guard let sel = viewModel.selection(for: category.id) else { return nil }
        return category.options.first { $0.id == sel.optionId }
    }

    @ViewBuilder
    private var currentSelectionBanner: some View {
        if let selection = viewModel.selection(for: category.id) {
            HStack(spacing: 12) {
                if let opt = selectedOption, let imgURL = opt.imageURL, !imgURL.isEmpty {
                    Color(.secondarySystemBackground)
                        .frame(width: 44, height: 44)
                        .overlay {
                            AsyncImage(url: URL(string: imgURL)) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    Circle()
                                        .fill(Color(hex: selection.hexColor))
                                        .padding(4)
                                }
                            }
                            .allowsHitTesting(false)
                        }
                        .clipShape(.rect(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                        }
                } else {
                    Circle()
                        .fill(Color(hex: selection.hexColor))
                        .frame(width: 38, height: 38)
                        .overlay {
                            Circle().stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                        }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Selection")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                    Text(selection.optionName)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                }
                Spacer()
                Button {
                    viewModel.clearSelection(for: category.id)
                    animateTrigger += 1
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AVIATheme.textTertiary)
                }
            }
            .padding(14)
            .background(AVIATheme.cardBackground)
            .clipShape(.rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AVIATheme.teal.opacity(0.2), lineWidth: 1)
            }
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(response: 0.3), value: selection.optionId)
        }
    }

    private var tierInfoBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: viewModel.specTier.icon)
                .foregroundStyle(AVIATheme.teal)
            Text("Showing options for your **\(viewModel.specTier.rawValue)** spec range")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AVIATheme.teal.opacity(0.06))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var optionsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]

        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(category.options) { option in
                let isTierUpgrade = option.isUpgradeOption(for: viewModel.specTier)
                ColourSwatchView(
                    option: option,
                    isSelected: viewModel.isSelected(categoryId: category.id, optionId: option.id),
                    isTierUpgrade: isTierUpgrade
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.select(option: option, for: category)
                    }
                    animateTrigger += 1
                }
            }
        }
    }
}

struct ColourSwatchView: View {
    let option: ColourOption
    let isSelected: Bool
    var isTierUpgrade: Bool = false
    let action: () -> Void

    private var swatchColor: Color {
        Color(hex: option.hexColor)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if let imageURL = option.imageURL, !imageURL.isEmpty {
                    imageSwatchContent(imageURL)
                } else {
                    circleSwatchContent
                }

                Text(option.name)
                    .font(isSelected ? .neueCaption2Medium : .neueCaption2)
                    .foregroundStyle(isSelected ? AVIATheme.teal : AVIATheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 28)

                if isTierUpgrade {
                    Text("UPGRADE")
                        .font(.neueCorpMedium(7))
                        .foregroundStyle(AVIATheme.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AVIATheme.warning.opacity(0.1))
                        .clipShape(Capsule())
                } else if option.isUpgrade {
                    Text("PREMIUM")
                        .font(.neueCorpMedium(7))
                        .foregroundStyle(AVIATheme.teal)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AVIATheme.teal.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 8)
            .opacity(isTierUpgrade ? 0.7 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private func imageSwatchContent(_ urlString: String) -> some View {
        Color(.secondarySystemBackground)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                AsyncImage(url: URL(string: urlString)) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if phase.error != nil {
                        Circle()
                            .fill(swatchColor)
                            .padding(8)
                    } else {
                        ProgressView()
                            .tint(AVIATheme.teal)
                    }
                }
                .allowsHitTesting(false)
            }
            .clipShape(.rect(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? AVIATheme.teal : AVIATheme.surfaceBorder, lineWidth: isSelected ? 2.5 : 1)
            }
            .overlay(alignment: .bottomTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, AVIATheme.teal)
                        .offset(x: 4, y: 4)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .shadow(color: isSelected ? AVIATheme.teal.opacity(0.25) : .clear, radius: 6, y: 2)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    private var circleSwatchContent: some View {
        ZStack {
            Circle()
                .fill(swatchColor)
                .frame(width: 52, height: 52)
                .overlay {
                    Circle().stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                }
                .shadow(color: swatchColor.opacity(isSelected ? 0.3 : 0.1), radius: isSelected ? 8 : 4, y: 2)
                .overlay {
                    if isSelected {
                        Circle()
                            .stroke(AVIATheme.teal, lineWidth: 3)
                            .frame(width: 62, height: 62)
                    }
                }
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.neueBody)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, AVIATheme.teal)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
        }
        .frame(height: 66)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
