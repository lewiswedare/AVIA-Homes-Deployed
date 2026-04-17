import SwiftUI
import Supabase

@Observable
class BuildSpecViewModel {
    var selections: [BuildSpecSelection] = []
    var colourSelections: [BuildColourSelection] = []
    var documents: [BuildSpecDocument] = []
    var rangeUpgradeRequests: [BuildRangeUpgradeRequest] = []
    var isLoading = false
    var isSaving = false
    var errorMessage: String?
    var successMessage: String?

    var buildId: String = ""
    var specTier: String = "messina"

    var notificationService: NotificationService?
    var adminRecipientIds: [String] = []
    var clientId: String = ""

    var groupedSelections: [(category: String, categoryId: String, items: [BuildSpecSelection])] {
        let grouped = Dictionary(grouping: selections) { $0.snapshotCategoryName }
        let categoryOrder = [
            "Structure & Ceiling", "External Finishes", "Windows & Doors",
            "Kitchen", "Bathroom & Ensuite", "Flooring",
            "Internal Finishes", "Electrical & Lighting", "Outdoor & Landscaping"
        ]
        return categoryOrder.compactMap { catName in
            guard let items = grouped[catName], !items.isEmpty else { return nil }
            return (category: catName, categoryId: items[0].categoryId, items: items.sorted { $0.sortOrder < $1.sortOrder })
        }
    }

    var overallStatus: BuildSpecStatus {
        guard let first = selections.first else { return .draft }
        return first.status
    }

    var isLockedForClient: Bool {
        overallStatus.isLockedForClient
    }

    var isFullyApproved: Bool {
        guard !selections.isEmpty else { return false }
        return selections.allSatisfy { $0.clientConfirmed && $0.adminConfirmed && $0.status == .approved }
    }

    var clientHasConfirmed: Bool {
        guard !selections.isEmpty else { return false }
        return selections.allSatisfy { $0.clientConfirmed }
    }

    var adminHasConfirmed: Bool {
        guard !selections.isEmpty else { return false }
        return selections.allSatisfy { $0.adminConfirmed }
    }

    var upgradeRequestedItems: [BuildSpecSelection] {
        selections.filter {
            $0.selectionType == .upgradeRequested ||
            $0.selectionType == .upgradeCosted ||
            $0.selectionType == .upgradeAccepted
        }
    }

    var upgradePendingClientResponseItems: [BuildSpecSelection] {
        selections.filter { $0.selectionType == .upgradeCosted }
    }

    var approvedItems: [BuildSpecSelection] {
        selections.filter { $0.status == .approved && $0.selectionType != .removed }
    }

    var totalUpgradeCost: Double {
        let specUpgrades = selections
            .filter { $0.upgradeCost != nil && ($0.selectionType == .upgradeCosted || $0.selectionType == .upgradeAccepted || $0.selectionType == .upgradeApproved) }
            .compactMap(\.upgradeCost)
            .reduce(0, +)
        let colourUpgrades = colourSelections
            .filter { $0.isUpgrade && $0.cost != nil }
            .compactMap(\.cost)
            .reduce(0, +)
        return specUpgrades + colourUpgrades
    }

    func load(buildId: String) async {
        self.buildId = buildId
        isLoading = true
        async let specsTask = SupabaseService.shared.fetchBuildSpecSelections(buildId: buildId)
        async let coloursTask = SupabaseService.shared.fetchBuildColourSelections(buildId: buildId)
        async let docsTask = SupabaseService.shared.fetchBuildSpecDocuments(buildId: buildId)
        async let rangeTask = SupabaseService.shared.fetchBuildRangeUpgradeRequests(buildId: buildId)
        var (specs, colours, docs, ranges) = await (specsTask, coloursTask, docsTask, rangeTask)

        if specs.isEmpty {
            let tier = SpecTier(rawValue: specTier.lowercased()) ?? .messina
            let _ = await SupabaseService.shared.createBuildSpecSnapshot(buildId: buildId, specTier: tier)
            specs = await SupabaseService.shared.fetchBuildSpecSelections(buildId: buildId)
        }

        selections = specs
        colourSelections = colours
        documents = docs
        rangeUpgradeRequests = ranges
        _ = ranges
        if let first = specs.first {
            specTier = first.specTier
        }
        isLoading = false
    }

