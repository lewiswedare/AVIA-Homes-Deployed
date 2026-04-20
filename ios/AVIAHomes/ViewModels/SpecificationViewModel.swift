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
                    specTier: currentTier.rawValue,
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

    var notificationService: NotificationService?
    var adminRecipientIds: [String] = []
    var clientId: String = ""
    var clientName: String = ""
    var buildAddress: String = ""
    var isSubmittingRequests = false
    var submitMessage: String?

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
            let tier = SpecTier(rawValue: firstTier.lowercased()) ?? .messina
            suppressTierSync = true
            currentTier = tier
            suppressTierSync = false
        }

        upgradeRequests = rows.compactMap { row -> UpgradeRequest? in
            guard row.selectionType == .upgradeDraft
               || row.selectionType == .upgradeRequested
               || row.selectionType == .upgradeCosted
               || row.selectionType == .upgradeAccepted
               || row.selectionType == .upgradeDeclined
               || row.selectionType == .upgradeApproved
               || row.selectionType == .substituted else { return nil }

            let status: UpgradeStatus = {
                switch row.selectionType {
                case .upgradeDraft: return .pending
                case .upgradeRequested: return .submitted
                case .upgradeCosted: return .quoted
                case .upgradeAccepted: return .submitted
                case .upgradeDeclined: return .declined
                case .upgradeApproved: return .approved
                case .substituted: return .approved
                default:
                    switch row.status {
                    case .awaitingAdmin: return .submitted
                    case .awaitingClient: return .quoted
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
                fromTier: SpecTier(rawValue: row.specTier.lowercased()) ?? .messina,
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
        let estimatedCost = item.upgradeCost(from: currentTier, to: toTier)

        let request = UpgradeRequest(
            id: UUID().uuidString,
            itemId: item.id,
            itemName: item.name,
            categoryName: categoryName,
            fromTier: currentTier,
            toTier: toTier,
            dateRequested: .now,
            status: .pending,
            upgradeCost: estimatedCost,
            adminNotes: nil
        )
        upgradeRequests.insert(request, at: 0)

        Task { @MainActor in
            if let idx = cachedSelections.firstIndex(where: { $0.specItemId == item.id }) {
                var sel = cachedSelections[idx]
                // Add to client-side draft basket; batched submission happens
                // from ClientSpecConfirmationView's "My Upgrade Requests" card.
                sel.selectionType = .upgradeDraft
                sel.clientNotes = nil
                sel.upgradeCost = estimatedCost
                cachedSelections[idx] = sel
                _ = await SupabaseService.shared.upsertBuildSpecSelection(sel)
            } else if !buildId.isEmpty {
                let sel = BuildSpecSelection(
                    id: UUID().uuidString,
                    buildId: buildId,
                    categoryId: "",
                    specItemId: item.id,
                    specTier: currentTier.rawValue,
                    // Add to client-side draft basket (see ClientSpecConfirmationView)
                    selectionType: .upgradeDraft,
                    clientNotes: nil,
                    adminNotes: nil,
                    clientConfirmed: false,
                    adminConfirmed: false,
                    clientConfirmedAt: nil,
                    adminConfirmedAt: nil,
                    lockedForClient: false,
                    status: .draft,
                    snapshotName: item.name,
                    snapshotDescription: item.description(for: toTier),
                    snapshotImageURL: nil,
                    snapshotCategoryName: categoryName,
                    sortOrder: cachedSelections.count,
                    upgradeCost: estimatedCost,
                    upgradeCostNote: estimatedCost != nil ? "Auto-calculated from spec pricing" : nil
                )
                cachedSelections.append(sel)
                _ = await SupabaseService.shared.upsertBuildSpecSelection(sel)
            }
        }
    }

    func pendingUpgradeCount(for itemId: String) -> Bool {
        upgradeRequests.contains { $0.itemId == itemId && $0.status == .pending }
    }

    func clientAcceptUpgradeCost(requestId: String) {
        if let reqIdx = upgradeRequests.firstIndex(where: { $0.id == requestId }) {
            upgradeRequests[reqIdx].status = .submitted
        }
        guard let idx = cachedSelections.firstIndex(where: { $0.id == requestId }) else { return }
        cachedSelections[idx].selectionType = .upgradeAccepted
        cachedSelections[idx].status = .awaitingAdmin
        cachedSelections[idx].clientConfirmed = true
        cachedSelections[idx].clientConfirmedAt = .now
        cachedSelections[idx].lockedForClient = true
        let item = cachedSelections[idx]
        Task { @MainActor in
            _ = await SupabaseService.shared.upsertBuildSpecSelection(item)
        }
    }

    func clientDeclineUpgradeCost(requestId: String) {
        if let reqIdx = upgradeRequests.firstIndex(where: { $0.id == requestId }) {
            upgradeRequests[reqIdx].status = .declined
            upgradeRequests[reqIdx].upgradeCost = nil
        }
        guard let idx = cachedSelections.firstIndex(where: { $0.id == requestId }) else { return }
        cachedSelections[idx].selectionType = .upgradeDeclined
        cachedSelections[idx].status = .approved
        cachedSelections[idx].clientConfirmed = true
        cachedSelections[idx].clientConfirmedAt = .now
        cachedSelections[idx].lockedForClient = false
        cachedSelections[idx].upgradeCost = nil
        cachedSelections[idx].upgradeCostNote = nil
        let item = cachedSelections[idx]
        Task { @MainActor in
            _ = await SupabaseService.shared.upsertBuildSpecSelection(item)
        }
    }

    /// Removes a draft upgrade request (one the client has not yet submitted to admin).
    /// Reverts the underlying selection back to `.included`.
    func removeUpgradeRequest(requestId: String) {
        upgradeRequests.removeAll { $0.id == requestId }
        guard let idx = cachedSelections.firstIndex(where: { $0.id == requestId }) else { return }
        guard cachedSelections[idx].selectionType == .upgradeDraft else { return }
        cachedSelections[idx].selectionType = .included
        cachedSelections[idx].clientNotes = nil
        cachedSelections[idx].upgradeCost = nil
        cachedSelections[idx].upgradeCostNote = nil
        let item = cachedSelections[idx]
        Task { @MainActor in
            _ = await SupabaseService.shared.upsertBuildSpecSelection(item)
        }
    }

    /// Submits all draft upgrade requests to admin for review. Converts
    /// `.upgradeDraft` selections to `.upgradeRequested` and notifies admins.
    func submitAllUpgradeRequests() async {
        let drafts = cachedSelections.filter { $0.selectionType == .upgradeDraft }
        guard !drafts.isEmpty else { return }
        isSubmittingRequests = true
        defer { isSubmittingRequests = false }

        var successCount = 0
        for draft in drafts {
            guard let idx = cachedSelections.firstIndex(where: { $0.id == draft.id }) else { continue }
            cachedSelections[idx].selectionType = .upgradeRequested
            let toSave = cachedSelections[idx]
            let ok = await SupabaseService.shared.upsertBuildSpecSelection(toSave)
            if ok { successCount += 1 }
        }

        if successCount > 0, let ns = notificationService {
            let sender = clientName.isEmpty ? "Client" : clientName
            let addressPart = buildAddress.isEmpty ? "" : " for \(buildAddress)"
            let message = "\(sender) submitted \(successCount) upgrade request\(successCount == 1 ? "" : "s")\(addressPart)"
            for recipientId in adminRecipientIds {
                await ns.createNotification(
                    recipientId: recipientId,
                    senderId: clientId,
                    senderName: sender,
                    type: .buildUpdate,
                    title: "Upgrade Requests Submitted",
                    message: message,
                    referenceId: buildId,
                    referenceType: "build"
                )
            }
            submitMessage = "Submitted \(successCount) upgrade request\(successCount == 1 ? "" : "s")"
        }
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
