import Foundation

nonisolated enum BuildSpecStatus: String, Codable, Sendable, CaseIterable {
    case draft
    case clientReviewing = "client_reviewing"
    case awaitingAdmin = "awaiting_admin"
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
        case .reopenedByAdmin: "arrow.counterclockwise"
        case .approved: "checkmark.seal.fill"
        case .amendedByAdmin: "pencil.circle.fill"
        }
    }

    var isLockedForClient: Bool {
        switch self {
        case .awaitingAdmin, .approved, .amendedByAdmin: true
        default: false
        }
    }

    var isFullyApproved: Bool { self == .approved }
}

nonisolated enum SelectionType: String, Codable, Sendable {
    case included
    case upgradeRequested = "upgrade_requested"
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
            sortOrder: sort_order
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
            updated_at: iso.string(from: .now)
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
            adminNotes: admin_notes
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
            updated_at: iso.string(from: .now)
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
