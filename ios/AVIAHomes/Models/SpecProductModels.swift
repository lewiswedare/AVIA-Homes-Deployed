import Foundation

// Database row for `spec_products`.
nonisolated struct SpecProductRow: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let spec_item_id: String
    var brand: String?
    var model: String?
    var sku: String?
    var name: String
    var description: String?
    var image_url: String?
    var dimensions: String?
    var is_active: Bool?
    var sort_order: Int?
}

// Database row for `spec_product_colours`.
nonisolated struct SpecProductColourRow: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let product_id: String
    var name: String
    var hex: String?
    var image_url: String?
    var is_default: Bool?
    var is_active: Bool?
    var sort_order: Int?
    var extra_cost: Double?
    var sku: String?
}

// Database row for `spec_range_item_products` — per-(range, slot, product) overrides.
nonisolated struct SpecRangeItemProductRow: Codable, Sendable, Identifiable, Hashable {
    let id: String?
    let range_id: String
    let spec_item_id: String
    let product_id: String
    var is_default: Bool?
    var inclusion_override: String?      // "included" | "upgrade" | "unavailable" | nil = inherit from spec_range_items
    var upgrade_price_override: Double?
    var sort_order: Int?
}

// Inclusion status for a product within a given range.
enum ProductRangeInclusion: String, Codable, Sendable, CaseIterable {
    case included
    case upgrade
    case unavailable

    var displayName: String {
        switch self {
        case .included: return "Included"
        case .upgrade: return "Upgrade"
        case .unavailable: return "Unavailable"
        }
    }
}

// In-memory editing model for a product's per-range membership.
struct EditableProductRangeMembership: Identifiable, Hashable {
    let rangeId: String          // "volos" | "messina" | "portobello"
    var inclusion: ProductRangeInclusion
    var upgradeCost: String      // empty string = no override
    var isDefault: Bool

    var id: String { rangeId }
}

// In-memory editing model for a product colour swatch.
struct EditableProductColour: Identifiable, Hashable {
    let id: String
    var name: String
    var hex: String
    var imageURL: String
    var isDefault: Bool
    var extraCost: String        // empty = no extra cost
    var sortOrder: Int
    var sku: String              // empty = no variant SKU
}
