import SwiftUI

@Observable
class SpecificationViewModel {
    var currentTier: SpecTier = .messina
    var categories: [SpecCategory] { CatalogDataManager.shared.allSpecCategories }
    var upgradeRequests: [UpgradeRequest] = []
    var selectedComparisonTier: SpecTier = .portobello

    var upgradeTiers: [SpecTier] {
        SpecTier.allCases.filter { $0.tierIndex > currentTier.tierIndex }
    }

    func upgradeableItems(in category: SpecCategory) -> [SpecItem] {
        category.items.filter { $0.isUpgradeable && $0.description(for: currentTier) != $0.description(for: .portobello) }
    }

    func hasUpgrade(for item: SpecItem) -> Bool {
        item.isUpgradeable && upgradeTiers.contains { tier in
            item.description(for: tier) != item.description(for: currentTier)
        }
    }

    func requestUpgrade(item: SpecItem, categoryName: String, toTier: SpecTier) {
        let request = UpgradeRequest(
            id: UUID().uuidString,
            itemId: item.id,
            itemName: item.name,
            categoryName: categoryName,
            fromTier: currentTier,
            toTier: toTier,
            dateRequested: .now,
            status: .pending
        )
        upgradeRequests.insert(request, at: 0)
    }

    func pendingUpgradeCount(for itemId: String) -> Bool {
        upgradeRequests.contains { $0.itemId == itemId && $0.status == .pending }
    }

    func requestFullUpgrade(toTier: SpecTier) {
        for category in categories {
            for item in upgradeableItems(in: category) {
                if item.description(for: toTier) != item.description(for: currentTier) && !pendingUpgradeCount(for: item.id) {
                    requestUpgrade(item: item, categoryName: category.name, toTier: toTier)
                }
            }
        }
    }
}
