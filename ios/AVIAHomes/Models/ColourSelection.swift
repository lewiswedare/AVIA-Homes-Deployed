import Foundation

nonisolated enum SelectionSection: String, CaseIterable, Sendable {
    case exterior = "Exterior"
    case interior = "Interior"
}

nonisolated struct ColourCategory: Identifiable, Sendable {
    let id: String
    let name: String
    let icon: String
    let section: SelectionSection
    let options: [ColourOption]
    let note: String?
    let imageURL: String?

    init(id: String, name: String, icon: String, section: SelectionSection, options: [ColourOption], note: String? = nil, imageURL: String? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.section = section
        self.options = options
        self.note = note
        self.imageURL = imageURL
    }
}

nonisolated struct ColourOption: Identifiable, Sendable {
    let id: String
    let name: String
    let hexColor: String
    let brand: String?
    let isUpgrade: Bool
    let imageURL: String?
    let availableTiers: Set<String>
    let cost: Double?

    init(id: String, name: String, hexColor: String, brand: String? = nil, isUpgrade: Bool = false, imageURL: String? = nil, availableTiers: Set<String> = [], cost: Double? = nil) {
        self.id = id
        self.name = name
        self.hexColor = hexColor
        self.brand = brand
        self.isUpgrade = isUpgrade
        self.imageURL = imageURL
        self.availableTiers = availableTiers
        self.cost = cost
    }

    func isAvailable(for tier: SpecTier) -> Bool {
        availableTiers.contains(tier.imageKeySuffix)
    }

    func isUpgradeOption(for tier: SpecTier) -> Bool {
        guard !isAvailable(for: tier) else { return false }
        let higherTiers = SpecTier.allCases.filter { $0.tierIndex > tier.tierIndex }
        return higherTiers.contains { isAvailable(for: $0) }
    }
}

nonisolated struct SelectionChoice: Sendable, Equatable {
    let categoryId: String
    let optionId: String
    let optionName: String
    let hexColor: String

    nonisolated static func == (lhs: SelectionChoice, rhs: SelectionChoice) -> Bool {
        lhs.categoryId == rhs.categoryId && lhs.optionId == rhs.optionId
    }
}
