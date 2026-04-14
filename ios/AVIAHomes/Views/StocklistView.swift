import SwiftUI

struct StocklistView: View {
    @State private var selectedRegionIndex = 0
    @State private var selectedSubRegionIndex = 0
    @State private var searchText = ""
    @State private var selectedStatus: String? = nil
    @State private var sortOption: SortOption = .none
    @State private var expandedLotIDs: Set<UUID> = []
    @State private var expandedEstateIDs: Set<UUID> = []
    @State private var showSortMenu = false
    @State private var showFilterMenu = false

    private let regions = StocklistData.regions

    enum SortOption: String, CaseIterable {
        case none = "Default"
        case priceLowHigh = "Price: Low → High"
        case priceHighLow = "Price: High → Low"
        case landSizeSmallLarge = "Land: Small → Large"
        case landSizeLargeSmall = "Land: Large → Small"
    }

    private let statusOptions = ["Available", "Available (Exclusive)", "EOI", "ON HOLD", "COMING SOON"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                regionSelector
                if selectedRegion.name == "BRISBANE" {
                    subRegionSelector
                }
                searchAndFilterBar
                lotList
            }
            .background(AVIATheme.background)
            .navigationTitle("Stocklist")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Region Selector

    private var regionSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(regions.enumerated()), id: \.element.id) { index, region in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedRegionIndex = index
                            selectedSubRegionIndex = 0
                        }
                    } label: {
                        Text(region.name)
                            .font(.neueCaptionMedium)
                            .foregroundStyle(selectedRegionIndex == index ? .white : AVIATheme.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedRegionIndex == index ? AVIATheme.teal : AVIATheme.cardBackground,
                                in: Capsule()
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Sub-Region Selector (Brisbane only)

    private var subRegionSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(selectedRegion.subRegions.enumerated()), id: \.element.id) { index, subRegion in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSubRegionIndex = index
                        }
                    } label: {
                        Text(subRegion.name)
                            .font(.neueCaption)
                            .foregroundStyle(selectedSubRegionIndex == index ? .white : AVIATheme.textTertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                selectedSubRegionIndex == index ? AVIATheme.tealLight : AVIATheme.cardBackgroundAlt,
                                in: Capsule()
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Search & Filter Bar

    private var searchAndFilterBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textTertiary)
                    TextField("Search lots, estates, designs...", text: $searchText)
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))

                Button {
                    showFilterMenu.toggle()
                } label: {
                    Image(systemName: selectedStatus != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.neueSubheadline)
                        .foregroundStyle(selectedStatus != nil ? AVIATheme.teal : AVIATheme.textSecondary)
                }

                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button {
                            sortOption = option
                        } label: {
                            HStack {
                                Text(option.rawValue)
                                if sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.neueSubheadline)
                        .foregroundStyle(sortOption != .none ? AVIATheme.teal : AVIATheme.textSecondary)
                }
            }
            .padding(.horizontal, 16)

            if showFilterMenu {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        filterChip(title: "All", isSelected: selectedStatus == nil) {
                            selectedStatus = nil
                        }
                        ForEach(statusOptions, id: \.self) { status in
                            filterChip(title: status, isSelected: selectedStatus == status) {
                                selectedStatus = (selectedStatus == status) ? nil : status
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                }
            }
        }
        .padding(.bottom, 8)
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.neueCaption2Medium)
                .foregroundStyle(isSelected ? .white : AVIATheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? statusColor(for: title == "All" ? "" : title) : AVIATheme.cardBackground, in: Capsule())
        }
    }

    // MARK: - Lot List

    private var lotList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredEstates) { estate in
                    estateSection(estate)
                }

                if filteredEstates.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundStyle(AVIATheme.textTertiary)
                        Text("No lots found")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textSecondary)
                        Text("Try adjusting your search or filters")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Estate Section

    private func estateSection(_ estate: StocklistEstate) -> some View {
        VStack(spacing: 0) {
            // Estate header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedEstateIDs.contains(estate.id) {
                        expandedEstateIDs.remove(estate.id)
                    } else {
                        expandedEstateIDs.insert(estate.id)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(estate.name)
                            .font(.neueCaptionMedium)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    let lotCount = filteredLots(for: estate).count
                    Text("\(lotCount) lot\(lotCount == 1 ? "" : "s")")
                        .font(.neueCaption2)
                        .foregroundStyle(.white.opacity(0.7))
                    Image(systemName: expandedEstateIDs.contains(estate.id) ? "chevron.up" : "chevron.down")
                        .font(.neueCaption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AVIATheme.tealGradient)
                .clipShape(.rect(topLeadingRadius: 16, topTrailingRadius: 16, bottomLeadingRadius: expandedEstateIDs.contains(estate.id) ? 0 : 16, bottomTrailingRadius: expandedEstateIDs.contains(estate.id) ? 0 : 16))
            }

            if expandedEstateIDs.contains(estate.id) {
                VStack(spacing: 0) {
                    // Deposit terms
                    if !estate.depositTerms.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.teal)
                            Text(estate.depositTerms)
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AVIATheme.teal.opacity(0.06))
                    }

                    // Lot cards
                    let lots = filteredLots(for: estate)
                    ForEach(Array(lots.enumerated()), id: \.element.id) { index, lot in
                        if index > 0 || !estate.depositTerms.isEmpty {
                            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                        }
                        lotCard(lot)
                    }

                    if lots.isEmpty {
                        Text("No lots currently listed")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textTertiary)
                            .padding(16)
                    }
                }
                .background(AVIATheme.cardBackground)
                .clipShape(.rect(bottomLeadingRadius: 16, bottomTrailingRadius: 16))
            }
        }
    }

    // MARK: - Lot Card

    private func lotCard(_ lot: StocklistLot) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedLotIDs.contains(lot.id) {
                        expandedLotIDs.remove(lot.id)
                    } else {
                        expandedLotIDs.insert(lot.id)
                    }
                }
            } label: {
                VStack(spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        // Lot number & stage
                        VStack(spacing: 2) {
                            Text("Lot")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                            Text(lot.lotNumber)
                                .font(.neueCorpMedium(22))
                                .foregroundStyle(AVIATheme.textPrimary)
                            if !lot.stage.isEmpty {
                                Text(lot.stage)
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                            }
                        }
                        .frame(width: 60)

                        // Middle: design & specs
                        VStack(alignment: .leading, spacing: 4) {
                            if !lot.designFacade.isEmpty && lot.designFacade != "COMING SOON" {
                                Text(lot.designFacade)
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                            }
                            if !lot.buildSize.isEmpty {
                                HStack(spacing: 10) {
                                    specLabel(icon: "ruler", text: lot.buildSize)
                                    if !lot.bedrooms.isEmpty {
                                        specLabel(icon: "bed.double.fill", text: lot.bedrooms)
                                    }
                                    if !lot.bathrooms.isEmpty {
                                        specLabel(icon: "shower.fill", text: lot.bathrooms)
                                    }
                                    if !lot.garages.isEmpty {
                                        specLabel(icon: "car.fill", text: lot.garages)
                                    }
                                    if !lot.theatre.isEmpty && lot.theatre != "0" {
                                        specLabel(icon: "tv.fill", text: lot.theatre)
                                    }
                                }
                            }
                            HStack(spacing: 6) {
                                Text(lot.landSize)
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textSecondary)
                                if !lot.landPrice.isEmpty {
                                    Text("·")
                                        .foregroundStyle(AVIATheme.textTertiary)
                                    Text("Land \(lot.landPrice)")
                                        .font(.neueCaption2)
                                        .foregroundStyle(AVIATheme.textSecondary)
                                }
                            }
                        }

                        Spacer()

                        // Right: price & status
                        VStack(alignment: .trailing, spacing: 4) {
                            if !lot.packagePrice.isEmpty {
                                Text(lot.packagePrice)
                                    .font(.neueCorpMedium(16))
                                    .foregroundStyle(AVIATheme.textPrimary)
                            }
                            stocklistStatusBadge(lot.status)
                        }
                    }
                }
                .padding(14)
            }

            // Expanded detail
            if expandedLotIDs.contains(lot.id) {
                lotDetailView(lot)
            }
        }
    }

    private func specLabel(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(AVIATheme.textTertiary)
            Text(text)
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textSecondary)
        }
    }

    // MARK: - Lot Detail (Expanded)

    private func lotDetailView(_ lot: StocklistLot) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

            VStack(alignment: .leading, spacing: 12) {
                // Price breakdown
                if !lot.landPrice.isEmpty || !lot.buildPrice.isEmpty {
                    VStack(spacing: 6) {
                        detailRow(label: "Land Price", value: lot.landPrice)
                        detailRow(label: "Build Price", value: lot.buildPrice)
                        if !lot.packagePrice.isEmpty {
                            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                            detailRow(label: "Package Price", value: lot.packagePrice, bold: true)
                        }
                    }
                }

                // Specs grid
                VStack(spacing: 6) {
                    detailRow(label: "Land Size", value: lot.landSize)
                    detailRow(label: "Build Size", value: lot.buildSize)
                    detailRow(label: "Design/Facade", value: lot.designFacade)
                    detailRow(label: "Specification", value: lot.specification)
                    detailRow(label: "Registration", value: lot.registered)
                    detailRow(label: "Availability", value: lot.availability)
                }

                // Owner occ badge
                if !lot.ownerOccInvestor.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AVIATheme.teal)
                        Text(lot.ownerOccInvestor)
                            .font(.neueCaption2Medium)
                            .foregroundStyle(AVIATheme.teal)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AVIATheme.teal.opacity(0.08), in: Capsule())
                }

                // Alternative designs
                if !lot.alternativeDesigns.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ALTERNATIVE DESIGNS")
                            .font(.neueCaption2Medium)
                            .foregroundStyle(AVIATheme.textTertiary)
                            .kerning(0.5)

                        ForEach(lot.alternativeDesigns) { alt in
                            VStack(spacing: 6) {
                                HStack {
                                    Text(alt.designFacade)
                                        .font(.neueCaptionMedium)
                                        .foregroundStyle(AVIATheme.textPrimary)
                                    Spacer()
                                    if !alt.packagePrice.isEmpty {
                                        Text(alt.packagePrice)
                                            .font(.neueCaptionMedium)
                                            .foregroundStyle(AVIATheme.textPrimary)
                                    }
                                }
                                HStack(spacing: 10) {
                                    specLabel(icon: "ruler", text: alt.buildSize)
                                    specLabel(icon: "bed.double.fill", text: alt.bedrooms)
                                    specLabel(icon: "shower.fill", text: alt.bathrooms)
                                    specLabel(icon: "car.fill", text: alt.garages)
                                    if !alt.theatre.isEmpty && alt.theatre != "0" {
                                        specLabel(icon: "tv.fill", text: alt.theatre)
                                    }
                                }
                                if !alt.buildPrice.isEmpty {
                                    detailRow(label: "Build Price", value: alt.buildPrice)
                                }
                            }
                            .padding(10)
                            .background(AVIATheme.cardBackgroundAlt, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }

                // Sales package link
                if let linkString = lot.salesPackageLink, let url = URL(string: linkString) {
                    Link(destination: url) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.fill")
                                .font(.neueCaptionMedium)
                            Text("View Sales Package")
                                .font(.neueCaptionMedium)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.neueCaption2)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AVIATheme.tealGradient, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(14)
            .background(AVIATheme.cardBackgroundAlt)
        }
    }

    private func detailRow(label: String, value: String, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textTertiary)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .font(bold ? .neueCaptionMedium : .neueCaption)
                .foregroundStyle(bold ? AVIATheme.textPrimary : AVIATheme.textSecondary)
        }
    }

    // MARK: - Status Badge

    private func stocklistStatusBadge(_ status: String) -> some View {
        Text(status.isEmpty ? "—" : status)
            .font(.neueCaption2Medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor(for: status), in: Capsule())
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case "Available":
            return AVIATheme.success
        case "Available (Exclusive)":
            return Color(hex: "7B4BBE")
        case "EOI":
            return AVIATheme.warning
        case "ON HOLD":
            return AVIATheme.textTertiary
        case "COMING SOON":
            return Color(hex: "3B82C9")
        default:
            return AVIATheme.textTertiary
        }
    }

    // MARK: - Computed Properties

    private var selectedRegion: StocklistRegion {
        regions[min(selectedRegionIndex, regions.count - 1)]
    }

    private var selectedSubRegion: StocklistSubRegion {
        let subRegions = selectedRegion.subRegions
        guard !subRegions.isEmpty else {
            return StocklistSubRegion(name: "", estates: [])
        }
        return subRegions[min(selectedSubRegionIndex, subRegions.count - 1)]
    }

    private var filteredEstates: [StocklistEstate] {
        let estates = selectedSubRegion.estates
        return estates.filter { estate in
            let lots = filteredLots(for: estate)
            let matchesSearch = searchText.isEmpty || estate.name.localizedCaseInsensitiveContains(searchText) || !lots.isEmpty
            return matchesSearch && (!lots.isEmpty || estate.lots.isEmpty)
        }
    }

    private func filteredLots(for estate: StocklistEstate) -> [StocklistLot] {
        var lots = estate.lots

        // Search filter
        if !searchText.isEmpty {
            lots = lots.filter { lot in
                lot.lotNumber.localizedCaseInsensitiveContains(searchText) ||
                lot.designFacade.localizedCaseInsensitiveContains(searchText) ||
                estate.name.localizedCaseInsensitiveContains(searchText) ||
                lot.stage.localizedCaseInsensitiveContains(searchText) ||
                lot.specification.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Status filter
        if let selectedStatus {
            lots = lots.filter { $0.status == selectedStatus }
        }

        // Sort
        switch sortOption {
        case .none:
            break
        case .priceLowHigh:
            lots.sort { parsePrice($0.packagePrice) < parsePrice($1.packagePrice) }
        case .priceHighLow:
            lots.sort { parsePrice($0.packagePrice) > parsePrice($1.packagePrice) }
        case .landSizeSmallLarge:
            lots.sort { parseLandSize($0.landSize) < parseLandSize($1.landSize) }
        case .landSizeLargeSmall:
            lots.sort { parseLandSize($0.landSize) > parseLandSize($1.landSize) }
        }

        return lots
    }

    private func parsePrice(_ price: String) -> Int {
        let cleaned = price.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return Int(cleaned) ?? 0
    }

    private func parseLandSize(_ size: String) -> Int {
        let cleaned = size.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return Int(cleaned) ?? 0
    }
}
