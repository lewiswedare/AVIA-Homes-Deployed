import Foundation

enum ColourData {
    static let exteriorCategories: [ColourCategory] = []
    static let interiorCategories: [ColourCategory] = []

    static var allCategories: [ColourCategory] { [] }

    static let specToColourMapping: [String: [String]] = [:]

    static func availableColourCategoryIds(for tier: SpecTier) -> Set<String> {
        CatalogDataManager.shared.availableColourCategoryIds(for: tier)
    }

    static func filteredExteriorCategories(for tier: SpecTier) -> [ColourCategory] {
        CatalogDataManager.shared.filteredExteriorCategories(for: tier)
    }

    static func filteredInteriorCategories(for tier: SpecTier) -> [ColourCategory] {
        CatalogDataManager.shared.filteredInteriorCategories(for: tier)
    }

    static func filteredAllCategories(for tier: SpecTier) -> [ColourCategory] {
        CatalogDataManager.shared.filteredAllCategories(for: tier)
    }
}
