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

struct StocklistItemRow: Codable, Identifiable, Sendable {
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

extension StocklistItemRow {
    func toHouseLandPackage(estateName: String) -> HouseLandPackage {
        let specTier: SpecTier
        switch (specification ?? "").lowercased() {
        case "messina": specTier = .messina
        case "portobello": specTier = .portobello
        default: specTier = .volos
        }

        return HouseLandPackage(
            id: "stocklist_\(id)",
            title: design_facade ?? "Lot \(lot_number)",
            location: estateName,
            lotSize: land_size ?? "",
            homeDesign: design_facade ?? "",
            price: package_price ?? land_price ?? "",
            imageURL: "",
            isNew: false,
            lotNumber: lot_number,
            lotFrontage: "",
            lotDepth: "",
            landPrice: land_price ?? "",
            housePrice: build_price ?? "",
            specTier: specTier,
            titleDate: registered ?? "",
            council: "",
            zoning: "",
            buildTimeEstimate: "",
            inclusions: [],
            isCustom: (design_facade ?? "").lowercased().contains("custom"),
            customBedrooms: Int(bedrooms ?? ""),
            customBathrooms: Int(bathrooms ?? ""),
            customGarages: Int(garages ?? ""),
            customSquareMeters: {
                guard let bs = build_size?.replacingOccurrences(of: "m2", with: "") else { return nil }
                return Double(bs)
            }(),
            customStoreys: nil,
            selectedFacadeId: nil
        )
    }
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