    var hasSelections: Bool { !selections.isEmpty }

    func requestUpgrade(selectionId: String, notes: String?) {
        guard let idx = selections.firstIndex(where: { $0.id == selectionId }) else { return }
        selections[idx].selectionType = .upgradeRequested
        selections[idx].clientNotes = notes
        Task {
            let success = await SupabaseService.shared.upsertBuildSpecSelection(selections[idx])
            if !success { errorMessage = "Failed to save upgrade request" }
        }
    }

    func updateClientNotes(selectionId: String, notes: String) {
        guard let idx = selections.firstIndex(where: { $0.id == selectionId }) else { return }
        selections[idx].clientNotes = notes
        Task {
            let success = await SupabaseService.shared.upsertBuildSpecSelection(selections[idx])
            if !success { errorMessage = "Failed to save notes" }
        }
    }

    func submitClientConfirmation() async {
        isSaving = true
        errorMessage = nil
        let success = await SupabaseService.shared.submitClientSpecConfirmation(buildId: buildId)
        if success {
            successMessage = "Specifications submitted for review"
            await load(buildId: buildId)
            if let ns = notificationService {
                for recipientId in adminRecipientIds {
                    await ns.createNotification(
                        recipientId: recipientId,
                        senderId: clientId,
                        senderName: "Client",
                        type: .buildUpdate,
                        title: "Spec Review Required",
                        message: "Client has submitted their spec range for review",
                        referenceId: buildId,
                        referenceType: "build"
                    )
                }
            }
        } else {
            errorMessage = "Failed to submit confirmation"
        }
        isSaving = false
    }

    func adminApproveAll() async {
        isSaving = true
        errorMessage = nil
        let success = await SupabaseService.shared.approveBuildSpecSelections(buildId: buildId)
        if success {
            successMessage = "All specifications approved"
            await load(buildId: buildId)
            if isFullyApproved {
                await generatePDF()
            }
            if let ns = notificationService, !clientId.isEmpty {
                await ns.createNotification(
                    recipientId: clientId,
                    senderId: nil,
                    senderName: "AVIA Homes",
                    type: .buildUpdate,
                    title: "Spec Range Approved",
                    message: "Your specification range has been approved by the admin",
                    referenceId: buildId,
                    referenceType: "build"
                )
                await ns.createNotification(
                    recipientId: clientId,
                    senderId: nil,
                    senderName: "AVIA Homes",
                    type: .buildUpdate,
                    title: "Spec Summary PDF Ready",
                    message: "Your approved spec range PDF has been generated",
                    referenceId: buildId,
                    referenceType: "build"
                )
            }
        } else {
            errorMessage = "Failed to approve specifications"
        }
        isSaving = false
    }

    func adminSetUpgradeCost(selectionId: String, cost: Double?, note: String?) {
        guard let idx = selections.firstIndex(where: { $0.id == selectionId }) else { return }
        selections[idx].upgradeCost = cost
        selections[idx].upgradeCostNote = note
        selections[idx].selectionType = .upgradeCosted
        selections[idx].status = .awaitingClient
        selections[idx].lockedForClient = false
        selections[idx].clientConfirmed = false
        selections[idx].clientConfirmedAt = nil
        let item = selections[idx]
        Task {
            let success = await SupabaseService.shared.upsertBuildSpecSelection(item)
            if !success {
                errorMessage = "Failed to save upgrade cost"
            } else if let ns = notificationService, !clientId.isEmpty {
                await ns.createNotification(
                    recipientId: clientId,
                    senderId: nil,
                    senderName: "AVIA Homes",
                    type: .upgradeQuoted,
                    title: "Upgrade Cost Available",
                    message: "A cost has been provided for your upgrade request for \(item.snapshotName). Please review and accept or decline.",
                    referenceId: buildId,
                    referenceType: "build"
                )
            }
        }
    }

