import SwiftUI

struct GuidedColourFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ColourSelectionViewModel.self) private var viewModel
    @State private var currentIndex = 0
    @State private var animateTrigger = 0

    private var categories: [ColourCategory] {
        viewModel.allFilteredCategories
    }

    private var currentCategory: ColourCategory? {
        guard currentIndex < categories.count else { return nil }
        return categories[currentIndex]
    }

    private var progress: Double {
        Double(currentIndex + 1) / Double(categories.count)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar

                if let category = currentCategory {
                    stepContent(for: category)
                }

                navigationButtons
            }
            .background(AVIATheme.background)
            .navigationTitle("Guided Selection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .tint(AVIATheme.timelessBrown)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(currentIndex + 1) of \(categories.count)")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
            }
            .sensoryFeedback(.selection, trigger: animateTrigger)
        }
    }

    private var progressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AVIATheme.timelessBrown.opacity(0.1))
                        .frame(height: 4)
                    Capsule()
                        .fill(AVIATheme.primaryGradient)
                        .frame(width: max(0, geo.size.width * progress), height: 4)
                        .animation(.spring(response: 0.3), value: progress)
                }
            }
            .frame(height: 4)

            if let category = currentCategory {
                HStack {
                    Text(category.section.rawValue.uppercased())
                        .font(.neueCaption2Medium)
                        .kerning(1.5)
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Spacer()
                    if viewModel.selection(for: category.id) != nil {
                        Label("Selected", systemImage: "checkmark.circle.fill")
                            .font(.neueCaption2Medium)
                            .foregroundStyle(AVIATheme.success)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(AVIATheme.cardBackground)
    }

    private func stepContent(for category: ColourCategory) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(category.name)
                        .font(.neueCorpMedium(22))
                        .foregroundStyle(AVIATheme.textPrimary)
                    if let note = category.note {
                        Text(note)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                if let selection = viewModel.selection(for: category.id) {
                    let selectedOpt = category.options.first { $0.id == selection.optionId }
                    HStack(spacing: 12) {
                        if let imgURL = selectedOpt?.imageURL, !imgURL.isEmpty {
                            Color(.secondarySystemBackground)
                                .frame(width: 36, height: 36)
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
                                .frame(width: 30, height: 30)
                                .overlay { Circle().stroke(AVIATheme.surfaceBorder, lineWidth: 1) }
                        }
                        Text(selection.optionName)
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Spacer()
                        Button("Clear") {
                            viewModel.clearSelection(for: category.id)
                            animateTrigger += 1
                        }
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.destructive)
                    }
                    .padding(14)
                    .background(AVIATheme.cardBackground)
                    .clipShape(.rect(cornerRadius: 14))
                    .padding(.horizontal, 20)
                }

                let columns = [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ]

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(category.options) { option in
                        ColourSwatchView(
                            option: option,
                            isSelected: viewModel.isSelected(categoryId: category.id, optionId: option.id),
                            isTierUpgrade: option.isUpgradeOption(for: viewModel.specTier)
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.select(option: option, for: category)
                            }
                            animateTrigger += 1
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 24)
        }
        .id(category.id)
    }

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentIndex > 0 {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        currentIndex -= 1
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.neueSubheadlineMedium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .background(AVIATheme.timelessBrown.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 14))
                }
            }

            if currentIndex < categories.count - 1 {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        currentIndex += 1
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.selection(for: currentCategory?.id ?? "") != nil ? "Next" : "Skip")
                        Image(systemName: "chevron.right")
                    }
                    .font(.neueSubheadlineMedium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(.white)
                    .background(AVIATheme.primaryGradient)
                    .clipShape(.rect(cornerRadius: 14))
                }
            } else {
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        viewModel.showSummary = true
                    }
                } label: {
                    Text("Review Selections")
                        .font(.neueSubheadlineMedium)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(.white)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(.rect(cornerRadius: 14))
                }
            }
        }
        .padding(16)
        .background(AVIATheme.cardBackground)
    }
}
