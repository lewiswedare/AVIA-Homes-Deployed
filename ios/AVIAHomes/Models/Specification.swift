import Foundation

nonisolated enum SpecTier: String, CaseIterable, Sendable, Identifiable, Hashable {
    case volos = "Volos"
    case messina = "Messina"
    case portobello = "Portobello"

    var id: String { rawValue }

    var tagline: String {
        switch self {
        case .volos: "Essential Living"
        case .messina: "Elevated Comfort"
        case .portobello: "Premium Collection"
        }
    }

    var imageKeySuffix: String {
        switch self {
        case .volos: "volos"
        case .messina: "messina"
        case .portobello: "portobello"
        }
    }

    var tierIndex: Int {
        switch self {
        case .volos: 0
        case .messina: 1
        case .portobello: 2
        }
    }

    var icon: String {
        switch self {
        case .volos: "house.fill"
        case .messina: "house.and.flag.fill"
        case .portobello: "crown.fill"
        }
    }

    var imageName: String {
        switch self {
        case .volos: "spec_volos"
        case .messina: "spec_messina"
        case .portobello: "spec_vogue"
        }
    }
}

nonisolated struct SpecCategory: Identifiable, Sendable {
    let id: String
    let name: String
    let icon: String
    let items: [SpecItem]
}

nonisolated struct SpecItem: Identifiable, Sendable {
    let id: String
    let name: String
    let volosDescription: String
    let messinaDescription: String
    let portobelloDescription: String
    let isUpgradeable: Bool
    let customImageURL: String?

    init(id: String, name: String, volosDescription: String, messinaDescription: String, portobelloDescription: String, isUpgradeable: Bool, customImageURL: String? = nil) {
        self.id = id
        self.name = name
        self.volosDescription = volosDescription
        self.messinaDescription = messinaDescription
        self.portobelloDescription = portobelloDescription
        self.isUpgradeable = isUpgradeable
        self.customImageURL = customImageURL
    }

    func description(for tier: SpecTier) -> String {
        switch tier {
        case .volos: volosDescription
        case .messina: messinaDescription
        case .portobello: portobelloDescription
        }
    }

    var imageURL: URL? {
        if let custom = customImageURL, !custom.isEmpty {
            return URL(string: custom)
        }
        let catalog = CatalogDataManager.shared
        return catalog.baseImageURL(for: id)
    }

    var hasTierSpecificImages: Bool {
        let catalog = CatalogDataManager.shared
        return catalog.specItemTierImages.keys.contains(where: { $0.hasPrefix(id + "_") })
    }

    func bundledImageName(for tier: SpecTier) -> String? {
        nil
    }

    func tierImageURL(for tier: SpecTier) -> URL? {
        let catalog = CatalogDataManager.shared
        return catalog.tierImageURL(for: id, tier: tier)
    }

    static let seedTierImageURLMapping: [String: String] = [:]
    static let seedBaseImageMapping: [String: String] = [:]
}

nonisolated struct UpgradeRequest: Identifiable, Sendable {
    let id: String
    let itemId: String
    let itemName: String
    let categoryName: String
    let fromTier: SpecTier
    let toTier: SpecTier
    let dateRequested: Date
    var status: UpgradeStatus
}

nonisolated enum UpgradeStatus: String, Sendable {
    case pending = "Pending"
    case quoted = "Quoted"
    case approved = "Approved"
    case declined = "Declined"
}

extension SpecCategory {
    static let seedCategories: [SpecCategory] = []
}
