import SwiftUI

struct HomeDesignDirectoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var viewModel
    @State private var searchText: String = ""
    @State private var selectedBedFilter: Int? = nil
    @State private var selectedStoreyFilter: Int? = nil
    @State private var sortOption: SortOption = .nameAZ
    @State private var isCompareMode: Bool = false
    @State private var compareSelections: [HomeDesign] = []
    @State private var showComparison: Bool = false

    private let bedOptions = [3, 4]
    private let storeyOptions = [1, 2]

    private var filteredDesigns: [HomeDesign] {
        var designs = viewModel.allHomeDesigns

        if !searchText.isEmpty {
            designs = designs.filter { $0.name.localizedStandardContains(searchText) }
        }

        if let beds = selectedBedFilter {
            designs = designs.filter { $0.bedrooms == beds }
        }

        if let storeys = selectedStoreyFilter {
            designs = designs.filter { $0.storeys == storeys }
        }

        switch sortOption {
        case .nameAZ:
            designs.sort { $0.name < $1.name }
        case .nameZA:
            designs.sort { $0.name > $1.name }
        case .sizeSmall:
            designs.sort { $0.squareMeters < $1.squareMeters }
        case .sizeLarge:
            designs.sort { $0.squareMeters > $1.squareMeters }
        }

        return designs
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        headerSection
                        if isCompareMode {
                            compareHint
                        }
                        filterChips
                        designCount
                        designGrid
                    }
                    .padding(.bottom, isCompareMode ? 100 : 40)
                }

                if isCompareMode && compareSelections.count == 2 {
                    compareActionButton
                }
            }
            .background(AVIATheme.background)
            .searchable(text: $searchText, prompt: "Search designs")
            .navigationTitle("Our Designs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isCompareMode.toggle()
                            if !isCompareMode {
                                compareSelections.removeAll()
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isCompareMode ? "xmark" : "arrow.left.arrow.right")
                                .font(.system(size: 12, weight: .semibold))
                            Text(isCompareMode ? "Cancel" : "Compare")
                                .font(.neueCaptionMedium)
                        }
                        .foregroundStyle(isCompareMode ? AVIATheme.destructive : AVIATheme.timelessBrown)
                    }
                }
            }
            .navigationDestination(for: HomeDesign.self) { design in
                HomeDesignDetailView(design: design)
            }
            .sheet(isPresented: $showComparison) {
                if compareSelections.count == 2 {
                    DesignComparisonView(designA: compareSelections[0], designB: compareSelections[1])
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Find your perfect AVIA home from our complete range of thoughtfully designed residences.")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var filterChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button {
                            withAnimation(.spring(response: 0.3)) { sortOption = option }
                        } label: {
                            HStack {
                                Text(option.label)
                                if sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.neueCorp(10))
                        Text(sortOption.shortLabel)
                            .font(.neueCaptionMedium)
                    }
                    .foregroundStyle(AVIATheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AVIATheme.cardBackground)
                    .clipShape(Capsule())
                    .overlay { Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: 1) }
                }

                ForEach(bedOptions, id: \.self) { beds in
                    filterChip(
                        label: "\(beds) Bed",
                        isActive: selectedBedFilter == beds
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedBedFilter = selectedBedFilter == beds ? nil : beds
                        }
                    }
                }

                ForEach(storeyOptions, id: \.self) { storeys in
                    filterChip(
                        label: storeys == 1 ? "Single Storey" : "Double Storey",
                        isActive: selectedStoreyFilter == storeys
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedStoreyFilter = selectedStoreyFilter == storeys ? nil : storeys
                        }
                    }
                }

                if selectedBedFilter != nil || selectedStoreyFilter != nil {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedBedFilter = nil
                            selectedStoreyFilter = nil
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.neueCorp(9))
                            Text("Clear")
                                .font(.neueCaptionMedium)
                        }
                        .foregroundStyle(AVIATheme.destructive)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .contentMargins(.horizontal, 16)
        .scrollIndicators(.hidden)
    }

    private func filterChip(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.neueCaptionMedium)
                .foregroundStyle(isActive ? AVIATheme.aviaWhite : AVIATheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isActive ? AVIATheme.timelessBrown : AVIATheme.cardBackground)
                .clipShape(Capsule())
                .overlay {
                    if !isActive {
                        Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                    }
                }
        }
        .sensoryFeedback(.selection, trigger: isActive)
    }

    private var designCount: some View {
        HStack {
            Text("\(filteredDesigns.count) design\(filteredDesigns.count == 1 ? "" : "s")")
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private var designGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
            ForEach(filteredDesigns) { design in
                if isCompareMode {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            toggleCompareSelection(design)
                        }
                    } label: {
                        designGridCard(design: design)
                            .overlay(alignment: .topLeading) {
                                let isSelected = compareSelections.contains(design)
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(isSelected ? AVIATheme.timelessBrown : AVIATheme.aviaWhite.opacity(0.8))
                                    .shadow(color: AVIATheme.aviaBlack.opacity(0.3), radius: 2, y: 1)
                                    .padding(8)
                            }
                            .overlay {
                                let isSelected = compareSelections.contains(design)
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(isSelected ? AVIATheme.timelessBrown : .clear, lineWidth: 2)
                            }
                    }
                    .sensoryFeedback(.selection, trigger: compareSelections.count)
                } else {
                    NavigationLink(value: design) {
                        designGridCard(design: design)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var compareHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AVIATheme.timelessBrown)
            Text(compareSelections.isEmpty ? "Select two designs to compare" : "Select \(2 - compareSelections.count) more design\(compareSelections.count == 0 ? "s" : "")")
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.textSecondary)
            Spacer()
            if !compareSelections.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        compareSelections.removeAll()
                    }
                } label: {
                    Text("Reset")
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.destructive)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AVIATheme.timelessBrown.opacity(0.06))
        .clipShape(.rect(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    private var compareActionButton: some View {
        Button {
            showComparison = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.neueSubheadlineMedium)
                Text("Compare Designs")
                    .font(.neueSubheadlineMedium)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(AVIATheme.aviaWhite)
            .background(AVIATheme.primaryGradient)
            .clipShape(.rect(cornerRadius: 14))
            .shadow(color: AVIATheme.timelessBrown.opacity(0.3), radius: 12, y: 4)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func toggleCompareSelection(_ design: HomeDesign) {
        if let index = compareSelections.firstIndex(of: design) {
            compareSelections.remove(at: index)
        } else if compareSelections.count < 2 {
            compareSelections.append(design)
        } else {
            compareSelections.removeFirst()
            compareSelections.append(design)
        }
    }

    private func designGridCard(design: HomeDesign) -> some View {
        Color(AVIATheme.surfaceElevated)
            .aspectRatio(3/4, contentMode: .fit)
            .overlay {
                AsyncImage(url: URL(string: design.imageURL)) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else if phase.error != nil {
                        Image(systemName: "house.fill")
                            .font(.neueCorpMedium(28))
                            .foregroundStyle(AVIATheme.timelessBrown.opacity(0.3))
                    } else {
                        ProgressView()
                    }
                }
                .allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) {
                if design.storeys == 2 {
                    Text("2 STOREY")
                        .font(.neueCorpMedium(8))
                        .kerning(0.5)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AVIATheme.timelessBrown)
                        .clipShape(Capsule())
                        .padding(8)
                }
            }
            .overlay(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(design.name)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)

                    Text("\(design.bedrooms) Bed · \(design.bathrooms) Bath · \(design.garages) Car")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)

                    Text(String(format: "%.0fm²", design.squareMeters))
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial)
                .clipShape(.rect(cornerRadii: .init(bottomLeading: 14, bottomTrailing: 14)))
            }
            .clipShape(.rect(cornerRadius: 14))
    }
}

nonisolated enum SortOption: CaseIterable, Sendable {
    case nameAZ, nameZA, sizeSmall, sizeLarge

    var label: String {
        switch self {
        case .nameAZ: "Name (A–Z)"
        case .nameZA: "Name (Z–A)"
        case .sizeSmall: "Size (Smallest)"
        case .sizeLarge: "Size (Largest)"
        }
    }

    var shortLabel: String {
        switch self {
        case .nameAZ: "A–Z"
        case .nameZA: "Z–A"
        case .sizeSmall: "Smallest"
        case .sizeLarge: "Largest"
        }
    }
}