    func clientAcceptUpgrade(selectionId: String) {
        guard let idx = selections.firstIndex(where: { $0.id == selectionId }) else { return }
        selections[idx].selectionType = .upgradeAccepted
        selections[idx].status = .awaitingAdmin
        selections[idx].clientConfirmed = true
        selections[idx].clientConfirmedAt = .now
        selections[idx].lockedForClient = true
        let item = selections[idx]
        Task {
            let success = await SupabaseService.shared.upsertBuildSpecSelection(item)
            if !success {
                errorMessage = "Failed to accept upgrade"
            } else if let ns = notificationService {
                for recipientId in adminRecipientIds {
                    await ns.createNotification(
                        recipientId: recipientId,
                        senderId: clientId,
                        senderName: "Client",
                        type: .buildUpdate,
                        title: "Upgrade Accepted",
                        message: "Client has accepted the upgrade cost for \(item.snapshotName)",
                        referenceId: buildId,
                        referenceType: "build"
                    )
                }
            }
        }
    }

    func clientDeclineUpgrade(selectionId: String) {
        guard let idx = selections.firstIndex(where: { $0.id == selectionId }) else { return }
        selections[idx].selectionType = .upgradeDeclined
        selections[idx].status = .approved
        selections[idx].clientConfirmed = true
        selections[idx].clientConfirmedAt = .now
        selections[idx].lockedForClient = false
        selections[idx].upgradeCost = nil
        selections[idx].upgradeCostNote = nil
        let item = selections[idx]
        Task {
            let success = await SupabaseService.shared.upsertBuildSpecSelection(item)
            if !success {
                errorMessage = "Failed to decline upgrade"
            } else if let ns = notificationService {
                for recipientId in adminRecipientIds {
                    await ns.createNotification(
                        recipientId: recipientId,
                        senderId: clientId,
                        senderName: "Client",
                        type: .buildUpdate,
                        title: "Upgrade Declined",
                        message: "Client has declined the upgrade cost for \(item.snapshotName)",
                        referenceId: buildId,
                        referenceType: "build"
                    )
                }
            }
        }
    }

    func adminRevertUpgrade(selectionId: String) {
        guard let idx = selections.firstIndex(where: { $0.id == selectionId }) else { return }
        selections[idx].selectionType = .included
        selections[idx].status = .approved
        selections[idx].upgradeCost = nil
        selections[idx].upgradeCostNote = nil
        selections[idx].clientConfirmed = false
        selections[idx].clientConfirmedAt = nil
        selections[idx].adminConfirmed = false
        selections[idx].adminConfirmedAt = nil
        selections[idx].lockedForClient = false
        let item = selections[idx]
        Task {
            let ok = await SupabaseService.shared.upsertBuildSpecSelection(item)
            if !ok {
                errorMessage = "Failed to remove upgrade"
                return
            }
            successMessage = "Upgrade removed"
            if let ns = notificationService, !clientId.isEmpty {
                await ns.createNotification(
                    recipientId: clientId,
                    senderId: nil,
                    senderName: "AVIA Homes",
                    type: .buildUpdate,
                    title: "Upgrade Removed",
                    message: "The upgrade for \(item.snapshotName) has been removed.",
                    referenceId: buildId,
                    referenceType: "build"
                )
            }
        }
    }

    func adminApproveItem(selectionId: String) {
        guard let idx = selections.firstIndex(where: { $0.id == selectionId }) else { return }
        selections[idx].adminConfirmed = true
        selections[idx].adminConfirmedAt = .now
        if selections[idx].selectionType == .upgradeAccepted {
            selections[idx].selectionType = .upgradeApproved
        }
        selections[idx].status = .approved
        let item = selections[idx]
        let wasUpgrade = item.selectionType == .upgradeApproved
        Task {
            let success = await SupabaseService.shared.upsertBuildSpecSelection(item)
            if !success {
                errorMessage = "Failed to approve item"
                return
            }
            if wasUpgrade {
                successMessage = "Upgrade locked in"
                if let ns = notificationService, !clientId.isEmpty {
                    await ns.createNotification(
                        recipientId: clientId,
                        senderId: nil,
                        senderName: "AVIA Homes",
                        type: .buildUpdate,
                        title: "Upgrade Confirmed",
                        message: "Your upgrade for \(item.snapshotName) has been locked in.",
                        referenceId: buildId,
                        referenceType: "build"
                    )
                }
            }
        }
    }

