import Foundation

nonisolated enum BuildSpecStatus: String, Codable, Sendable, CaseIterable {
    case draft
    case clientReviewing = "client_reviewing"
    case awaitingAdmin = "awaiting_admin"
    case awaitingClient = "awaiting_client"
    case reopenedByAdmin = "reopened_by_admin"
    case approved
    case amendedByAdmin = "amended_by_admin"

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = BuildSpecStatus(rawValue: raw) ?? .draft
    }

    var displayLabel: String {
        switch self {
        case .draft: "Draft"
        case .clientReviewing: "Reviewing"
        case .awaitingAdmin: "Awaiting Admin"
        case .awaitingClient: "Awaiting Client"
        case .reopenedByAdmin: "Reopened"
        case .approved: "Approved"
        case .amendedByAdmin: "Amended"
        }
    }

    var icon: String {
        switch self {
        case .draft: "doc.text"
        case .clientReviewing: "eye"
        case .awaitingAdmin: "clock.fill"
        case .awaitingClient: "hourglass"
        case .reopenedByAdmin: "arrow.counterclockwise"
        case .approved: "checkmark.seal.fill"
        case .amendedByAdmin: "pencil.circle.fill"
        }
    }

    var isLockedForClient: Bool {
        switch self {
        case .awaitingAdmin, .awaitingClient, .approved, .amendedByAdmin: true
        default: false
        }
    }

    var isFullyApproved: Bool { self == .approved }
}

nonisolated enum SelectionType: String, Codable, Sendable {
    case included
    case upgradeRequested = "upgrade_requested"
    case upgradeCosted = "upgrade_costed"
    case upgradeAccepted = "upgrade_accepted"
    case upgradeDeclined = "upgrade_declined"
    case upgradeApproved = "upgrade_approved"
    case substituted
    case removed

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = SelectionType(rawValue: raw) ?? .included
    }

    var displayLabel: String {
        switch self {
        case .included: "Included"
        case .upgradeRequested: "Upgrade Requested"
        case .upgradeCosted: "Upgrade Costed"
        case .upgradeAccepted: "Upgrade Accepted"
        case .upgradeDeclined: "Upgrade Declined"
        case .upgradeApproved: "Upgrade Approved"
        case .substituted: "Substituted"
        case .removed: "Removed"
        }
    }
}

nonisolated enum ColourSelectionStatus: String, Codable, Sendable {
    case draft
    case submitted
    case approved
    case reopened

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = ColourSelectionStatus(rawValue: raw) ?? .draft
    }
}

