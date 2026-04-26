import SwiftUI

struct ColourOverviewView: View {
    @Environment(ColourSelectionViewModel.self) private var viewModel
    @State private var selectedSection: SelectionSection = .exterior
    @State private var showGuidedFlow = false
    @State private var showHomeFast = false
    @State private var selectedCategory: ColourCategory?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroImage

                    VStack(spacing: 16) {
                        progressCard
                        homeFastButton
                        guidedTourButton
                        sectionPicker
                        categoryGrid
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: [.top, .horizontal])
            .background(AVIATheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Summary", systemImage: "list.clipboard") {
                        viewModel.showSummary = true
                    }
                    .tint(AVIATheme.timelessBrown)
                    .disabled(viewModel.completedCount == 0)
                }
            }
            .sheet(item: $selectedCategory) { category in
                ColourDetailView(category: category)
            }
            .sheet(isPresented: Bindable(viewModel).showSummary) {
                SelectionSummaryView()
            }
            .fullScreenCover(isPresented: $showGuidedFlow) {
                GuidedColourFlowView()
            }
            .sheet(isPresented: $showHomeFast) {
                HomeFastSchemeView()
            }
        }
    }

    private var heroImage: some View {
        Color(AVIATheme.surfaceElevated)
            .frame(height: 320)
            .overlay {
                Image("hero_colours")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0.0),
                        .init(color: AVIATheme.background.opacity(0.15), location: 0.25),
                        .init(color: AVIATheme.background.opacity(0.4), location: 0.45),
                        .init(color: AVIATheme.background.opacity(0.7), location: 0.65),
                        .init(color: AVIATheme.background.opacity(0.9), location: 0.8),
                        .init(color: AVIATheme.background, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Colour Library")
                        .font(.neueCorpMedium(28))
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Preview colours — your official build selections are made on your live build.")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .clipped()
    }

    private var progressCard: some View {
        BentoCard(cornerRadius: 18) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(AVIATheme.timelessBrown.opacity(0.12), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: viewModel.completionProgress)
                        .stroke(AVIATheme.timelessBrown, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring, value: viewModel.completionProgress)
                    VStack(spacing: 0) {
                        Text("\(viewModel.completedCount)")
                            .font(.neueCorpMedium(22))
                            .foregroundStyle(AVIATheme.timelessBrown)
                        Text("of \(viewModel.totalCount)")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                }
                .frame(width: 68, height: 68)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Previews")
                        .font(.neueHeadline)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Explore colours and finishes. These are preview-only.")
                        .font(.neueSubheadline)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                Spacer()
            }
            .padding(18)
        }
    }

    private var homeFastButton: some View {
        Button {
            showHomeFast = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.neueTitle3)
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .frame(width: 44, height: 44)
                    .background(AVIATheme.timelessBrown.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("HomeFast Schemes")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        if let scheme = viewModel.appliedScheme {
                            Text(scheme.name)
                                .font(.neueCaption2Medium)
                                .foregroundStyle(AVIATheme.success)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AVIATheme.success.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    Text("Pre-designed colour packages")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(16)
            .background(AVIATheme.cardBackground)
            .clipShape(.rect(cornerRadius: 18))
            .overlay {
                if viewModel.appliedScheme != nil {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(AVIATheme.success.opacity(0.2), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.pressable(.subtle))
    }

    private var guidedTourButton: some View {
        Button {
            showGuidedFlow = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "wand.and.stars")
                    .font(.neueTitle3)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(width: 44, height: 44)
                    .background(AVIATheme.aviaWhite.opacity(0.15))
                    .clipShape(.rect(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Start Guided Tour")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.aviaWhite)
                    Text("Step-by-step through every selection")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.aviaWhite.opacity(0.7))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.aviaWhite.opacity(0.5))
            }
            .padding(16)
            .background(AVIATheme.primaryGradient)
            .clipShape(.rect(cornerRadius: 18))
        }
    }

    private var sectionPicker: some View {
        HStack(spacing: 4) {
            ForEach(SelectionSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedSection = section
                    }
                } label: {
                    Text(section.rawValue)
                        .font(.neueSubheadlineMedium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(selectedSection == section ? AVIATheme.aviaWhite : AVIATheme.textSecondary)
                        .background {
                            if selectedSection == section {
                                Capsule().fill(AVIATheme.timelessBrown)
                            } else {
                                Capsule().fill(AVIATheme.surfaceElevated)
                            }
                        }
                }
            }
        }
        .padding(3)
        .background(AVIATheme.surfaceElevated)
        .clipShape(Capsule())
    }

    private var categoryGrid: some View {
        let categories = selectedSection == .exterior
            ? viewModel.exteriorCategories
            : viewModel.interiorCategories

        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            ForEach(categories) { category in
                CategoryCard(
                    category: category,
                    selection: viewModel.selection(for: category.id)
                ) {
                    selectedCategory = category
                }
            }
        }
        .animation(.spring(response: 0.3), value: selectedSection)
    }
}

struct CategoryCard: View {
    let category: ColourCategory
    let selection: SelectionChoice?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    if let selection {
                        Circle()
                            .fill(Color(hex: selection.hexColor))
                            .frame(width: 50, height: 50)
                            .overlay {
                                Circle()
                                    .stroke(AVIATheme.timelessBrown, lineWidth: 2.5)
                                    .frame(width: 60, height: 60)
                            }
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: "checkmark")
                                    .font(.neueCorpMedium(8))
                                    .foregroundStyle(AVIATheme.aviaWhite)
                                    .padding(5)
                                    .background(AVIATheme.timelessBrown, in: Circle())
                                    .offset(x: 6, y: -6)
                            }
                    } else {
                        Image(systemName: category.icon)
                            .font(.neueTitle3)
                            .foregroundStyle(AVIATheme.textTertiary)
                            .frame(width: 50, height: 50)
                            .background(AVIATheme.surfaceElevated)
                            .clipShape(Circle())
                    }
                }
                .frame(height: 62)

                VStack(spacing: 3) {
                    Text(category.name)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    if let selection {
                        Text(selection.optionName)
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.timelessBrown)
                            .lineLimit(1)
                    } else {
                        Text("Not selected")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(AVIATheme.cardBackground)
            .clipShape(.rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selection != nil ? AVIATheme.timelessBrown.opacity(0.2) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.pressable(.subtle))
    }
}