    func adminSubstituteItem(selectionId: String, newItemId: String, newName: String, newDescription: String, notes: String?) {
        guard let idx = selections.firstIndex(where: { $0.id == selectionId }) else { return }
        selections[idx].selectionType = .substituted
        selections[idx].adminNotes = notes
        selections[idx].status = .amendedByAdmin
        Task {
            let success = await SupabaseService.shared.upsertBuildSpecSelection(selections[idx])
            if !success { errorMessage = "Failed to substitute item" }
        }
    }

    func adminAddNotes(selectionId: String, notes: String) {
        guard let idx = selections.firstIndex(where: { $0.id == selectionId }) else { return }
        selections[idx].adminNotes = notes
        Task {
            let success = await SupabaseService.shared.upsertBuildSpecSelection(selections[idx])
            if !success { errorMessage = "Failed to save notes" }
        }
    }

    func adminReopenForClient() async {
        isSaving = true
        errorMessage = nil
        let success = await SupabaseService.shared.reopenBuildSpecSelections(buildId: buildId)
        if success {
            successMessage = "Reopened for client review"
            await load(buildId: buildId)
            if let ns = notificationService, !clientId.isEmpty {
                await ns.createNotification(
                    recipientId: clientId,
                    senderId: nil,
                    senderName: "AVIA Homes",
                    type: .buildUpdate,
                    title: "Spec Range Reopened",
                    message: "Admin has reopened your spec range for further changes",
                    referenceId: buildId,
                    referenceType: "build"
                )
            }
        } else {
            errorMessage = "Failed to reopen"
        }
        isSaving = false
    }

    // MARK: - Range Upgrade Flow

    var pendingRangeUpgrade: BuildRangeUpgradeRequest? {
        rangeUpgradeRequests.first {
            $0.status == .pendingClient || $0.status == .clientAccepted
        }
    }

    func clientRequestRangeUpgrade(toTier: String, cost: Double, notes: String?) {
        if let existing = pendingRangeUpgrade {
            Task { _ = await SupabaseService.shared.deleteBuildRangeUpgradeRequest(id: existing.id) }
            rangeUpgradeRequests.removeAll { $0.id == existing.id }
        }
        let request = BuildRangeUpgradeRequest(
            id: UUID().uuidString,
            buildId: buildId,
            fromTier: specTier,
            toTier: toTier,
            cost: cost,
            status: .pendingClient,
            clientNotes: notes,
            adminNotes: nil
        )
        rangeUpgradeRequests.append(request)
        Task {
            let ok = await SupabaseService.shared.upsertBuildRangeUpgradeRequest(request)
            if !ok {
                errorMessage = "Failed to save range upgrade request"
            }
        }
    }

    func clientAcceptRangeUpgrade(requestId: String) {
        guard let idx = rangeUpgradeRequests.firstIndex(where: { $0.id == requestId }) else { return }
        rangeUpgradeRequests[idx].status = .clientAccepted
        let req = rangeUpgradeRequests[idx]
        Task {
            let ok = await SupabaseService.shared.upsertBuildRangeUpgradeRequest(req)
            if !ok {
                errorMessage = "Failed to confirm upgrade"
                return
            }
            successMessage = "Upgrade confirmed — awaiting admin approval"
            if let ns = notificationService {
                for recipientId in adminRecipientIds {
                    await ns.createNotification(
                        recipientId: recipientId,
                        senderId: clientId,
                        senderName: "Client",
                        type: .buildUpdate,
                        title: "Range Upgrade Accepted",
                        message: "Client has accepted the \(req.toTier.capitalized) range upgrade. Please approve.",
                        referenceId: buildId,
                        referenceType: "build"
                    )
                }
            }
        }
    }

    func clientDeclineRangeUpgrade(requestId: String) {
        guard let idx = rangeUpgradeRequests.firstIndex(where: { $0.id == requestId }) else { return }
        rangeUpgradeRequests[idx].status = .clientDeclined
        let req = rangeUpgradeRequests[idx]
        Task {
            let ok = await SupabaseService.shared.upsertBuildRangeUpgradeRequest(req)
            if !ok {
                errorMessage = "Failed to decline upgrade"
                return
            }
            successMessage = "Upgrade declined"
            if let ns = notificationService {
                for recipientId in adminRecipientIds {
                    await ns.createNotification(
                        recipientId: recipientId,
                        senderId: clientId,
                        senderName: "Client",
                        type: .buildUpdate,
                        title: "Range Upgrade Declined",
                        message: "Client has declined the \(req.toTier.capitalized) range upgrade.",
                        referenceId: buildId,
                        referenceType: "build"
                    )
                }
            }
        }
    }

