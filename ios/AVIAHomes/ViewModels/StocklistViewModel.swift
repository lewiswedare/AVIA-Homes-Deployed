import SwiftUI

@Observable @MainActor
class StocklistViewModel {
    var estates: [StocklistEstateRow] = []
    var items: [StocklistItemRow] = []
    var altDesigns: [StocklistAltDesignRow] = []

    var selectedRegion: String = "Brisbane"
    var selectedSubRegion: String? = nil
    var searchText: String = ""
    var statusFilter: String? = nil
    var isLoading = false
    var isSaving = false
    var errorMessage: String?
    var successMessage: String?

    static let regions = ["Brisbane", "Gold Coast", "Sunshine Coast", "Toowoomba"]
    static let brisbaneSubRegions = ["North Brisbane", "West Brisbane", "South Brisbane"]
    static let statusOptions = ["Available", "Available (Exclusive)", "EOI", "ON HOLD", "COMING SOON", "Sold"]

    // MARK: - Derived Data

    var availableSubRegions: [String] {
        if selectedRegion == "Brisbane" {
            return Self.brisbaneSubRegions
        }
        return []
    }

    var filteredEstates: [StocklistEstateRow] {
        estates.filter { estate in
            estate.region == selectedRegion &&
            (selectedSubRegion == nil || estate.sub_region == selectedSubRegion) &&
            (searchText.isEmpty || estate.name.localizedCaseInsensitiveContains(searchText) || !filteredItems(for: estate.id).isEmpty)
        }
    }

    func filteredItems(for estateId: String) -> [StocklistItemRow] {
        var result = items.filter { $0.estate_id == estateId }

        if !searchText.isEmpty {
            result = result.filter { item in
                item.lot_number.localizedCaseInsensitiveContains(searchText) ||
                (item.design_facade ?? "").localizedCaseInsensitiveContains(searchText) ||
                (item.stage ?? "").localizedCaseInsensitiveContains(searchText) ||
                (item.specification ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }

        if let statusFilter {
            result = result.filter { $0.status == statusFilter }
        }

        return result
    }

    func altDesignsForItem(_ itemId: String) -> [StocklistAltDesignRow] {
        altDesigns.filter { $0.stocklist_item_id == itemId }
    }

    // MARK: - Data Loading

    func loadAll() async {
        isLoading = true
        async let fetchedEstates = SupabaseService.shared.fetchStocklistEstates()
        async let fetchedItems = SupabaseService.shared.fetchStocklistItems()
        let (e, i) = await (fetchedEstates, fetchedItems)
        estates = e
        items = i
        let itemIds = i.map(\.id)
        altDesigns = await SupabaseService.shared.fetchStocklistAltDesigns(itemIds: itemIds)
        isLoading = false
    }

    // MARK: - Estate CRUD

    func saveEstate(_ estate: StocklistEstateRow) async {
        isSaving = true
        errorMessage = nil
        let success = await SupabaseService.shared.upsertStocklistEstate(estate)
        if success {
            successMessage = "Estate saved"
            await loadAll()
        } else {
            errorMessage = "Failed to save estate"
        }
        isSaving = false
    }

    func deleteEstate(_ id: String) async {
        isSaving = true
        errorMessage = nil
        let success = await SupabaseService.shared.deleteStocklistEstate(id: id)
        if success {
            successMessage = "Estate deleted"
            await loadAll()
        } else {
            errorMessage = "Failed to delete estate"
        }
        isSaving = false
    }

    // MARK: - Lot CRUD

    func saveLot(_ item: StocklistItemRow) async {
        isSaving = true
        errorMessage = nil
        let success = await SupabaseService.shared.upsertStocklistItem(item)
        if success {
            successMessage = "Lot saved"
            await loadAll()
        } else {
            errorMessage = "Failed to save lot"
        }
        isSaving = false
    }

    func deleteLot(_ id: String) async {
        isSaving = true
        errorMessage = nil
        let success = await SupabaseService.shared.deleteStocklistItem(id: id)
        if success {
            successMessage = "Lot deleted"
            await loadAll()
        } else {
            errorMessage = "Failed to delete lot"
        }
        isSaving = false
    }
}