nonisolated struct BuildSpecSelectionRow: Codable, Sendable, Identifiable {
    let id: String
    let build_id: String
    let category_id: String
    let spec_item_id: String
    let spec_tier: String
    let selection_type: String
    let client_notes: String?
    let admin_notes: String?
    let client_confirmed: Bool
    let admin_confirmed: Bool
    let client_confirmed_at: String?
    let admin_confirmed_at: String?
    let locked_for_client: Bool
    let status: String
    let snapshot_name: String
    let snapshot_description: String
    let snapshot_image_url: String?
    let snapshot_category_name: String
    let sort_order: Int
    let created_at: String?
    let updated_at: String?
    let upgrade_cost: Double?
    let upgrade_cost_note: String?

    enum CodingKeys: String, CodingKey {
        case id, build_id, category_id, spec_item_id, spec_tier, selection_type
        case client_notes, admin_notes, client_confirmed, admin_confirmed
        case client_confirmed_at, admin_confirmed_at, locked_for_client, status
        case snapshot_name, snapshot_description, snapshot_image_url, snapshot_category_name
        case sort_order, created_at, updated_at, upgrade_cost, upgrade_cost_note
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(build_id, forKey: .build_id)
        try container.encode(category_id, forKey: .category_id)
        try container.encode(spec_item_id, forKey: .spec_item_id)
        try container.encode(spec_tier, forKey: .spec_tier)
        try container.encode(selection_type, forKey: .selection_type)
        try container.encodeIfPresent(client_notes, forKey: .client_notes)
        try container.encodeIfPresent(admin_notes, forKey: .admin_notes)
        try container.encode(client_confirmed, forKey: .client_confirmed)
        try container.encode(admin_confirmed, forKey: .admin_confirmed)
        try container.encodeIfPresent(client_confirmed_at, forKey: .client_confirmed_at)
        try container.encodeIfPresent(admin_confirmed_at, forKey: .admin_confirmed_at)
        try container.encode(locked_for_client, forKey: .locked_for_client)
        try container.encode(status, forKey: .status)
        try container.encode(snapshot_name, forKey: .snapshot_name)
        try container.encode(snapshot_description, forKey: .snapshot_description)
        try container.encodeIfPresent(snapshot_image_url, forKey: .snapshot_image_url)
        try container.encode(snapshot_category_name, forKey: .snapshot_category_name)
        try container.encode(sort_order, forKey: .sort_order)
        try container.encodeIfPresent(updated_at, forKey: .updated_at)
        try container.encodeIfPresent(upgrade_cost, forKey: .upgrade_cost)
        try container.encodeIfPresent(upgrade_cost_note, forKey: .upgrade_cost_note)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        build_id = try container.decode(String.self, forKey: .build_id)
        category_id = try container.decode(String.self, forKey: .category_id)
        spec_item_id = try container.decode(String.self, forKey: .spec_item_id)
        spec_tier = try container.decode(String.self, forKey: .spec_tier)
        selection_type = try container.decode(String.self, forKey: .selection_type)
        client_notes = try container.decodeIfPresent(String.self, forKey: .client_notes)
        admin_notes = try container.decodeIfPresent(String.self, forKey: .admin_notes)
        client_confirmed = try container.decode(Bool.self, forKey: .client_confirmed)
        admin_confirmed = try container.decode(Bool.self, forKey: .admin_confirmed)
        client_confirmed_at = try container.decodeIfPresent(String.self, forKey: .client_confirmed_at)
        admin_confirmed_at = try container.decodeIfPresent(String.self, forKey: .admin_confirmed_at)
        locked_for_client = try container.decode(Bool.self, forKey: .locked_for_client)
        status = try container.decode(String.self, forKey: .status)
        snapshot_name = try container.decode(String.self, forKey: .snapshot_name)
        snapshot_description = try container.decode(String.self, forKey: .snapshot_description)
        snapshot_image_url = try container.decodeIfPresent(String.self, forKey: .snapshot_image_url)
        snapshot_category_name = try container.decode(String.self, forKey: .snapshot_category_name)
        sort_order = try container.decode(Int.self, forKey: .sort_order)
        created_at = try container.decodeIfPresent(String.self, forKey: .created_at)
        updated_at = try container.decodeIfPresent(String.self, forKey: .updated_at)
        upgrade_cost_note = try container.decodeIfPresent(String.self, forKey: .upgrade_cost_note)
        if let d = try? container.decodeIfPresent(Double.self, forKey: .upgrade_cost) {
            upgrade_cost = d
        } else if let s = try? container.decodeIfPresent(String.self, forKey: .upgrade_cost), let d = Double(s) {
            upgrade_cost = d
        } else {
            upgrade_cost = nil
        }
    }

    init(id: String, build_id: String, category_id: String, spec_item_id: String, spec_tier: String, selection_type: String, client_notes: String?, admin_notes: String?, client_confirmed: Bool, admin_confirmed: Bool, client_confirmed_at: String?, admin_confirmed_at: String?, locked_for_client: Bool, status: String, snapshot_name: String, snapshot_description: String, snapshot_image_url: String?, snapshot_category_name: String, sort_order: Int, created_at: String?, updated_at: String?, upgrade_cost: Double? = nil, upgrade_cost_note: String? = nil) {
        self.id = id
        self.build_id = build_id
        self.category_id = category_id
        self.spec_item_id = spec_item_id
        self.spec_tier = spec_tier
        self.selection_type = selection_type
        self.client_notes = client_notes
        self.admin_notes = admin_notes
        self.client_confirmed = client_confirmed
        self.admin_confirmed = admin_confirmed
        self.client_confirmed_at = client_confirmed_at
        self.admin_confirmed_at = admin_confirmed_at
        self.locked_for_client = locked_for_client
        self.status = status
        self.snapshot_name = snapshot_name
        self.snapshot_description = snapshot_description
        self.snapshot_image_url = snapshot_image_url
        self.snapshot_category_name = snapshot_category_name
        self.sort_order = sort_order
        self.created_at = created_at
        self.updated_at = updated_at
        self.upgrade_cost = upgrade_cost
        self.upgrade_cost_note = upgrade_cost_note
    }
}