    func adminApproveRangeUpgrade(requestId: String) async {
        guard let idx = rangeUpgradeRequests.firstIndex(where: { $0.id == requestId }) else { return }
        isSaving = true
        rangeUpgradeRequests[idx].status = .adminApproved
        let req = rangeUpgradeRequests[idx]
        let ok = await SupabaseService.shared.upsertBuildRangeUpgradeRequest(req)
        let tierUpdated = await SupabaseService.shared.updateBuildSpecTier(buildId: buildId, newTier: req.toTier)
        if ok && tierUpdated {
            if let tier = SpecTier(rawValue: req.toTier.lowercased()) {
                _ = await SupabaseService.shared.createBuildSpecSnapshot(buildId: buildId, specTier: tier)
            }
            specTier = req.toTier
            successMessage = "Range upgrade approved"
            await load(buildId: buildId)
            if let ns = notificationService, !clientId.isEmpty {
                await ns.createNotification(
                    recipientId: clientId,
                    senderId: nil,
                    senderName: "AVIA Homes",
                    type: .buildUpdate,
                    title: "Range Upgrade Approved",
                    message: "Your upgrade to the \(req.toTier.capitalized) spec range has been approved.",
                    referenceId: buildId,
                    referenceType: "build"
                )
            }
        } else {
            errorMessage = "Failed to approve range upgrade"
        }
        isSaving = false
    }

    func adminRejectRangeUpgrade(requestId: String) async {
        guard let idx = rangeUpgradeRequests.firstIndex(where: { $0.id == requestId }) else { return }
        let req = rangeUpgradeRequests[idx]
        let ok = await SupabaseService.shared.deleteBuildRangeUpgradeRequest(id: req.id)
        if ok {
            rangeUpgradeRequests.removeAll { $0.id == req.id }
            successMessage = "Range upgrade removed"
            if let ns = notificationService, !clientId.isEmpty {
                await ns.createNotification(
                    recipientId: clientId,
                    senderId: nil,
                    senderName: "AVIA Homes",
                    type: .buildUpdate,
                    title: "Range Upgrade Removed",
                    message: "Your \(req.toTier.capitalized) range upgrade request has been removed.",
                    referenceId: buildId,
                    referenceType: "build"
                )
            }
        } else {
            errorMessage = "Failed to remove range upgrade"
        }
    }

    // MARK: - Colour Upgrade Flow

    func clientAcceptColourUpgrade(selectionId: String) {
        guard let idx = colourSelections.firstIndex(where: { $0.id == selectionId }) else { return }
        colourSelections[idx].selectionStatus = .upgradeAcceptedByClient
        let item = colourSelections[idx]
        Task {
            let ok = await SupabaseService.shared.upsertBuildColourSelection(item)
            if !ok {
                errorMessage = "Failed to confirm colour upgrade"
                return
            }
            successMessage = "Colour upgrade confirmed — awaiting admin approval"
            if let ns = notificationService {
                for recipientId in adminRecipientIds {
                    await ns.createNotification(
                        recipientId: recipientId,
                        senderId: clientId,
                        senderName: "Client",
                        type: .buildUpdate,
                        title: "Colour Upgrade Accepted",
                        message: "Client has accepted a colour upgrade cost. Please approve.",
                        referenceId: buildId,
                        referenceType: "build"
                    )
                }
            }
        }
    }

    func clientDeclineColourUpgrade(selectionId: String) {
        guard let idx = colourSelections.firstIndex(where: { $0.id == selectionId }) else { return }
        colourSelections[idx].selectionStatus = .upgradeDeclinedByClient
        let item = colourSelections[idx]
        Task {
            let ok = await SupabaseService.shared.upsertBuildColourSelection(item)
            if !ok {
                errorMessage = "Failed to decline colour upgrade"
                return
            }
            successMessage = "Colour upgrade declined"
            if let ns = notificationService {
                for recipientId in adminRecipientIds {
                    await ns.createNotification(
                        recipientId: recipientId,
                        senderId: clientId,
                        senderName: "Client",
                        type: .buildUpdate,
                        title: "Colour Upgrade Declined",
                        message: "Client has declined a colour upgrade cost.",
                        referenceId: buildId,
                        referenceType: "build"
                    )
                }
            }
        }
    }

