import Foundation

nonisolated struct UpgradePricingRow: Codable, Sendable, Identifiable {
    let id: String
    let spec_item_id: String?
    let colour_category_id: String?
    let colour_option_id: String?
    let from_tier: String?
    let to_tier: String?
    let cost: Double
    let description: String?
    let is_active: Bool
    let created_at: String?
    let updated_at: String?

    enum CodingKeys: String, CodingKey {
        case id, spec_item_id, colour_category_id, colour_option_id
        case from_tier, to_tier, cost, description, is_active
        case created_at, updated_at
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(spec_item_id, forKey: .spec_item_id)
        try container.encodeIfPresent(colour_category_id, forKey: .colour_category_id)
        try container.encodeIfPresent(colour_option_id, forKey: .colour_option_id)
        try container.encodeIfPresent(from_tier, forKey: .from_tier)
        try container.encodeIfPresent(to_tier, forKey: .to_tier)
        try container.encode(cost, forKey: .cost)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(is_active, forKey: .is_active)
        try container.encodeIfPresent(updated_at, forKey: .updated_at)
    }
}

struct UpgradePricing: Identifiable, Sendable {
    let id: String
    let specItemId: String?
    let colourCategoryId: String?
    let colourOptionId: String?
    let fromTier: String?
    let toTier: String?
    var cost: Double
    var description: String?
    var isActive: Bool
}

extension UpgradePricingRow {
    func toModel() -> UpgradePricing {
        UpgradePricing(
            id: id,
            specItemId: spec_item_id,
            colourCategoryId: colour_category_id,
            colourOptionId: colour_option_id,
            fromTier: from_tier,
            toTier: to_tier,
            cost: cost,
            description: description,
            isActive: is_active
        )
    }
}

extension UpgradePricing {
    func toRow() -> UpgradePricingRow {
        let iso = ISO8601DateFormatter()
        return UpgradePricingRow(
            id: id,
            spec_item_id: specItemId,
            colour_category_id: colourCategoryId,
            colour_option_id: colourOptionId,
            from_tier: fromTier,
            to_tier: toTier,
            cost: cost,
            description: description,
            is_active: isActive,
            created_at: nil,
            updated_at: iso.string(from: .now)
        )
    }
}
