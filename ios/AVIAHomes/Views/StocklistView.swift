import SwiftUI

struct StocklistView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var stocklistVM = StocklistViewModel()
    @State private var expandedEstateIDs: Set<String> = []
    @State private var selectedLot: StocklistItemRow?
    @State private var selectedLotEstate: StocklistEstateRow?
    @State private var showSortMenu = false
    @State private var showFilterMenu = false
    @State private var sortOption: SortOption = .none
    @State private var isEditMode = false
    @State private var estateToEdit: StocklistEstateRow?
    @State private var showEstateEditor = false
    @State private var lotToEdit: StocklistItemRow?
    @State private var lotEditEstateId: String?
    @State private var showLotEditor = false
    @State private var showDeleteEstateConfirm = false
    @State private var estateToDelete: StocklistEstateRow?
    @State private var showDeleteLotConfirm = false
    @State private var lotToDelete: StocklistItemRow?

    enum SortOption: String, CaseIterable {
        case none = "Default"
        case priceLowHigh = "Price: Low → High"
        case priceHighLow = "Price: High → Low"
        case landSizeSmallLarge = "Land: Small → Large"
        case landSizeLargeSmall = "Land: Large → Small"
    }

    private var canEdit: Bool {
        let role = appViewModel.currentRole
        return role == .admin || role == .superAdmin || role == .salesAdmin
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                regionSelector
                if stocklistVM.selectedRegion == "Brisbane" {
                    subRegionSelector
                }
                searchAndFilterBar
                lotList
            }
            .background(AVIATheme.background)
            .navigationTitle("Stocklist")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if canEdit {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isEditMode.toggle()
                            }
                        } label: {
                            Text(isEditMode ? "Done" : "Edit")
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.teal)
                        }
                    }
                }
            }
            .task {
                await stocklistVM.loadAll()
            }
            .refreshable {
                await stocklistVM.loadAll()
            }
            .sheet(isPresented: $showEstateEditor) {
                AdminStocklistEstateEditorSheet(
                    estate: estateToEdit,
                    viewModel: stocklistVM
                )
            }
            .sheet(isPresented: $showLotEditor) {
                AdminStocklistItemEditorSheet(
                    item: lotToEdit,
                    estateId: lotEditEstateId ?? "",
                    viewModel: stocklistVM
                )
            }
            .alert("Delete Estate", isPresented: $showDeleteEstateConfirm) {
                Button("Delete", role: .destructive) {
                    if let estate = estateToDelete {
                        Task { await stocklistVM.deleteEstate(estate.id) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \"\(estateToDelete?.name ?? "")\"? This cannot be undone.")
            }
            .alert("Delete Lot", isPresented: $showDeleteLotConfirm) {
                Button("Delete", role: .destructive) {
                    if let lot = lotToDelete {
                        Task { await stocklistVM.deleteLot(lot.id) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete Lot \(lotToDelete?.lot_number ?? "")? This cannot be undone.")
            }
            .sheet(item: $selectedLot) { lot in
                if let estate = selectedLotEstate {
                    let alts = stocklistVM.altDesigns(for: lot.id)
                    StocklistLotDetailSheet(lot: lot, estate: estate, altDesigns: alts)
                }
            }
        }
    }

    // MARK: - Region Selector

    private var regionSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StocklistViewModel.regions, id: \.self) { region in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            stocklistVM.selectedRegion = region
                            stocklistVM.selectedSubRegion = nil
                        }
                    } label: {
                        Text(region.uppercased())
                            .font(.neueCaptionMedium)
                            .foregroundStyle(stocklistVM.selectedRegion == region ? .white : AVIATheme.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                stocklistVM.selectedRegion == region ? AVIATheme.teal : AVIATheme.cardBackground,
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
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        stocklistVM.selectedSubRegion = nil
                    }
                } label: {
                    Text("All")
                        .font(.neueCaption)
                        .foregroundStyle(stocklistVM.selectedSubRegion == nil ? .white : AVIATheme.textTertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            stocklistVM.selectedSubRegion == nil ? AVIATheme.tealLight : AVIATheme.cardBackgroundAlt,
                            in: Capsule()
                        )
                }

                ForEach(stocklistVM.availableSubRegions, id: \.self) { subRegion in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            stocklistVM.selectedSubRegion = subRegion
                        }
                    } label: {
                        Text(subRegion)
                            .font(.neueCaption)
                            .foregroundStyle(stocklistVM.selectedSubRegion == subRegion ? .white : AVIATheme.textTertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                stocklistVM.selectedSubRegion == subRegion ? AVIATheme.tealLight : AVIATheme.cardBackgroundAlt,
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
                    TextField("Search lots, estates, designs...", text: $stocklistVM.searchText)
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AVIATheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))

                Button {
                    showFilterMenu.toggle()
                } label: {
                    Image(systemName: stocklistVM.statusFilter != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.neueSubheadline)
                        .foregroundStyle(stocklistVM.statusFilter != nil ? AVIATheme.teal : AVIATheme.textSecondary)
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
                        filterChip(title: "All", isSelected: stocklistVM.statusFilter == nil) {
                            stocklistVM.statusFilter = nil
                        }
                        ForEach(StocklistViewModel.statusOptions, id: \.self) { status in
                            filterChip(title: status, isSelected: stocklistVM.statusFilter == status) {
                                stocklistVM.statusFilter = (stocklistVM.statusFilter == status) ? nil : status
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
                if isEditMode && canEdit {
                    Button {
                        estateToEdit = nil
                        showEstateEditor = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.neueCaptionMedium)
                            Text("Add Estate")
                                .font(.neueCaptionMedium)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AVIATheme.tealGradient, in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                if stocklistVM.isLoading && stocklistVM.estates.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(AVIATheme.teal)
                        Text("Loading stocklist...")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    let estates = stocklistVM.filteredEstates
                    ForEach(estates) { estate in
                        estateSection(estate)
                    }

                    if estates.isEmpty {
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
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Estate Section

    private func estateSection(_ estate: StocklistEstateRow) -> some View {
        VStack(spacing: 0) {
            // Estate header
            Button {
                if isEditMode && canEdit {
                    estateToEdit = estate
                    showEstateEditor = true
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if expandedEstateIDs.contains(estate.id) {
                            expandedEstateIDs.remove(estate.id)
                        } else {
                            expandedEstateIDs.insert(estate.id)
                        }
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
                    if isEditMode && canEdit {
                        Image(systemName: "pencil.circle.fill")
                            .font(.neueSubheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    let lotCount = sortedLots(stocklistVM.filteredItems(for: estate.id)).count
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
            .contextMenu {
                if isEditMode && canEdit {
                    Button {
                        estateToEdit = estate
                        showEstateEditor = true
                    } label: {
                        Label("Edit Estate", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        estateToDelete = estate
                        showDeleteEstateConfirm = true
                    } label: {
                        Label("Delete Estate", systemImage: "trash")
                    }
                }
            }

            if expandedEstateIDs.contains(estate.id) {
                VStack(spacing: 0) {
                    // Deposit terms
                    if let terms = estate.deposit_terms, !terms.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.teal)
                            Text(terms)
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AVIATheme.teal.opacity(0.06))
                    }

                    if isEditMode && canEdit {
                        Button {
                            lotToEdit = nil
                            lotEditEstateId = estate.id
                            showLotEditor = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.neueCaption)
                                Text("Add Lot")
                                    .font(.neueCaptionMedium)
                            }
                            .foregroundStyle(AVIATheme.teal)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                    }

                    // Lot cards grid
                    let lots = sortedLots(stocklistVM.filteredItems(for: estate.id))
                    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(lots) { lot in
                            Button {
                                if isEditMode && canEdit {
                                    lotToEdit = lot
                                    lotEditEstateId = lot.estate_id
                                    showLotEditor = true
                                } else {
                                    selectedLot = lot
                                    selectedLotEstate = estate
                                }
                            } label: {
                                lotCard(lot: lot, estate: estate)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if isEditMode && canEdit {
                                    Button {
                                        lotToEdit = lot
                                        lotEditEstateId = lot.estate_id
                                        showLotEditor = true
                                    } label: {
                                        Label("Edit Lot", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        lotToDelete = lot
                                        showDeleteLotConfirm = true
                                    } label: {
                                        Label("Delete Lot", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)

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

    // MARK: - Lot Card (BentoCard style)

    private func lotCard(lot: StocklistItemRow, estate: StocklistEstateRow) -> some View {
        BentoCard(cornerRadius: 16) {
            VStack(spacing: 0) {
                // Top section: status badge + lot number
                Color(AVIATheme.surfaceElevated)
                    .frame(height: 80)
                    .overlay {
                        VStack(spacing: 4) {
                            Text("Lot \(lot.lot_number)")
                                .font(.neueCorpMedium(24))
                                .foregroundStyle(AVIATheme.textPrimary)
                            if let stage = lot.stage, !stage.isEmpty {
                                Text(stage)
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 6) {
                            stocklistStatusBadge(lot.status)
                            if lot.is_coming_soon {
                                Text("COMING SOON")
                                    .font(.neueCorpMedium(8))
                                    .kerning(0.5)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(10)
                    }
                    .overlay(alignment: .topTrailing) {
                        if let spec = lot.specification, !spec.isEmpty {
                            Text(spec.uppercased())
                                .font(.neueCorpMedium(8))
                                .kerning(0.5)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AVIATheme.textSecondary)
                                .clipShape(Capsule())
                                .padding(10)
                        }
                    }
                    .clipShape(.rect(cornerRadii: .init(topLeading: 16, topTrailing: 16)))

                VStack(alignment: .leading, spacing: 8) {
                    // Design & facade name
                    if let design = lot.design_facade, !design.isEmpty, design != "COMING SOON" {
                        Text(design)
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                            .lineLimit(1)
                    }

                    // Location (estate name)
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.neueCorp(10))
                            .foregroundStyle(AVIATheme.teal)
                        Text(estate.name)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .lineLimit(1)
                    }

                    // Bed/bath/garage/theatre + land size row
                    HStack(spacing: 14) {
                        if let bed = lot.bedrooms, !bed.isEmpty {
                            Label(bed, systemImage: "bed.double.fill")
                        }
                        if let bath = lot.bathrooms, !bath.isEmpty {
                            Label(bath, systemImage: "shower.fill")
                        }
                        if let garage = lot.garages, !garage.isEmpty {
                            Label(garage, systemImage: "car.fill")
                        }
                        if let theatre = lot.theatre, theatre == "1" {
                            Label("1", systemImage: "tv.fill")
                        }
                        if let landSize = lot.land_size, !landSize.isEmpty {
                            Label(landSize, systemImage: "ruler")
                        }
                    }
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)

                    // Price row
                    HStack {
                        if let pkgPrice = lot.package_price, !pkgPrice.isEmpty {
                            Text(pkgPrice)
                                .font(.neueCorpMedium(18))
                                .foregroundStyle(AVIATheme.teal)
                        } else if let landPrice = lot.land_price, !landPrice.isEmpty {
                            Text(landPrice)
                                .font(.neueCorpMedium(18))
                                .foregroundStyle(AVIATheme.teal)
                            Text("land only")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                        Spacer()
                        if let buildSize = lot.build_size, !buildSize.isEmpty, buildSize != "COMING SOON" {
                            Text(buildSize)
                                .font(.neueCaption2Medium)
                                .foregroundStyle(AVIATheme.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(AVIATheme.surfaceElevated)
                                .clipShape(Capsule())
                        }
                    }

                    // Owner occ / investor badge
                    if let ooi = lot.owner_occ_investor, !ooi.isEmpty {
                        Text(ooi)
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                }
                .padding(14)
            }
        }
    }

    // MARK: - Status Badge

    private func stocklistStatusBadge(_ status: String) -> some View {
        Text(status.isEmpty ? "—" : status)
            .font(.neueCorpMedium(8))
            .kerning(0.5)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(stocklistStatusColor(status))
            .clipShape(Capsule())
    }

    private func stocklistStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "available": return .green
        case "available (exclusive)": return .purple
        case "eoi": return .orange
        case "on hold": return .gray
        case "coming soon": return .blue
        case "sold": return .red
        default: return AVIATheme.textSecondary
        }
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
        case "Sold":
            return AVIATheme.destructive
        default:
            return AVIATheme.textTertiary
        }
    }

    // MARK: - Sorting

    private func sortedLots(_ lots: [StocklistItemRow]) -> [StocklistItemRow] {
        switch sortOption {
        case .none:
            return lots
        case .priceLowHigh:
            return lots.sorted { parsePrice($0.package_price ?? "") < parsePrice($1.package_price ?? "") }
        case .priceHighLow:
            return lots.sorted { parsePrice($0.package_price ?? "") > parsePrice($1.package_price ?? "") }
        case .landSizeSmallLarge:
            return lots.sorted { parseLandSize($0.land_size ?? "") < parseLandSize($1.land_size ?? "") }
        case .landSizeLargeSmall:
            return lots.sorted { parseLandSize($0.land_size ?? "") > parseLandSize($1.land_size ?? "") }
        }
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