    func adminApproveColourUpgrade(selectionId: String) {
        guard let idx = colourSelections.firstIndex(where: { $0.id == selectionId }) else { return }
        colourSelections[idx].selectionStatus = .approved
        let item = colourSelections[idx]
        Task {
            let ok = await SupabaseService.shared.upsertBuildColourSelection(item)
            if !ok {
                errorMessage = "Failed to approve colour upgrade"
                return
            }
            successMessage = "Colour upgrade approved"
            if let ns = notificationService, !clientId.isEmpty {
                await ns.createNotification(
                    recipientId: clientId,
                    senderId: nil,
                    senderName: "AVIA Homes",
                    type: .buildUpdate,
                    title: "Colour Upgrade Approved",
                    message: "Your colour upgrade has been approved.",
                    referenceId: buildId,
                    referenceType: "build"
                )
            }
        }
    }

    func adminRejectColourUpgrade(selectionId: String) {
        guard let idx = colourSelections.firstIndex(where: { $0.id == selectionId }) else { return }
        colourSelections[idx].selectionStatus = .draft
        colourSelections[idx].cost = nil
        colourSelections[idx].isUpgrade = false
        let item = colourSelections[idx]
        Task {
            _ = await SupabaseService.shared.upsertBuildColourSelection(item)
        }
    }

    func generatePDF() async {
        let approvedItems = selections.filter { $0.selectionType != .removed }
        guard !approvedItems.isEmpty else { return }

        let grouped = Dictionary(grouping: approvedItems) { $0.snapshotCategoryName }
        let categoryOrder = [
            "Structure & Ceiling", "External Finishes", "Windows & Doors",
            "Kitchen", "Bathroom & Ensuite", "Flooring",
            "Internal Finishes", "Electrical & Lighting", "Outdoor & Landscaping"
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let data = renderer.pdfData { context in
            var yOffset: CGFloat = 50
            let pageWidth: CGFloat = 612
            let margin: CGFloat = 50
            let contentWidth = pageWidth - margin * 2

            func startNewPage() {
                context.beginPage()
                yOffset = 50
            }

            func checkPage(needed: CGFloat) {
                if yOffset + needed > 742 {
                    startNewPage()
                }
            }

            startNewPage()

            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 22),
                .foregroundColor: UIColor(red: 26/255, green: 26/255, blue: 26/255, alpha: 1)
            ]
            let title = "AVIA Homes — Specification Summary"
            title.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: titleAttr)
            yOffset += 35

