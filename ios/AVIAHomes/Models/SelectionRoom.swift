import Foundation

/// Room/group used by the unified Selections experience. Maps an existing
/// spec snapshot category (e.g. "Kitchen") onto a visual room card so clients
/// can browse upgrades + colours by room rather than by data category.
nonisolated enum SelectionRoom: String, CaseIterable, Sendable, Identifiable {
    case kitchen
    case bathroom
    case flooring
    case internalFinishes
    case electrical
    case windowsDoors
    case external
    case outdoor
    case structure

    var id: String { rawValue }

    /// Matches the snapshotCategoryName values stored on BuildSpecSelection.
    var snapshotCategoryName: String {
        switch self {
        case .kitchen: "Kitchen"
        case .bathroom: "Bathroom & Ensuite"
        case .flooring: "Flooring"
        case .internalFinishes: "Internal Finishes"
        case .electrical: "Electrical & Lighting"
        case .windowsDoors: "Windows & Doors"
        case .external: "External Finishes"
        case .outdoor: "Outdoor & Landscaping"
        case .structure: "Structure & Ceiling"
        }
    }

    var displayName: String {
        switch self {
        case .kitchen: "Kitchen"
        case .bathroom: "Bathroom & Ensuite"
        case .flooring: "Flooring"
        case .internalFinishes: "Internal Finishes"
        case .electrical: "Electrical & Lighting"
        case .windowsDoors: "Windows & Doors"
        case .external: "Exterior"
        case .outdoor: "Outdoor"
        case .structure: "Structure"
        }
    }

    var subtitle: String {
        switch self {
        case .kitchen: "Cabinetry, benchtops, appliances"
        case .bathroom: "Tapware, tiles, vanities"
        case .flooring: "Carpet, tile, timber, vinyl"
        case .internalFinishes: "Walls, doors, joinery"
        case .electrical: "Lighting, switches, power"
        case .windowsDoors: "Frames, glazing, entry"
        case .external: "Render, brick, roof, cladding"
        case .outdoor: "Driveway, landscaping, fencing"
        case .structure: "Frame, ceiling height, slabs"
        }
    }

    var icon: String {
        switch self {
        case .kitchen: "cooktop.fill"
        case .bathroom: "shower.fill"
        case .flooring: "square.stack.3d.up.fill"
        case .internalFinishes: "paintbrush.fill"
        case .electrical: "lightbulb.fill"
        case .windowsDoors: "door.left.hand.open"
        case .external: "house.lodge.fill"
        case .outdoor: "tree.fill"
        case .structure: "square.grid.3x3.square"
        }
    }

    /// Bundled image asset name to use as a hero. Falls back gracefully
    /// to a colour-tinted placeholder if the asset is missing.
    var heroImageName: String {
        switch self {
        case .kitchen: "spec_cabinetry_messina"
        case .bathroom: "spec_shower_messina"
        case .flooring: "scheme_neutral_living"
        case .internalFinishes: "scheme_neutral_bedroom"
        case .electrical: "scheme_neutral_kitchen"
        case .windowsDoors: "spec_front_entry_messina"
        case .external: "facade_classic"
        case .outdoor: "facade_resort"
        case .structure: "facade_contemporary"
        }
    }

    static func from(snapshotCategoryName name: String) -> SelectionRoom? {
        SelectionRoom.allCases.first { $0.snapshotCategoryName == name }
    }

    /// The order rooms should be presented to the client (front-of-mind first).
    static let displayOrder: [SelectionRoom] = [
        .kitchen, .bathroom, .flooring, .internalFinishes,
        .electrical, .windowsDoors, .external, .outdoor, .structure
    ]
}
