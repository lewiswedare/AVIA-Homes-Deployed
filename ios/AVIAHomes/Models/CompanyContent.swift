import Foundation

nonisolated struct BlogPost: Identifiable, Sendable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let category: String
    let imageURL: String
    let date: Date
    let readTime: String
    let content: String

    init(id: String, title: String, subtitle: String, category: String, imageURL: String, date: Date, readTime: String, content: String = "") {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.imageURL = imageURL
        self.date = date
        self.readTime = readTime
        self.content = content
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    nonisolated static func == (lhs: BlogPost, rhs: BlogPost) -> Bool {
        lhs.id == rhs.id
    }
}

nonisolated struct HomeDesign: Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let bedrooms: Int
    let bathrooms: Int
    let garages: Int
    let squareMeters: Double
    let imageURL: String
    let priceFrom: String
    let storeys: Int
    let lotWidth: Double
    let slug: String
    let description: String
    let houseWidth: Double
    let houseLength: Double
    let livingAreas: Int
    let floorplanImageURL: String
    let roomHighlights: [String]
    let inclusions: [String]

    static let defaultFloorplanURL: String = "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/t6n7lee0b3vwff1rhkljx.webp"

    init(id: String, name: String, bedrooms: Int, bathrooms: Int, garages: Int, squareMeters: Double, imageURL: String, priceFrom: String, storeys: Int = 1, lotWidth: Double = 12.5, slug: String = "", description: String = "", houseWidth: Double = 0, houseLength: Double = 0, livingAreas: Int = 1, floorplanImageURL: String = "", roomHighlights: [String] = [], inclusions: [String] = []) {
        self.id = id
        self.name = name
        self.bedrooms = bedrooms
        self.bathrooms = bathrooms
        self.garages = garages
        self.squareMeters = squareMeters
        self.imageURL = imageURL
        self.priceFrom = priceFrom
        self.storeys = storeys
        self.lotWidth = lotWidth
        self.slug = slug
        self.description = description
        self.houseWidth = houseWidth
        self.houseLength = houseLength
        self.livingAreas = livingAreas
        self.floorplanImageURL = floorplanImageURL.isEmpty ? HomeDesign.defaultFloorplanURL : floorplanImageURL
        self.roomHighlights = roomHighlights
        self.inclusions = inclusions
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    nonisolated static func == (lhs: HomeDesign, rhs: HomeDesign) -> Bool {
        lhs.id == rhs.id
    }
}

nonisolated struct HouseLandPackage: Identifiable, Sendable, Hashable {
    let id: String
    let title: String
    let location: String
    let lotSize: String
    let homeDesign: String
    let price: String
    let imageURL: String
    let isNew: Bool
    let lotNumber: String
    let lotFrontage: String
    let lotDepth: String
    let landPrice: String
    let housePrice: String
    let specTier: SpecTier
    let titleDate: String
    let council: String
    let zoning: String
    let buildTimeEstimate: String
    let inclusions: [String]
    let isCustom: Bool
    let customBedrooms: Int?
    let customBathrooms: Int?
    let customGarages: Int?
    let customSquareMeters: Double?
    let customStoreys: Int?
    let selectedFacadeId: String?

    init(id: String, title: String, location: String, lotSize: String, homeDesign: String, price: String, imageURL: String, isNew: Bool, lotNumber: String, lotFrontage: String, lotDepth: String, landPrice: String, housePrice: String, specTier: SpecTier, titleDate: String, council: String, zoning: String, buildTimeEstimate: String, inclusions: [String], isCustom: Bool = false, customBedrooms: Int? = nil, customBathrooms: Int? = nil, customGarages: Int? = nil, customSquareMeters: Double? = nil, customStoreys: Int? = nil, selectedFacadeId: String? = nil) {
        self.id = id
        self.title = title
        self.location = location
        self.lotSize = lotSize
        self.homeDesign = homeDesign
        self.price = price
        self.imageURL = imageURL
        self.isNew = isNew
        self.lotNumber = lotNumber
        self.lotFrontage = lotFrontage
        self.lotDepth = lotDepth
        self.landPrice = landPrice
        self.housePrice = housePrice
        self.specTier = specTier
        self.titleDate = titleDate
        self.council = council
        self.zoning = zoning
        self.buildTimeEstimate = buildTimeEstimate
        self.inclusions = inclusions
        self.isCustom = isCustom
        self.customBedrooms = customBedrooms
        self.customBathrooms = customBathrooms
        self.customGarages = customGarages
        self.customSquareMeters = customSquareMeters
        self.customStoreys = customStoreys
        self.selectedFacadeId = selectedFacadeId
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    nonisolated static func == (lhs: HouseLandPackage, rhs: HouseLandPackage) -> Bool {
        lhs.id == rhs.id
    }

    var matchedDesign: HomeDesign? {
        nil
    }

    var matchedEstate: LandEstate? {
        nil
    }

    var matchedFacade: Facade? {
        nil
    }
}

extension BlogPost {
    static let samples: [BlogPost] = []
}

extension HomeDesign {
    static let samples: [HomeDesign] = []
    static let allDesigns: [HomeDesign] = []
}

nonisolated enum PackageStatus: String, CaseIterable, Sendable {
    case available = "Available"
    case underOffer = "Under Offer"
    case sold = "Sold"
}

extension HouseLandPackage {
    var bedrooms: Int {
        if let custom = customBedrooms { return custom }
        return 4
    }
    var bathrooms: Int {
        if let custom = customBathrooms { return custom }
        return 2
    }
    var garages: Int {
        if let custom = customGarages { return custom }
        return 2
    }
    var status: PackageStatus {
        .available
    }
    var estate: String {
        let loc = location.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? location
        return loc
    }

    static let allPackages: [HouseLandPackage] = []
    static let samples: [HouseLandPackage] = []
}