            let tierLabel = "Spec Range: \(specTier.capitalized)"
            tierLabel.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor(red: 26/255, green: 26/255, blue: 26/255, alpha: 0.55)
            ])
            yOffset += 25

            let dateLabel = "Generated: \(Date.now.formatted(date: .long, time: .shortened))"
            dateLabel.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor(red: 26/255, green: 26/255, blue: 26/255, alpha: 0.35)
            ])
            yOffset += 30

            for catName in categoryOrder {
                guard let items = grouped[catName], !items.isEmpty else { continue }
                checkPage(needed: 40)

                let catAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 14),
                    .foregroundColor: UIColor(red: 26/255, green: 26/255, blue: 26/255, alpha: 1)
                ]
                catName.uppercased().draw(at: CGPoint(x: margin, y: yOffset), withAttributes: catAttr)
                yOffset += 22

                let line = UIBezierPath()
                line.move(to: CGPoint(x: margin, y: yOffset))
                line.addLine(to: CGPoint(x: margin + contentWidth, y: yOffset))
                UIColor(red: 205/255, green: 201/255, blue: 199/255, alpha: 1).setStroke()
                line.lineWidth = 0.5
                line.stroke()
                yOffset += 8

                for item in items.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                    checkPage(needed: 50)

                    let nameAttr: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: 11),
                        .foregroundColor: UIColor(red: 26/255, green: 26/255, blue: 26/255, alpha: 1)
                    ]
                    item.snapshotName.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: nameAttr)

                    if item.selectionType != .included {
                        let badge = " [\(item.selectionType.displayLabel)]"
                        badge.draw(at: CGPoint(x: margin + 200, y: yOffset), withAttributes: [
                            .font: UIFont.italicSystemFont(ofSize: 9),
                            .foregroundColor: UIColor(red: 55/255, green: 51/255, blue: 43/255, alpha: 0.8)
                        ])
                    }
                    yOffset += 16

                    let descRect = CGRect(x: margin + 10, y: yOffset, width: contentWidth - 10, height: 40)
                    let descAttr: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 10),
                        .foregroundColor: UIColor(red: 26/255, green: 26/255, blue: 26/255, alpha: 0.55)
                    ]
                    let descStr = NSAttributedString(string: item.snapshotDescription, attributes: descAttr)
                    descStr.draw(with: descRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
                    yOffset += 30

                    if let notes = item.clientNotes, !notes.isEmpty {
                        let notesStr = "Client notes: \(notes)"
                        notesStr.draw(at: CGPoint(x: margin + 10, y: yOffset), withAttributes: [
                            .font: UIFont.italicSystemFont(ofSize: 9),
                            .foregroundColor: UIColor(red: 26/255, green: 26/255, blue: 26/255, alpha: 0.35)
                        ])
                        yOffset += 14
                    }
                    if let notes = item.adminNotes, !notes.isEmpty {
                        let notesStr = "Admin notes: \(notes)"
                        notesStr.draw(at: CGPoint(x: margin + 10, y: yOffset), withAttributes: [
                            .font: UIFont.italicSystemFont(ofSize: 9),
                            .foregroundColor: UIColor(red: 142/255, green: 155/255, blue: 146/255, alpha: 1)
                        ])
                        yOffset += 14
                    }

                    yOffset += 6
                }
                yOffset += 10
            }
        }

        let existingDocs = await SupabaseService.shared.fetchBuildSpecDocuments(buildId: buildId)
        let nextVersion = (existingDocs.map(\.version).max() ?? 0) + 1
        let fileName = "spec_summary_v\(nextVersion).pdf"
        let storagePath = "builds/\(buildId)/\(fileName)"

        let doc = BuildSpecDocument(
            id: UUID().uuidString,
            buildId: buildId,
            storagePath: storagePath,
            publicURL: nil,
            version: nextVersion,
            generatedAt: .now,
            generatedBy: "system"
        )
        let success = await SupabaseService.shared.upsertBuildSpecDocument(doc)
        if success {
            documents.insert(doc, at: 0)
            successMessage = "PDF generated (v\(nextVersion))"
        }
    }

    func colourSelection(for specSelectionId: String) -> BuildColourSelection? {
        colourSelections.first { $0.buildSpecSelectionId == specSelectionId }
    }

    var colourSelectionOverallStatus: ColourSelectionStatus {
        guard !colourSelections.isEmpty else { return .draft }
        if colourSelections.allSatisfy({ $0.selectionStatus == .approved }) { return .approved }
        if colourSelections.allSatisfy({ $0.selectionStatus == .submitted || $0.selectionStatus == .approved }) { return .submitted }
        return .draft
    }

    func submitColourSelectionsForApproval() async {
        isSaving = true
        errorMessage = nil
        let success = await SupabaseService.shared.submitClientColourSelections(buildId: buildId)
        if success {
            successMessage = "Colour selections submitted for approval"
            await load(buildId: buildId)
            if let ns = notificationService {
                for recipientId in adminRecipientIds {
                    await ns.createNotification(
                        recipientId: recipientId,
                        senderId: clientId,
                        senderName: "Client",
                        type: .colourSelectionSubmitted,
                        title: "Colour Selections Submitted",
                        message: "Client has submitted their colour selections for approval",
                        referenceId: buildId,
                        referenceType: "build"
                    )
                }
            }
        } else {
            errorMessage = "Failed to submit colour selections"
        }
        isSaving = false
    }

    func adminApproveColourSelections() async {
        isSaving = true
        errorMessage = nil
        let success = await SupabaseService.shared.approveClientColourSelections(buildId: buildId)
        if success {
            successMessage = "Colour selections approved"
            await load(buildId: buildId)
            await generateColourPDF()
            if let ns = notificationService, !clientId.isEmpty {
                await ns.createNotification(
                    recipientId: clientId,
                    senderId: nil,
                    senderName: "AVIA Homes",
                    type: .buildUpdate,
                    title: "Colour Selections Approved",
                    message: "Your colour selections have been approved! Your colour summary PDF is ready.",
                    referenceId: buildId,
                    referenceType: "build"
                )
            }
        } else {
            errorMessage = "Failed to approve colour selections"
        }
        isSaving = false
    }

    func generateColourPDF() async {
        guard !colourSelections.isEmpty else { return }
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let data = renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = 50
            let margin: CGFloat = 50
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 22),
                .foregroundColor: UIColor(red: 26/255, green: 26/255, blue: 26/255, alpha: 1)
            ]
            "AVIA Homes — Colour Selection Summary".draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttr)
            y += 35
            "Generated: \(Date.now.formatted(date: .long, time: .shortened))".draw(at: CGPoint(x: margin, y: y), withAttributes: [
                .font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor(red: 26/255, green: 26/255, blue: 26/255, alpha: 0.35)
            ])
            y += 30
            for selection in colourSelections {
                if y > 720 { context.beginPage(); y = 50 }
                let line = "Category: \(selection.colourCategoryId)  |  Option: \(selection.colourOptionId)  |  Status: \(selection.selectionStatus.rawValue)"
                line.draw(at: CGPoint(x: margin, y: y), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor(red: 26/255, green: 26/255, blue: 26/255, alpha: 0.55)
                ])
                y += 18
            }
        }
        let existingDocs = await SupabaseService.shared.fetchBuildSpecDocuments(buildId: buildId)
        let nextVersion = (existingDocs.map(\.version).max() ?? 0) + 1
        let fileName = "colour_summary_v\(nextVersion).pdf"
        let storagePath = "builds/\(buildId)/\(fileName)"
        let doc = BuildSpecDocument(
            id: UUID().uuidString,
            buildId: buildId,
            storagePath: storagePath,
            publicURL: nil,
            version: nextVersion,
            generatedAt: .now,
            generatedBy: "system"
        )
        let success = await SupabaseService.shared.upsertBuildSpecDocument(doc)
        if success {
            documents.insert(doc, at: 0)
            successMessage = "Colour PDF generated (v\(nextVersion))"
        }
    }

    func saveColourSelection(buildSpecSelectionId: String, specItemId: String, colourCategoryId: String, colourOptionId: String, cost: Double? = nil, isUpgrade: Bool = false) async {
        let initialStatus: ColourSelectionStatus = (isUpgrade && (cost ?? 0) > 0) ? .upgradePendingClient : .draft
        if let idx = colourSelections.firstIndex(where: { $0.buildSpecSelectionId == buildSpecSelectionId && $0.colourCategoryId == colourCategoryId }) {
            var updated = colourSelections[idx]
            updated = BuildColourSelection(
                id: updated.id,
                buildId: buildId,
                buildSpecSelectionId: buildSpecSelectionId,
                specItemId: specItemId,
                colourCategoryId: colourCategoryId,
                colourOptionId: colourOptionId,
                selectionStatus: initialStatus,
                clientNotes: nil,
                adminNotes: nil,
                cost: cost,
                isUpgrade: isUpgrade,
                specTier: specTier
            )
            colourSelections[idx] = updated
            _ = await SupabaseService.shared.upsertBuildColourSelection(updated)
        } else {
            let new = BuildColourSelection(
                id: UUID().uuidString,
                buildId: buildId,
                buildSpecSelectionId: buildSpecSelectionId,
                specItemId: specItemId,
                colourCategoryId: colourCategoryId,
                colourOptionId: colourOptionId,
                selectionStatus: initialStatus,
                clientNotes: nil,
                adminNotes: nil,
                cost: cost,
                isUpgrade: isUpgrade,
                specTier: specTier
            )
            colourSelections.append(new)
            _ = await SupabaseService.shared.upsertBuildColourSelection(new)
        }

        if let ns = notificationService, !adminRecipientIds.isEmpty {
            for adminId in adminRecipientIds {
                await ns.createNotification(
                    recipientId: adminId,
                    senderId: clientId,
                    senderName: "Client",
                    type: .colourSelectionSubmitted,
                    title: "Colour Selection Saved",
                    message: "Client has updated a colour selection.",
                    referenceId: buildId,
                    referenceType: "build"
                )
            }
        }
    }
}
