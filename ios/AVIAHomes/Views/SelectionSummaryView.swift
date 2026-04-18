import SwiftUI

struct SelectionSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ColourSelectionViewModel.self) private var viewModel

    private var exteriorSelections: [(ColourCategory, SelectionChoice)] {
        viewModel.exteriorCategories.compactMap { category in
            guard let selection = viewModel.selection(for: category.id) else { return nil }
            return (category, selection)
        }
    }

    private var interiorSelections: [(ColourCategory, SelectionChoice)] {
        viewModel.interiorCategories.compactMap { category in
            guard let selection = viewModel.selection(for: category.id) else { return nil }
            return (category, selection)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.completedCount == 0 {
                    ContentUnavailableView(
                        "No Previews Yet",
                        systemImage: "paintpalette",
                        description: Text("Browse the Colour Library to preview colours and finishes. Your final selections are made on your live build once specs are approved.")
                    )
                    .foregroundStyle(AVIATheme.textSecondary)
                } else {
                    selectionsList
                }
            }
            .background(AVIATheme.background)
            .navigationTitle("Preview Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.neueSubheadlineMedium)
                        .tint(AVIATheme.timelessBrown)
                }
            }
        }
        .presentationBackground(AVIATheme.background)
    }

    private var selectionsList: some View {
        ScrollView {
            VStack(spacing: 20) {
                statusBanner
                libraryNotice

                if !exteriorSelections.isEmpty {
                    selectionSection(title: "Exterior", selections: exteriorSelections)
                }
                if !interiorSelections.isEmpty {
                    selectionSection(title: "Interior", selections: interiorSelections)
                }
            }
            .padding(20)
        }
    }

    private var libraryNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(AVIATheme.timelessBrown)
            Text("These are preview-only previews. Your official colour choices are made on your live build once the AVIA team approves your Stage 1 specifications.")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AVIATheme.timelessBrown.opacity(0.06))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var statusBanner: some View {
        BentoCard(cornerRadius: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(AVIATheme.timelessBrown.opacity(0.12), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: viewModel.completionProgress)
                        .stroke(AVIATheme.timelessBrown, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(viewModel.completionProgress * 100))%")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(viewModel.completedCount) of \(viewModel.totalCount) selections made")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text(viewModel.isComplete ? "All complete — ready to submit!" : "Some categories still need selection")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                Spacer()
            }
            .padding(16)
        }
    }

    private func selectionSection(title: String, selections: [(ColourCategory, SelectionChoice)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.neueHeadline)
                .foregroundStyle(AVIATheme.textPrimary)

            BentoCard(cornerRadius: 14) {
                VStack(spacing: 0) {
                    ForEach(Array(selections.enumerated()), id: \.element.0.id) { index, pair in
                        let (category, selection) = pair
                        let selectedOpt = category.options.first { $0.id == selection.optionId }
                        HStack(spacing: 14) {
                            if let imgURL = selectedOpt?.imageURL, !imgURL.isEmpty {
                                Color(.secondarySystemBackground)
                                    .frame(width: 38, height: 38)
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
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        Circle().stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                                    }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.name)
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text(selection.optionName)
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if index < selections.count - 1 {
                            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 68)
                        }
                    }
                }
            }
        }
    }

}
