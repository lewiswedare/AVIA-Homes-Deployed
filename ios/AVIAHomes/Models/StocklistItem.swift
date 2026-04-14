import Foundation

struct StocklistRegion: Identifiable {
    let id = UUID()
    let name: String
    let subRegions: [StocklistSubRegion]
}

struct StocklistSubRegion: Identifiable {
    let id = UUID()
    let name: String
    let estates: [StocklistEstate]
}

struct StocklistEstate: Identifiable {
    let id = UUID()
    let name: String
    let depositTerms: String
    var lots: [StocklistLot]
}

struct StocklistLot: Identifiable {
    let id = UUID()
    let lotNumber: String
    let stage: String
    let street: String
    let landSize: String
    let landPrice: String
    let registered: String
    let designFacade: String
    let buildSize: String
    let bedrooms: String
    let bathrooms: String
    let garages: String
    let theatre: String
    let buildPrice: String
    let packagePrice: String
    let specification: String
    let status: String
    let ownerOccInvestor: String
    let availability: String
    let salesPackageLink: String?
    let alternativeDesigns: [StocklistAlternativeDesign]
}

struct StocklistAlternativeDesign: Identifiable {
    let id = UUID()
    let designFacade: String
    let buildSize: String
    let bedrooms: String
    let bathrooms: String
    let garages: String
    let theatre: String
    let buildPrice: String
    let packagePrice: String
    let specification: String
}
