import Foundation

struct StocklistEstateRow: Codable, Identifiable, Sendable {
    let id: String
    var name: String
    var region: String
    var sub_region: String?
    var deposit_terms: String?
    var estate_brochure_url: String?
    var rental_appraisal_url: String?
    var eoi_form_url: String?
    var sort_order: Int
    var is_active: Bool
    let created_at: String?
    let updated_at: String?
}

struct StocklistItemRow: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var estate_id: String
    var lot_number: String
    var stage: String?
    var street: String?
    var land_size: String?
    var land_price: String?
    var registered: String?
    var design_facade: String?
    var build_size: String?
    var bedrooms: String?
    var bathrooms: String?
    var garages: String?
    var theatre: String?
    var build_price: String?
    var package_price: String?
    var specification: String?
    var status: String
    var owner_occ_investor: String?
    var availability: String?
    var sales_package_link: String?
    var is_coming_soon: Bool
    var sort_order: Int
    let created_at: String?
    let updated_at: String?
}

struct StocklistAltDesignRow: Codable, Identifiable, Sendable {
    let id: String
    var stocklist_item_id: String
    var design_facade: String
    var build_size: String?
    var bedrooms: String?
    var bathrooms: String?
    var garages: String?
    var theatre: String?
    var build_price: String?
    var package_price: String?
    var specification: String?
}
