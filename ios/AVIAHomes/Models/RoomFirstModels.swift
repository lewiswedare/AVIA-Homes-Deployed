import Foundation

// MARK: - Product Category (Tile, Stone, Tapware, …)
//
// Sits above `spec_items` in the room-first model: every item belongs to one
// product category. Rooms (formerly Spec Categories) are now an orthogonal
// dimension expressed via `variant_room_assignments`.

nonisolated struct ProductCategoryRow: Codable, Sendable, Identifiable, Hashable {
    let id: String
    var name: String
    var icon: String
    var sort_order: Int
    var image_url: String?
}

// MARK: - Variant Room Assignment
//
// Join row that pins a variant (spec_product_colours row) to a Room
// (spec_categories row) for a given Range, with the room-specific image,
// cost, and inclusion status. This replaces the old `(range, item, product)`
// inclusion model for client display + pricing.

nonisolated enum VariantInclusion: String, Codable, Sendable, CaseIterable {
    case included
    case upgrade

    var displayName: String {
        switch self {
        case .included: return "Included"
        case .upgrade:  return "Upgrade"
        }
    }
}

nonisolated struct VariantRoomAssignmentRow: Codable, Sendable, Identifiable, Hashable {
    let id: String?
    let variant_id: String
    let room_id: String
    let range_id: String
    var image_url: String?
    var cost: Double
    var inclusion: String       // "included" | "upgrade"
    var sort_order: Int?

    var inclusionValue: VariantInclusion {
        VariantInclusion(rawValue: inclusion) ?? .included
    }

    /// Stable composite key used to index assignments client-side.
    var compositeKey: String { "\(variant_id)|\(room_id)|\(range_id)" }
}
