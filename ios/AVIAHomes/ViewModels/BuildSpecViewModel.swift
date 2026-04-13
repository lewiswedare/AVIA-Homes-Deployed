import SwiftUI
import Supabase

@Observable
class BuildSpecViewModel {
    var selections: [BuildSpecSelection] = []
    var colourSelections: [BuildColourSelection] = []
    var documents: [BuildSpecDocument] = []
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

    func load(buildId: String) async {
        self.buildId = buildId
        isLoading = true
        async let specsTask = SupabaseService.shared.fetchBuildSpecSelections(buildId: buildId)
        async let coloursTask = SupabaseService.shared.fetchBuildColourSelections(buildId: buildId)
        async let docsTask = SupabaseService.shared.fetchBuildSpecDocuments(buildId: buildId)
        var (specs, colours, docs) = await (specsTask, coloursTask, docsTask)

        if specs.isEmpty {
            let tier = SpecTier(rawValue: specTier.lowercased()) ?? .messina
            let _ = await SupabaseService.shared.createBuildSpecSnapshot(buildId: buildId, specTier: tier)
            specs = await SupabaseService.shared.fetchBuildSpecSelections(buildId: buildId)
        }

        selections = specs
        colourSelections = colours
        documents = docs
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

    func adminApproveItem(selectionId: String) {
        guard let idx = selections.firstIndex(where: { $0.id == selectionId }) else { return }
        selections[idx].adminConfirmed = true
        selections[idx].adminConfirmedAt = .now
        if selections[idx].selectionType == .upgradeAccepted {
            selections[idx].selectionType = .upgradeApproved
        }
        selections[idx].status = .approved
        Task {
            let success = await SupabaseService.shared.upsertBuildSpecSelection(selections[idx])
            if !success { errorMessage = "Failed to approve item" }
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
                .foregroundColor: UIColor.black
            ]
            let title = "AVIA Homes — Specification Summary"
            title.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: titleAttr)
            yOffset += 35

            let tierLabel = "Spec Range: \(specTier.capitalized)"
            tierLabel.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.darkGray
            ])
            yOffset += 25

            let dateLabel = "Generated: \(Date.now.formatted(date: .long, time: .shortened))"
            dateLabel.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.gray
            ])
            yOffset += 30

            for catName in categoryOrder {
                guard let items = grouped[catName], !items.isEmpty else { continue }
                checkPage(needed: 40)

                let catAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 14),
                    .foregroundColor: UIColor.black
                ]
                catName.uppercased().draw(at: CGPoint(x: margin, y: yOffset), withAttributes: catAttr)
                yOffset += 22

                let line = UIBezierPath()
                line.move(to: CGPoint(x: margin, y: yOffset))
                line.addLine(to: CGPoint(x: margin + contentWidth, y: yOffset))
                UIColor.lightGray.setStroke()
                line.lineWidth = 0.5
                line.stroke()
                yOffset += 8

                for item in items.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                    checkPage(needed: 50)

                    let nameAttr: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: 11),
                        .foregroundColor: UIColor.black
                    ]
                    item.snapshotName.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: nameAttr)

                    if item.selectionType != .included {
                        let badge = " [\(item.selectionType.displayLabel)]"
                        badge.draw(at: CGPoint(x: margin + 200, y: yOffset), withAttributes: [
                            .font: UIFont.italicSystemFont(ofSize: 9),
                            .foregroundColor: UIColor.systemOrange
                        ])
                    }
                    yOffset += 16

                    let descRect = CGRect(x: margin + 10, y: yOffset, width: contentWidth - 10, height: 40)
                    let descAttr: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 10),
                        .foregroundColor: UIColor.darkGray
                    ]
                    let descStr = NSAttributedString(string: item.snapshotDescription, attributes: descAttr)
                    descStr.draw(with: descRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
                    yOffset += 30

                    if let notes = item.clientNotes, !notes.isEmpty {
                        let notesStr = "Client notes: \(notes)"
                        notesStr.draw(at: CGPoint(x: margin + 10, y: yOffset), withAttributes: [
                            .font: UIFont.italicSystemFont(ofSize: 9),
                            .foregroundColor: UIColor.gray
                        ])
                        yOffset += 14
                    }
                    if let notes = item.adminNotes, !notes.isEmpty {
                        let notesStr = "Admin notes: \(notes)"
                        notesStr.draw(at: CGPoint(x: margin + 10, y: yOffset), withAttributes: [
                            .font: UIFont.italicSystemFont(ofSize: 9),
                            .foregroundColor: UIColor.systemBlue
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
                .foregroundColor: UIColor.black
            ]
            "AVIA Homes — Colour Selection Summary".draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttr)
            y += 35
            "Generated: \(Date.now.formatted(date: .long, time: .shortened))".draw(at: CGPoint(x: margin, y: y), withAttributes: [
                .font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.gray
            ])
            y += 30
            for selection in colourSelections {
                if y > 720 { context.beginPage(); y = 50 }
                let line = "Category: \(selection.colourCategoryId)  |  Option: \(selection.colourOptionId)  |  Status: \(selection.selectionStatus.rawValue)"
                line.draw(at: CGPoint(x: margin, y: y), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.darkGray
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

    func saveColourSelection(buildSpecSelectionId: String, specItemId: String, colourCategoryId: String, colourOptionId: String) async {
        if let idx = colourSelections.firstIndex(where: { $0.buildSpecSelectionId == buildSpecSelectionId && $0.colourCategoryId == colourCategoryId }) {
            var updated = colourSelections[idx]
            updated = BuildColourSelection(
                id: updated.id,
                buildId: buildId,
                buildSpecSelectionId: buildSpecSelectionId,
                specItemId: specItemId,
                colourCategoryId: colourCategoryId,
                colourOptionId: colourOptionId,
                selectionStatus: .draft,
                clientNotes: nil,
                adminNotes: nil
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
                selectionStatus: .draft,
                clientNotes: nil,
                adminNotes: nil
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
