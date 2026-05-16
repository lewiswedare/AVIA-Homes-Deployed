import Foundation

/// Room/group used by the unified Selections experience.
///
/// Rooms are now driven directly by the admin-managed spec categories in
/// `CatalogDataManager.allSpecCategories` rather than a hardcoded list. Every
/// category an admin creates and adds items to becomes a room — that way the
/// client and admin Selections views always reflect the full catalog instead
/// of silently dropping items whose category name doesn't match a fixed enum.
nonisolated struct SelectionRoom: Identifiable, Sendable, Hashable {
    /// Stable identity — matches the snapshot category name written onto each
    /// `BuildSpecSelection` (which is itself the `SpecCategory.name`).
    let snapshotCategoryName: String

    /// Optional spec category id (e.g. "kitchen", "bath_ensuite") when we can
    /// resolve the matching `SpecCategory` from the catalog. Used to look up
    /// nicer subtitles / hero imagery.
    let categoryId: String?

    let displayName: String
    let subtitle: String
    let icon: String
    let heroImageName: String
    /// Admin-uploaded banner image URL for this category (Supabase storage). When
    /// present, clients see this instead of the bundled `heroImageName` asset.
    let heroImageURL: String?

    var id: String { snapshotCategoryName }

    static func == (lhs: SelectionRoom, rhs: SelectionRoom) -> Bool {
        lhs.snapshotCategoryName == rhs.snapshotCategoryName
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(snapshotCategoryName)
    }
}

@MainActor
extension SelectionRoom {
    /// Build a room from a catalog spec category.
    static func from(specCategory category: SpecCategory) -> SelectionRoom {
        let meta = roomMeta(forCategoryId: category.id, name: category.name)
        let adminImage = category.imageURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        return SelectionRoom(
            snapshotCategoryName: category.name,
            categoryId: category.id,
            displayName: meta.displayName,
            subtitle: meta.subtitle,
            icon: category.icon.isEmpty ? meta.icon : category.icon,
            heroImageName: meta.heroImageName,
            heroImageURL: (adminImage?.isEmpty == false) ? adminImage : nil
        )
    }

    /// Build a room from an arbitrary snapshot category name. If a matching
    /// catalog category exists we use it; otherwise we synthesise a best-effort
    /// room so legacy / out-of-sync selections still show up.
    static func from(snapshotCategoryName name: String) -> SelectionRoom {
        if let category = CatalogDataManager.shared.allSpecCategories.first(where: { $0.name == name }) {
            return from(specCategory: category)
        }
        let meta = roomMeta(forCategoryId: nil, name: name)
        return SelectionRoom(
            snapshotCategoryName: name,
            categoryId: nil,
            displayName: meta.displayName,
            subtitle: meta.subtitle,
            icon: meta.icon,
            heroImageName: meta.heroImageName,
            heroImageURL: nil
        )
    }

    /// Display order — uses the catalog's category order so admins control
    /// what comes first via the catalog editor.
    static var displayOrder: [SelectionRoom] {
        CatalogDataManager.shared.allSpecCategories.map { from(specCategory: $0) }
    }
}

// MARK: - Per-category presentation metadata

private struct RoomMeta {
    let displayName: String
    let subtitle: String
    let icon: String
    let heroImageName: String
}

private func roomMeta(forCategoryId id: String?, name: String) -> RoomMeta {
    if let id, let preset = presetMeta[id] {
        return preset
    }
    // Fallback when name matches a known catalog category but id wasn't passed.
    if let preset = presetMeta.values.first(where: { $0.displayName.caseInsensitiveCompare(name) == .orderedSame }) {
        return preset
    }
    return RoomMeta(
        displayName: name,
        subtitle: "Selections in this category",
        icon: "square.grid.2x2",
        heroImageName: "spec_cabinetry_messina"
    )
}

