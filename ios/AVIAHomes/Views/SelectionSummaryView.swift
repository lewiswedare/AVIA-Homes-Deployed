import SwiftUI

struct SelectionSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ColourSelectionViewModel.self) private var viewModel
    @Environment(CustomerJourneyViewModel.self) private var journeyVM
    @State private var isSubmitting = false
    @State private var showSubmitConfirmation = false

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
                if viewModel.isSubmitted {
                    submittedState
                } else if viewModel.completedCount == 0 {
                    ContentUnavailableView(
                        "No Selections Yet",
                        systemImage: "paintpalette",
                        description: Text("Start choosing colours and finishes for your new home.")
                    )
                    .foregroundStyle(AVIATheme.textSecondary)
                } else {
                    selectionsList
                }
            }
            .background(AVIATheme.background)
            .navigationTitle("Selection Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.neueSubheadlineMedium)
                        .tint(AVIATheme.teal)
                }
            }
            .alert("Submit Selections?", isPresented: $showSubmitConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Submit") {
                    isSubmitting = true
                    Task {
                        await viewModel.submitSelections()
                        journeyVM.markColoursComplete()
                        isSubmitting = false
                    }
                }
            } message: {
                Text("Your colour selections will be sent to the AVIA design team for review.")
            }
        }
        .presentationBackground(AVIATheme.background)
    }

    private var selectionsList: some View {
        ScrollView {
            VStack(spacing: 20) {
                statusBanner

                if !exteriorSelections.isEmpty {
                    selectionSection(title: "Exterior", selections: exteriorSelections)
                }
                if !interiorSelections.isEmpty {
                    selectionSection(title: "Interior", selections: interiorSelections)
                }

                if viewModel.completedCount < viewModel.totalCount {
                    incompleteWarning
                }

                submitButton
            }
            .padding(20)
        }
    }

    private var statusBanner: some View {
        BentoCard(cornerRadius: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(AVIATheme.teal.opacity(0.12), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: viewModel.completionProgress)
                        .stroke(AVIATheme.teal, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(viewModel.completionProgress * 100))%")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.teal)
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

    private var incompleteWarning: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AVIATheme.warning)
            Text("\(viewModel.totalCount - viewModel.completedCount) categories still need selection. You can submit partial selections and update later.")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
        }
        .padding(14)
        .background(AVIATheme.warning.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var submitButton: some View {
        Button {
            showSubmitConfirmation = true
        } label: {
            Group {
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Label("Submit Selections", systemImage: "paperplane.fill")
                }
            }
            .font(.neueSubheadlineMedium)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(.white)
            .background(AVIATheme.tealGradient)
            .clipShape(.rect(cornerRadius: 14))
        }
        .disabled(viewModel.completedCount == 0 || isSubmitting)
    }

    private var submittedState: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.neueCorp(72))
                .foregroundStyle(AVIATheme.success)
                .symbolEffect(.bounce, value: viewModel.isSubmitted)

            Text("Selections Submitted!")
                .font(.neueCorpMedium(22))
                .foregroundStyle(AVIATheme.textPrimary)

            Text("Your colour selections have been sent to the AVIA design team. They'll review and confirm your choices within 2 business days.")
                .font(.neueSubheadline)
                .foregroundStyle(AVIATheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Close") { dismiss() }
                .font(.neueSubheadlineMedium)
                .frame(width: 200, height: 50)
                .foregroundStyle(.white)
                .background(AVIATheme.tealGradient)
                .clipShape(.rect(cornerRadius: 14))

            Spacer()
        }
    }
}
