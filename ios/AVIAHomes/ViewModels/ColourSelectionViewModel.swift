import SwiftUI

@Observable
class ColourSelectionViewModel {
    var selections: [String: SelectionChoice] = [:]
    var showSummary = false
    var appliedScheme: HomeFastScheme?
    var specTier: SpecTier = .messina

    private var catalog: CatalogDataManager { CatalogDataManager.shared }

    var exteriorCategories: [ColourCategory] { catalog.filteredExteriorCategories(for: specTier) }
    var interiorCategories: [ColourCategory] { catalog.filteredInteriorCategories(for: specTier) }

    var allFilteredCategories: [ColourCategory] { catalog.filteredAllCategories(for: specTier) }

    var totalCount: Int { allFilteredCategories.count }

    var completedCount: Int {
        let available = catalog.availableColourCategoryIds(for: specTier)
        return selections.keys.filter { available.contains($0) }.count
    }

    var completionProgress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var isComplete: Bool { completedCount == totalCount }

    func selection(for categoryId: String) -> SelectionChoice? {
        selections[categoryId]
    }

    func isSelected(categoryId: String, optionId: String) -> Bool {
        selections[categoryId]?.optionId == optionId
    }

    func select(option: ColourOption, for category: ColourCategory) {
        selections[category.id] = SelectionChoice(
            categoryId: category.id,
            optionId: option.id,
            optionName: option.name,
            hexColor: option.hexColor
        )
    }

    func clearSelection(for categoryId: String) {
        selections.removeValue(forKey: categoryId)
        appliedScheme = nil
    }

    func applyScheme(_ scheme: HomeFastScheme) {
        var newSelections: [String: SelectionChoice] = [:]
        for (categoryId, schemeSelection) in scheme.selections {
            newSelections[categoryId] = SelectionChoice(
                categoryId: categoryId,
                optionId: schemeSelection.optionId,
                optionName: schemeSelection.optionName,
                hexColor: schemeSelection.hexColor
            )
        }
        selections = newSelections
        appliedScheme = scheme
    }

    func clearAllSelections() {
        selections.removeAll()
        appliedScheme = nil
    }

    // This ViewModel powers the read-only Colour Library (catalog preview).
    // Build-specific colour submissions happen in BuildSpecViewModel via
    // BuildColourSelectionView — there is no submission path from the Library.
}
