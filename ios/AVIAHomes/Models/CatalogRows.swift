import Foundation

nonisolated struct ColourCategoryRow: Codable, Sendable {
    let id: String
    let name: String
    let icon: String
    let section: String
    let note: String?
    let image_url: String?
    let sort_order: Int
    let options: [ColourOptionRow]

    struct ColourOptionRow: Codable, Sendable {
        let id: String
        let name: String
        let hex_color: String?
        let brand: String?
        let is_upgrade: Bool?
        let image_url: String?
        let available_tiers: [String]?
    }

    func toColourCategory() -> ColourCategory {
        ColourCategory(
            id: id,
            name: name,
            icon: icon,
            section: section == "exterior" ? .exterior : .interior,
            options: options.map {
                ColourOption(id: $0.id, name: $0.name, hexColor: $0.hex_color ?? "CCCCCC", brand: $0.brand, isUpgrade: $0.is_upgrade ?? false, imageURL: $0.image_url, availableTiers: Set($0.available_tiers ?? []))
            },
            note: note,
            imageURL: image_url
        )
    }
}

nonisolated struct SpecCategoryRow: Codable, Sendable {
    let id: String
    let name: String
    let icon: String
    let sort_order: Int
    let items: [SpecItemRow]

    struct SpecItemRow: Codable, Sendable {
        let id: String
        let name: String
        let volos_description: String
        let messina_description: String
        let portobello_description: String
        let is_upgradeable: Bool
    }

    func toSpecCategory() -> SpecCategory {
        SpecCategory(
            id: id,
            name: name,
            icon: icon,
            items: items.map {
                SpecItem(
                    id: $0.id,
                    name: $0.name,
                    volosDescription: $0.volos_description,
                    messinaDescription: $0.messina_description,
                    portobelloDescription: $0.portobello_description,
                    isUpgradeable: $0.is_upgradeable
                )
            }
        )
    }
}

nonisolated struct SpecRangeTierRow: Codable, Sendable {
    let tier: String
    let hero_image_url: String
    let summary: String
    let highlights: [HighlightRow]
    let room_images: [RoomImageRow]

    struct HighlightRow: Codable, Sendable {
        let icon: String
        let title: String
        let subtitle: String
    }

    struct RoomImageRow: Codable, Sendable {
        let name: String
        let image_url: String
    }

    func toSpecRangeData() -> SpecRangeData {
        SpecRangeData(
            heroImageURL: hero_image_url,
            summary: summary,
            highlights: highlights.map {
                SpecRangeHighlight(icon: $0.icon, title: $0.title, subtitle: $0.subtitle)
            }
        )
    }

    func toRoomImages() -> [(name: String, imageURL: String)] {
        room_images.map { ($0.name, $0.image_url) }
    }
}

nonisolated struct HomeFastSchemeRow: Codable, Sendable {
    let id: String
    let name: String
    let subtitle: String
    let preview_colors: [String]
    let selections: [String: SchemeSelectionRow]
    let room_images: [SchemeRoomImageRow]
    let sort_order: Int

    struct SchemeSelectionRow: Codable, Sendable {
        let option_id: String
        let option_name: String
        let hex_color: String
    }

    struct SchemeRoomImageRow: Codable, Sendable {
        let room: String
        let label: String
        let asset_name: String
    }

    func toHomeFastScheme() -> HomeFastScheme {
        HomeFastScheme(
            id: id,
            name: name,
            subtitle: subtitle,
            previewColors: preview_colors,
            selections: selections.mapValues {
                SchemeSelection(optionId: $0.option_id, optionName: $0.option_name, hexColor: $0.hex_color)
            },
            roomImages: room_images.map {
                SchemeRoomImage(room: $0.room, label: $0.label, assetName: $0.asset_name)
            }
        )
    }
}

nonisolated struct SpecItemFlatRow: Codable, Sendable {
    let id: String
    let category_id: String
    let name: String
    let volos_description: String
    let messina_description: String
    let portobello_description: String
    let is_upgradeable: Bool?
    let image_url: String?
    let sort_order: Int?

    func toSpecItem() -> SpecItem {
        SpecItem(
            id: id,
            name: name,
            volosDescription: volos_description,
            messinaDescription: messina_description,
            portobelloDescription: portobello_description,
            isUpgradeable: is_upgradeable ?? false,
            customImageURL: image_url
        )
    }
}

nonisolated struct SpecToColourMappingRow: Codable, Sendable {
    let spec_item_id: String
    let colour_category_ids: [String]
}

nonisolated struct SpecItemImageRow: Codable, Sendable {
    let spec_item_id: String
    let base_image_url: String?
    let tier_images: [String: String]?
}

nonisolated struct ColourCategoryUpsertRow: Codable, Sendable {
    let id: String
    let name: String
    let icon: String
    let section: String
    let note: String?
    let image_url: String?
    let sort_order: Int
    let options: [ColourCategoryRow.ColourOptionRow]

    init(from category: ColourCategory, sortOrder: Int) {
        id = category.id
        name = category.name
        icon = category.icon
        section = category.section == .exterior ? "exterior" : "interior"
        note = category.note
        image_url = category.imageURL
        sort_order = sortOrder
        options = category.options.map {
            ColourCategoryRow.ColourOptionRow(
                id: $0.id, name: $0.name, hex_color: $0.hexColor,
                brand: $0.brand, is_upgrade: $0.isUpgrade, image_url: $0.imageURL,
                available_tiers: Array($0.availableTiers).sorted()
            )
        }
    }
}
