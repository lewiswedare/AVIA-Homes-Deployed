import Foundation

nonisolated struct Facade: Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let style: String
    let description: String
    let heroImageURL: String
    let galleryImageURLs: [String]
    let features: [String]
    let pricing: FacadePricing
    let storeys: Int

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    nonisolated static func == (lhs: Facade, rhs: Facade) -> Bool {
        lhs.id == rhs.id
    }
}

nonisolated enum FacadePricing: Sendable, Hashable {
    case included
    case upgrade(String)

    var displayText: String {
        switch self {
        case .included: "Included"
        case .upgrade(let cost): cost
        }
    }

    var isIncluded: Bool {
        if case .included = self { return true }
        return false
    }
}

extension Facade {
    static let allFacades: [Facade] = []
}