struct BuildSpecSelection: Identifiable, Sendable {
    let id: String
    let buildId: String
    let categoryId: String
    let specItemId: String
    let specTier: String
    var selectionType: SelectionType
    var clientNotes: String?
    var adminNotes: String?
    var clientConfirmed: Bool
    var adminConfirmed: Bool
    var clientConfirmedAt: Date?
    var adminConfirmedAt: Date?
    var lockedForClient: Bool
    var status: BuildSpecStatus
    let snapshotName: String
    let snapshotDescription: String
    let snapshotImageURL: String?
    let snapshotCategoryName: String
    let sortOrder: Int
    var upgradeCost: Double?
    var upgradeCostNote: String?

    var isFullyApproved: Bool {
        clientConfirmed && adminConfirmed && status == .approved
    }
}

extension BuildSpecSelectionRow {
    func toModel() -> BuildSpecSelection {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        return BuildSpecSelection(
            id: id,
            buildId: build_id,
            categoryId: category_id,
            specItemId: spec_item_id,
            specTier: spec_tier,
            selectionType: SelectionType(rawValue: selection_type) ?? .included,
            clientNotes: client_notes,
            adminNotes: admin_notes,
            clientConfirmed: client_confirmed,
            adminConfirmed: admin_confirmed,
            clientConfirmedAt: client_confirmed_at.flatMap { fmt.date(from: $0) ?? fallback.date(from: $0) },
            adminConfirmedAt: admin_confirmed_at.flatMap { fmt.date(from: $0) ?? fallback.date(from: $0) },
            lockedForClient: locked_for_client,
            status: BuildSpecStatus(rawValue: status) ?? .draft,
            snapshotName: snapshot_name,
            snapshotDescription: snapshot_description,
            snapshotImageURL: snapshot_image_url,
            snapshotCategoryName: snapshot_category_name,
            sortOrder: sort_order,
            upgradeCost: upgrade_cost,
            upgradeCostNote: upgrade_cost_note
        )
    }
}

extension BuildSpecSelection {
    func toRow() -> BuildSpecSelectionRow {
        let iso = ISO8601DateFormatter()
        return BuildSpecSelectionRow(
            id: id,
            build_id: buildId,
            category_id: categoryId,
            spec_item_id: specItemId,
            spec_tier: specTier,
            selection_type: selectionType.rawValue,
            client_notes: clientNotes,
            admin_notes: adminNotes,
            client_confirmed: clientConfirmed,
            admin_confirmed: adminConfirmed,
            client_confirmed_at: clientConfirmedAt.map { iso.string(from: $0) },
            admin_confirmed_at: adminConfirmedAt.map { iso.string(from: $0) },
            locked_for_client: lockedForClient,
            status: status.rawValue,
            snapshot_name: snapshotName,
            snapshot_description: snapshotDescription,
            snapshot_image_url: snapshotImageURL,
            snapshot_category_name: snapshotCategoryName,
            sort_order: sortOrder,
            created_at: nil,
            updated_at: iso.string(from: .now),
            upgrade_cost: upgradeCost,
            upgrade_cost_note: upgradeCostNote
        )
    }
}

