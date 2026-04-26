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
    let default_option_cost: Double?
    let applicable_tiers: [String]?

    struct ColourOptionRow: Codable, Sendable {
        let id: String
        let name: String
        let hex_color: String?
        let brand: String?
        let is_upgrade: Bool?
        let image_url: String?
        let available_tiers: [String]?
        let cost: Double?
        let applicable_tiers: [String]?
    }

    func toColourCategory() -> ColourCategory {
        ColourCategory(
            id: id,
            name: name,
            icon: icon,
            section: section == "exterior" ? .exterior : .interior,
            options: options.map {
                ColourOption(id: $0.id, name: $0.name, hexColor: $0.hex_color ?? "CCCCCC", brand: $0.brand, isUpgrade: $0.is_upgrade ?? false, imageURL: $0.image_url, availableTiers: Set($0.available_tiers ?? []), cost: $0.cost, applicableTiers: $0.applicable_tiers)
            },
            note: note,
            imageURL: image_url,
            defaultOptionCost: default_option_cost,
            applicableTiers: applicable_tiers,
            specItemId: nil
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
        let volos_cost: Double?
        let messina_cost: Double?
        let portobello_cost: Double?
        let volos_to_messina_cost: Double?
        let volos_to_portobello_cost: Double?
        let messina_to_portobello_cost: Double?
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
                    isUpgradeable: $0.is_upgradeable,
                    volosCost: $0.volos_cost,
                    messinaCost: $0.messina_cost,
                    portobelloCost: $0.portobello_cost,
                    volosToMessinaCost: $0.volos_to_messina_cost,
                    volosToPortobelloCost: $0.volos_to_portobello_cost,
                    messinaToPortobelloCost: $0.messina_to_portobello_cost
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
    let partner_logos: [PartnerLogoRow]?
    let pdf_url: String?

    struct HighlightRow: Codable, Sendable {
        let icon: String
        let title: String
        let subtitle: String
        let icon_image_url: String?
        let detail_image_url: String?

        init(icon: String, title: String, subtitle: String, icon_image_url: String? = nil, detail_image_url: String? = nil) {
            self.icon = icon
            self.title = title
            self.subtitle = subtitle
            self.icon_image_url = icon_image_url
            self.detail_image_url = detail_image_url
        }
    }

    struct RoomImageRow: Codable, Sendable {
        let name: String
        let image_url: String
    }

    struct PartnerLogoRow: Codable, Sendable {
        let name: String
        let image_url: String
    }

    init(
        tier: String,
        hero_image_url: String,
        summary: String,
        highlights: [HighlightRow],
        room_images: [RoomImageRow],
        partner_logos: [PartnerLogoRow]? = nil,
        pdf_url: String? = nil
    ) {
        self.tier = tier
        self.hero_image_url = hero_image_url
        self.summary = summary
        self.highlights = highlights
        self.room_images = room_images
        self.partner_logos = partner_logos
        self.pdf_url = pdf_url
    }

    func toSpecRangeData() -> SpecRangeData {
        SpecRangeData(
            heroImageURL: hero_image_url,
            summary: summary,
            highlights: highlights.map {
                SpecRangeHighlight(
                    icon: $0.icon,
                    title: $0.title,
                    subtitle: $0.subtitle,
                    iconImageURL: $0.icon_image_url,
                    detailImageURL: $0.detail_image_url
                )
            },
            partnerLogos: (partner_logos ?? []).map {
                SpecRangePartnerLogo(name: $0.name, imageURL: $0.image_url)
            },
            pdfURL: pdf_url
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
    let volos_cost: Double?
    let messina_cost: Double?
    let portobello_cost: Double?
    let volos_to_messina_cost: Double?
    let volos_to_portobello_cost: Double?
    let messina_to_portobello_cost: Double?

    init(id: String, category_id: String, name: String, volos_description: String, messina_description: String, portobello_description: String, is_upgradeable: Bool?, image_url: String?, sort_order: Int?, volos_cost: Double? = nil, messina_cost: Double? = nil, portobello_cost: Double? = nil, volos_to_messina_cost: Double? = nil, volos_to_portobello_cost: Double? = nil, messina_to_portobello_cost: Double? = nil) {
        self.id = id
        self.category_id = category_id
        self.name = name
        self.volos_description = volos_description
        self.messina_description = messina_description
        self.portobello_description = portobello_description
        self.is_upgradeable = is_upgradeable
        self.image_url = image_url
        self.sort_order = sort_order
        self.volos_cost = volos_cost
        self.messina_cost = messina_cost
        self.portobello_cost = portobello_cost
        self.volos_to_messina_cost = volos_to_messina_cost
        self.volos_to_portobello_cost = volos_to_portobello_cost
        self.messina_to_portobello_cost = messina_to_portobello_cost
    }

    func toSpecItem() -> SpecItem {
        SpecItem(
            id: id,
            name: name,
            volosDescription: volos_description,
            messinaDescription: messina_description,
            portobelloDescription: portobello_description,
            isUpgradeable: is_upgradeable ?? false,
            customImageURL: image_url,
            volosCost: volos_cost,
            messinaCost: messina_cost,
            portobelloCost: portobello_cost,
            volosToMessinaCost: volos_to_messina_cost,
            volosToPortobelloCost: volos_to_portobello_cost,
            messinaToPortobelloCost: messina_to_portobello_cost
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
    let default_option_cost: Double?
    let applicable_tiers: [String]?

    init(from category: ColourCategory, sortOrder: Int) {
        id = category.id
        name = category.name
        icon = category.icon
        section = category.section == .exterior ? "exterior" : "interior"
        note = category.note
        image_url = category.imageURL
        sort_order = sortOrder
        default_option_cost = category.defaultOptionCost
        applicable_tiers = category.applicableTiers
        options = category.options.map {
            ColourCategoryRow.ColourOptionRow(
                id: $0.id, name: $0.name, hex_color: $0.hexColor,
                brand: $0.brand, is_upgrade: $0.isUpgrade, image_url: $0.imageURL,
                available_tiers: Array($0.availableTiers).sorted(),
                cost: $0.cost,
                applicable_tiers: $0.applicableTiers
            )
        }
    }
}
