import SwiftUI

@Observable
class SpecificationViewModel {
    private var suppressTierSync = false

    var currentTier: SpecTier = .messina {
        didSet {
            guard !suppressTierSync, !buildId.isEmpty, currentTier != oldValue else { return }
            var updated = cachedSelections
            for i in updated.indices {
                updated[i] = BuildSpecSelection(
                    id: updated[i].id,
                    buildId: updated[i].buildId,
                    categoryId: updated[i].categoryId,
                    specItemId: updated[i].specItemId,
                    specTier: currentTier.rawValue.lowercased(),
                    selectionType: updated[i].selectionType,
                    clientNotes: updated[i].clientNotes,
                    adminNotes: updated[i].adminNotes,
                    clientConfirmed: updated[i].clientConfirmed,
                    adminConfirmed: updated[i].adminConfirmed,
                    clientConfirmedAt: updated[i].clientConfirmedAt,
                    adminConfirmedAt: updated[i].adminConfirmedAt,
                    lockedForClient: updated[i].lockedForClient,
                    status: updated[i].status,
                    snapshotName: updated[i].snapshotName,
                    snapshotDescription: updated[i].snapshotDescription,
                    snapshotImageURL: updated[i].snapshotImageURL,
                    snapshotCategoryName: updated[i].snapshotCategoryName,
                    sortOrder: updated[i].sortOrder,
                    upgradeCost: updated[i].upgradeCost,
                    upgradeCostNote: updated[i].upgradeCostNote
                )
            }
            cachedSelections = updated
            Task { @MainActor in
                _ = await SupabaseService.shared.upsertBuildSpecSelections(updated)
            }
        }
    }
    var categories: [SpecCategory] { CatalogDataManager.shared.allSpecCategories }
    var upgradeRequests: [UpgradeRequest] = []
    var selectedComparisonTier: SpecTier = .portobello

    private(set) var buildId: String = ""
    private var cachedSelections: [BuildSpecSelection] = []

    var upgradeTiers: [SpecTier] {
        SpecTier.allCases.filter { $0.tierIndex > currentTier.tierIndex }
    }

    func load(buildId: String) async {
        self.buildId = buildId
        var rows = await SupabaseService.shared.fetchBuildSpecSelections(buildId: buildId)

        if rows.isEmpty {
            let _ = await SupabaseService.shared.createBuildSpecSnapshot(buildId: buildId, specTier: currentTier)
            rows = await SupabaseService.shared.fetchBuildSpecSelections(buildId: buildId)
        }

        cachedSelections = rows

        if let firstTier = rows.first?.specTier {
            let tier = SpecTier(rawValue: firstTier.capitalized) ?? .messina
            suppressTierSync = true
            currentTier = tier
            suppressTierSync = false
        }

        upgradeRequests = rows.compactMap { row -> UpgradeRequest? in
            guard row.selectionType == .upgradeRequested
               || row.selectionType == .upgradeApproved
               || row.selectionType == .substituted else { return nil }

            let status: UpgradeStatus = {
                switch row.selectionType {
                case .upgradeApproved: return .approved
                case .substituted: return .approved
                default:
                    switch row.status {
                    case .awaitingAdmin: return .pending
                    case .approved: return .approved
                    case .amendedByAdmin: return .quoted
                    default: return .pending
                    }
                }
            }()

            return UpgradeRequest(
                id: row.id,
                itemId: row.specItemId,
                itemName: row.snapshotName,
                categoryName: row.snapshotCategoryName,
                fromTier: SpecTier(rawValue: row.specTier.capitalized) ?? .messina,
                toTier: .portobello,
                dateRequested: row.clientConfirmedAt ?? .now,
                status: status,
                upgradeCost: row.upgradeCost,
                adminNotes: row.adminNotes
            )
        }
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
            status: .pending,
            upgradeCost: nil,
            adminNotes: nil
        )
        upgradeRequests.insert(request, at: 0)

        Task { @MainActor in
            if let idx = cachedSelections.firstIndex(where: { $0.specItemId == item.id }) {
                var sel = cachedSelections[idx]
                sel.selectionType = .upgradeRequested
                sel.status = .awaitingAdmin
                sel.clientNotes = nil
                cachedSelections[idx] = sel
                _ = await SupabaseService.shared.upsertBuildSpecSelection(sel)
            } else if !buildId.isEmpty {
                let sel = BuildSpecSelection(
                    id: UUID().uuidString,
                    buildId: buildId,
                    categoryId: "",
                    specItemId: item.id,
                    specTier: currentTier.rawValue.lowercased(),
                    selectionType: .upgradeRequested,
                    clientNotes: nil,
                    adminNotes: nil,
                    clientConfirmed: false,
                    adminConfirmed: false,
                    clientConfirmedAt: nil,
                    adminConfirmedAt: nil,
                    lockedForClient: false,
                    status: .awaitingAdmin,
                    snapshotName: item.name,
                    snapshotDescription: item.description(for: toTier),
                    snapshotImageURL: nil,
                    snapshotCategoryName: categoryName,
                    sortOrder: cachedSelections.count,
                    upgradeCost: nil,
                    upgradeCostNote: nil
                )
                cachedSelections.append(sel)
                _ = await SupabaseService.shared.upsertBuildSpecSelection(sel)
            }
        }
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
