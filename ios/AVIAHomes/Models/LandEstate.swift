import Foundation

nonisolated struct LandEstate: Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let location: String
    let suburb: String
    let status: EstateStatus
    let totalLots: Int
    let availableLots: Int
    let priceFrom: String
    let imageURL: String
    let description: String
    let features: [String]
    let expectedCompletion: String
    let logoURL: String?
    let logoAssetName: String?
    let brochureURL: String?
    let siteMapURL: String?
    let siteMapAssetName: String?

    nonisolated enum EstateStatus: String, CaseIterable, Sendable {
        case current = "Current"
        case upcoming = "Upcoming"
        case completed = "Completed"
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    nonisolated static func == (lhs: LandEstate, rhs: LandEstate) -> Bool {
        lhs.id == rhs.id
    }
}

extension LandEstate {
    static let allEstates: [LandEstate] = []
}