nonisolated struct BuildColourSelectionRow: Codable, Sendable, Identifiable {
    let id: String
    let build_id: String
    let build_spec_selection_id: String?
    let spec_item_id: String?
    let colour_category_id: String
    let colour_option_id: String
    let selection_status: String
    let client_notes: String?
    let admin_notes: String?
    let created_at: String?
    let updated_at: String?
    let cost: Double?
    let is_upgrade: Bool?

    nonisolated enum CodingKeys: String, CodingKey {
        case id, build_id, build_spec_selection_id, spec_item_id
        case colour_category_id, colour_option_id, selection_status
        case client_notes, admin_notes, created_at, updated_at
        case cost, is_upgrade
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(build_id, forKey: .build_id)
        try container.encodeIfPresent(build_spec_selection_id, forKey: .build_spec_selection_id)
        try container.encodeIfPresent(spec_item_id, forKey: .spec_item_id)
        try container.encode(colour_category_id, forKey: .colour_category_id)
        try container.encode(colour_option_id, forKey: .colour_option_id)
        try container.encode(selection_status, forKey: .selection_status)
        try container.encodeIfPresent(client_notes, forKey: .client_notes)
        try container.encodeIfPresent(admin_notes, forKey: .admin_notes)
        try container.encodeIfPresent(updated_at, forKey: .updated_at)
        try container.encodeIfPresent(cost, forKey: .cost)
        try container.encodeIfPresent(is_upgrade, forKey: .is_upgrade)
    }
}

struct BuildColourSelection: Identifiable, Sendable {
    let id: String
    let buildId: String
    let buildSpecSelectionId: String?
    let specItemId: String?
    let colourCategoryId: String
    let colourOptionId: String
    var selectionStatus: ColourSelectionStatus
    var clientNotes: String?
    var adminNotes: String?
    var cost: Double?
    var isUpgrade: Bool
}

extension BuildColourSelectionRow {
    func toModel() -> BuildColourSelection {
        BuildColourSelection(
            id: id,
            buildId: build_id,
            buildSpecSelectionId: build_spec_selection_id,
            specItemId: spec_item_id,
            colourCategoryId: colour_category_id,
            colourOptionId: colour_option_id,
            selectionStatus: ColourSelectionStatus(rawValue: selection_status) ?? .draft,
            clientNotes: client_notes,
            adminNotes: admin_notes,
            cost: cost,
            isUpgrade: is_upgrade ?? false
        )
    }
}

extension BuildColourSelection {
    func toRow() -> BuildColourSelectionRow {
        let iso = ISO8601DateFormatter()
        return BuildColourSelectionRow(
            id: id,
            build_id: buildId,
            build_spec_selection_id: buildSpecSelectionId,
            spec_item_id: specItemId,
            colour_category_id: colourCategoryId,
            colour_option_id: colourOptionId,
            selection_status: selectionStatus.rawValue,
            client_notes: clientNotes,
            admin_notes: adminNotes,
            created_at: nil,
            updated_at: iso.string(from: .now),
            cost: cost,
            is_upgrade: isUpgrade
        )
    }
}

nonisolated struct BuildSpecDocumentRow: Codable, Sendable, Identifiable {
    let id: String
    let build_id: String
    let storage_path: String
    let public_url: String?
    let version: Int
    let generated_at: String?
    let generated_by: String?
}

struct BuildSpecDocument: Identifiable, Sendable {
    let id: String
    let buildId: String
    let storagePath: String?
    let publicURL: String?
    let version: Int
    let generatedAt: Date?
    let generatedBy: String?
}

extension BuildSpecDocumentRow {
    func toModel() -> BuildSpecDocument {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        return BuildSpecDocument(
            id: id,
            buildId: build_id,
            storagePath: storage_path.isEmpty ? nil : storage_path,
            publicURL: public_url,
            version: version,
            generatedAt: generated_at.flatMap { fmt.date(from: $0) ?? fallback.date(from: $0) },
            generatedBy: generated_by
        )
    }
}