private let presetMeta: [String: RoomMeta] = [
    "pre_construction": RoomMeta(displayName: "Pre-Construction", subtitle: "Permits, soil tests, planning",
        icon: "doc.text.fill", heroImageName: "facade_classic"),
    "construction": RoomMeta(displayName: "Construction", subtitle: "Build stages & oversight",
        icon: "hammer.fill", heroImageName: "facade_contemporary"),
    "insulation": RoomMeta(displayName: "Insulation", subtitle: "Thermal & acoustic",
        icon: "thermometer.medium", heroImageName: "spec_classic"),
    "site_requirements": RoomMeta(displayName: "Site Requirements", subtitle: "Earthworks & site prep",
        icon: "map.fill", heroImageName: "facade_resort"),
    "frame": RoomMeta(displayName: "Frame", subtitle: "Structure, ceiling, slab",
        icon: "square.split.bottomrightquarter.fill", heroImageName: "facade_contemporary"),
    "external": RoomMeta(displayName: "External", subtitle: "Render, brick, roof, cladding",
        icon: "house.fill", heroImageName: "facade_classic"),
    "windows": RoomMeta(displayName: "Windows", subtitle: "Frames & glazing",
        icon: "rectangle.split.2x1.fill", heroImageName: "facade_coastal"),
    "doors": RoomMeta(displayName: "Doors", subtitle: "Entry, internal, sliding",
        icon: "door.left.hand.open", heroImageName: "spec_front_entry_messina"),
    "electrical": RoomMeta(displayName: "Electrical", subtitle: "Lighting, switches, power",
        icon: "lightbulb.fill", heroImageName: "scheme_neutral_kitchen"),
    "internal_living": RoomMeta(displayName: "Internal Living", subtitle: "Living, dining, family",
        icon: "sofa.fill", heroImageName: "scheme_neutral_living"),
    "kitchen": RoomMeta(displayName: "Kitchen", subtitle: "Cabinetry, benchtops, appliances",
        icon: "fork.knife", heroImageName: "spec_cabinetry_messina"),
    "bath_ensuite": RoomMeta(displayName: "Bath / Ensuite", subtitle: "Tapware, tiles, vanities",
        icon: "shower.fill", heroImageName: "spec_shower_messina"),
    "laundry": RoomMeta(displayName: "Laundry", subtitle: "Tubs, cabinetry, fittings",
        icon: "washer.fill", heroImageName: "colour_laundry_tub"),
    "flooring": RoomMeta(displayName: "Flooring", subtitle: "Carpet, tile, timber, vinyl",
        icon: "square.grid.3x3.fill", heroImageName: "scheme_neutral_living"),
    "paintwork": RoomMeta(displayName: "Paintwork", subtitle: "Walls, ceilings, trim",
        icon: "paintbrush.fill", heroImageName: "scheme_neutral_bedroom"),
    "storage": RoomMeta(displayName: "Storage", subtitle: "Wardrobes, linen, joinery",
        icon: "archivebox.fill", heroImageName: "colour_wardrobes"),
    "colour_selections": RoomMeta(displayName: "Colour Selections", subtitle: "Schemes & palettes",
        icon: "paintpalette.fill", heroImageName: "scheme_coastal_living"),
    "landscaping": RoomMeta(displayName: "Landscaping", subtitle: "Driveway, fencing, gardens",
        icon: "leaf.fill", heroImageName: "facade_resort"),
    "garage": RoomMeta(displayName: "Garage", subtitle: "Doors, finishes, access",
        icon: "car.fill", heroImageName: "facade_classic"),
    "post_construction": RoomMeta(displayName: "Post-Construction", subtitle: "Handover & finishing",
        icon: "checkmark.seal.fill", heroImageName: "facade_contemporary"),
    "warranties": RoomMeta(displayName: "Warranties", subtitle: "Coverage & guarantees",
        icon: "shield.lefthalf.filled", heroImageName: "spec_premium"),
]
