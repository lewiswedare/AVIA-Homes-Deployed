import SwiftUI

struct HomeDesignDirectoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var viewModel
    @State private var searchText: String = ""
    @State private var selectedBedFilter: Int? = nil
    @State private var selectedStoreyFilter: Int? = nil
    @State private var sortOption: SortOption = .nameAZ

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
            ScrollView {
                VStack(spacing: 16) {
                    headerSection
                    filterChips
                    designCount
                    designGrid
                }
                .padding(.bottom, 40)
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
            }
            .navigationDestination(for: HomeDesign.self) { design in
                HomeDesignDetailView(design: design)
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
                .foregroundStyle(isActive ? .white : AVIATheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isActive ? AVIATheme.teal : AVIATheme.cardBackground)
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
                NavigationLink(value: design) {
                    designGridCard(design: design)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func designGridCard(design: HomeDesign) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color(AVIATheme.surfaceElevated)
                .aspectRatio(4/3, contentMode: .fit)
                .overlay {
                    AsyncImage(url: URL(string: design.imageURL)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else if phase.error != nil {
                            Image(systemName: "house.fill")
                                .font(.neueCorpMedium(28))
                                .foregroundStyle(AVIATheme.teal.opacity(0.3))
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
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(AVIATheme.teal)
                            .clipShape(Capsule())
                            .padding(8)
                    }
                }
                .clipShape(.rect(cornerRadii: .init(topLeading: 14, topTrailing: 14)))

            VStack(alignment: .leading, spacing: 6) {
                Text(design.name)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)

                HStack(spacing: 8) {
                    Label("\(design.bedrooms)", systemImage: "bed.double.fill")
                    Label("\(design.bathrooms)", systemImage: "shower.fill")
                    Label("\(design.garages)", systemImage: "car.fill")
                }
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textSecondary)

                Text(String(format: "%.0fm²", design.squareMeters))
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.teal)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(AVIATheme.cardBackground)
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
