import Foundation

nonisolated struct HomeDesignRow: Codable, Sendable {
    let id: String
    let name: String
    let bedrooms: Int
    let bathrooms: Int
    let garages: Int
    let square_meters: Double
    let image_url: String
    let price_from: String
    let storeys: Int
    let lot_width: Double
    let slug: String
    let description: String
    let house_width: Double
    let house_length: Double
    let living_areas: Int
    let floorplan_image_url: String
    let room_highlights: [String]
    let inclusions: [String]

    init(from design: HomeDesign) {
        id = design.id
        name = design.name
        bedrooms = design.bedrooms
        bathrooms = design.bathrooms
        garages = design.garages
        square_meters = design.squareMeters
        image_url = design.imageURL
        price_from = design.priceFrom
        storeys = design.storeys
        lot_width = design.lotWidth
        slug = design.slug
        description = design.description
        house_width = design.houseWidth
        house_length = design.houseLength
        living_areas = design.livingAreas
        floorplan_image_url = design.floorplanImageURL
        room_highlights = design.roomHighlights
        inclusions = design.inclusions
    }

    func toHomeDesign() -> HomeDesign {
        HomeDesign(
            id: id,
            name: name,
            bedrooms: bedrooms,
            bathrooms: bathrooms,
            garages: garages,
            squareMeters: square_meters,
            imageURL: image_url,
            priceFrom: price_from,
            storeys: storeys,
            lotWidth: lot_width,
            slug: slug,
            description: description,
            houseWidth: house_width,
            houseLength: house_length,
            livingAreas: living_areas,
            floorplanImageURL: floorplan_image_url,
            roomHighlights: room_highlights,
            inclusions: inclusions
        )
    }
}

nonisolated struct HouseLandPackageRow: Codable, Sendable {
    let id: String
    let title: String
    let location: String
    let lot_size: String
    let home_design: String
    let price: String
    let image_url: String
    let is_new: Bool
    let lot_number: String
    let lot_frontage: String
    let lot_depth: String
    let land_price: String
    let house_price: String
    let spec_tier: String
    let title_date: String
    let council: String
    let zoning: String
    let build_time_estimate: String
    let inclusions: [String]
    let is_custom: Bool?
    let custom_bedrooms: Int?
    let custom_bathrooms: Int?
    let custom_garages: Int?
    let custom_square_meters: Double?
    let custom_storeys: Int?
    let selected_facade_id: String?

    enum CodingKeys: String, CodingKey {
        case id, title, location, lot_size, home_design, price, image_url, is_new
        case lot_number, lot_frontage, lot_depth, land_price, house_price
        case spec_tier, title_date, council, zoning, build_time_estimate, inclusions
        case is_custom, custom_bedrooms, custom_bathrooms, custom_garages
        case custom_square_meters, custom_storeys, selected_facade_id
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        location = try container.decode(String.self, forKey: .location)
        lot_size = try container.decode(String.self, forKey: .lot_size)
        home_design = try container.decode(String.self, forKey: .home_design)
        price = try container.decode(String.self, forKey: .price)
        image_url = try container.decode(String.self, forKey: .image_url)
        is_new = try container.decode(Bool.self, forKey: .is_new)
        lot_number = try container.decode(String.self, forKey: .lot_number)
        lot_frontage = try container.decode(String.self, forKey: .lot_frontage)
        lot_depth = try container.decode(String.self, forKey: .lot_depth)
        land_price = try container.decode(String.self, forKey: .land_price)
        house_price = try container.decode(String.self, forKey: .house_price)
        spec_tier = try container.decode(String.self, forKey: .spec_tier)
        title_date = try container.decode(String.self, forKey: .title_date)
        council = try container.decode(String.self, forKey: .council)
        zoning = try container.decode(String.self, forKey: .zoning)
        build_time_estimate = try container.decode(String.self, forKey: .build_time_estimate)
        inclusions = try container.decode([String].self, forKey: .inclusions)
        is_custom = try container.decodeIfPresent(Bool.self, forKey: .is_custom)
        custom_bedrooms = try container.decodeIfPresent(Int.self, forKey: .custom_bedrooms)
        custom_bathrooms = try container.decodeIfPresent(Int.self, forKey: .custom_bathrooms)
        custom_garages = try container.decodeIfPresent(Int.self, forKey: .custom_garages)
        custom_storeys = try container.decodeIfPresent(Int.self, forKey: .custom_storeys)
        selected_facade_id = try container.decodeIfPresent(String.self, forKey: .selected_facade_id)
        // PostgREST returns numeric columns as JSON strings (e.g. "12.50")
        if let d = try? container.decodeIfPresent(Double.self, forKey: .custom_square_meters) {
            custom_square_meters = d
        } else if let s = try? container.decodeIfPresent(String.self, forKey: .custom_square_meters), let d = Double(s) {
            custom_square_meters = d
        } else {
            custom_square_meters = nil
        }
    }

    init(from pkg: HouseLandPackage) {
        id = pkg.id
        title = pkg.title
        location = pkg.location
        lot_size = pkg.lotSize
        home_design = pkg.homeDesign
        price = pkg.price
        image_url = pkg.imageURL
        is_new = pkg.isNew
        lot_number = pkg.lotNumber
        lot_frontage = pkg.lotFrontage
        lot_depth = pkg.lotDepth
        land_price = pkg.landPrice
        house_price = pkg.housePrice
        spec_tier = pkg.specTier.rawValue
        title_date = pkg.titleDate
        council = pkg.council
        zoning = pkg.zoning
        build_time_estimate = pkg.buildTimeEstimate
        inclusions = pkg.inclusions
        is_custom = pkg.isCustom
        custom_bedrooms = pkg.customBedrooms
        custom_bathrooms = pkg.customBathrooms
        custom_garages = pkg.customGarages
        custom_square_meters = pkg.customSquareMeters
        custom_storeys = pkg.customStoreys
        selected_facade_id = pkg.selectedFacadeId
    }

    func toHouseLandPackage() -> HouseLandPackage {
        HouseLandPackage(
            id: id,
            title: title,
            location: location,
            lotSize: lot_size,
            homeDesign: home_design,
            price: price,
            imageURL: image_url,
            isNew: is_new,
            lotNumber: lot_number,
            lotFrontage: lot_frontage,
            lotDepth: lot_depth,
            landPrice: land_price,
            housePrice: house_price,
            specTier: SpecTier(rawValue: spec_tier) ?? .messina,
            titleDate: title_date,
            council: council,
            zoning: zoning,
            buildTimeEstimate: build_time_estimate,
            inclusions: inclusions,
            isCustom: is_custom ?? false,
            customBedrooms: custom_bedrooms,
            customBathrooms: custom_bathrooms,
            customGarages: custom_garages,
            customSquareMeters: custom_square_meters,
            customStoreys: custom_storeys,
            selectedFacadeId: selected_facade_id
        )
    }
}

nonisolated struct BlogPostRow: Codable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let category: String
    let image_url: String
    let date: String
    let read_time: String
    let content: String

    init(from post: BlogPost) {
        let iso = ISO8601DateFormatter()
        id = post.id
        title = post.title
        subtitle = post.subtitle
        category = post.category
        image_url = post.imageURL
        date = iso.string(from: post.date)
        read_time = post.readTime
        content = post.content
    }

    func toBlogPost() -> BlogPost {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        return BlogPost(
            id: id,
            title: title,
            subtitle: subtitle,
            category: category,
            imageURL: image_url,
            date: formatter.date(from: date) ?? fallback.date(from: date) ?? .now,
            readTime: read_time,
            content: content
        )
    }
}

nonisolated struct LandEstateRow: Codable, Sendable {
    let id: String
    let name: String
    let location: String
    let suburb: String
    let status: String
    let total_lots: Int
    let available_lots: Int
    let price_from: String
    let image_url: String
    let description: String
    let features: [String]
    let expected_completion: String
    let logo_url: String?
    let logo_asset_name: String?
    let brochure_url: String?
    let site_map_url: String?
    let site_map_asset_name: String?

    init(from estate: LandEstate) {
        id = estate.id
        name = estate.name
        location = estate.location
        suburb = estate.suburb
        status = estate.status.rawValue
        total_lots = estate.totalLots
        available_lots = estate.availableLots
        price_from = estate.priceFrom
        image_url = estate.imageURL
        description = estate.description
        features = estate.features
        expected_completion = estate.expectedCompletion
        logo_url = estate.logoURL
        logo_asset_name = estate.logoAssetName
        brochure_url = estate.brochureURL
        site_map_url = estate.siteMapURL
        site_map_asset_name = estate.siteMapAssetName
    }

    func toLandEstate() -> LandEstate {
        LandEstate(
            id: id,
            name: name,
            location: location,
            suburb: suburb,
            status: LandEstate.EstateStatus(rawValue: status) ?? .current,
            totalLots: total_lots,
            availableLots: available_lots,
            priceFrom: price_from,
            imageURL: image_url,
            description: description,
            features: features,
            expectedCompletion: expected_completion,
            logoURL: logo_url,
            logoAssetName: logo_asset_name,
            brochureURL: brochure_url,
            siteMapURL: site_map_url,
            siteMapAssetName: site_map_asset_name
        )
    }
}

nonisolated struct FacadeRow: Codable, Sendable {
    let id: String
    let name: String
    let style: String
    let description: String
    let hero_image_url: String
    let gallery_image_urls: [String]
    let features: [String]
    let pricing_type: String
    let pricing_amount: String?
    let storeys: Int

    init(from facade: Facade) {
        id = facade.id
        name = facade.name
        style = facade.style
        description = facade.description
        hero_image_url = facade.heroImageURL
        gallery_image_urls = facade.galleryImageURLs
        features = facade.features
        switch facade.pricing {
        case .included:
            pricing_type = "included"
            pricing_amount = nil
        case .upgrade(let amount):
            pricing_type = "upgrade"
            pricing_amount = amount
        }
        storeys = facade.storeys
    }

    func toFacade() -> Facade {
        let pricing: FacadePricing
        if pricing_type == "included" {
            pricing = .included
        } else {
            pricing = .upgrade(pricing_amount ?? "$0")
        }
        return Facade(
            id: id,
            name: name,
            style: style,
            description: description,
            heroImageURL: hero_image_url,
            galleryImageURLs: gallery_image_urls,
            features: features,
            pricing: pricing,
            storeys: storeys
        )
    }
}

nonisolated struct ClientDocumentRow: Codable, Sendable {
    let id: String
    let client_id: String
    let name: String
    let category: String
    let date_added: String
    let file_size: String
    let is_new: Bool
    let file_url: String?
    let build_id: String?
    let build_stage_id: String?
    let created_at: String?

    init(from doc: ClientDocument, clientId: String, buildId: String? = nil, buildStageId: String? = nil) {
        let iso = ISO8601DateFormatter()
        id = doc.id
        client_id = clientId
        name = doc.name
        category = doc.category.rawValue
        date_added = iso.string(from: doc.dateAdded)
        file_size = doc.fileSize
        is_new = doc.isNew
        file_url = doc.fileURL
        self.build_id = buildId ?? doc.buildId
        self.build_stage_id = buildStageId
        created_at = nil
    }

    func toClientDocument() -> ClientDocument {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        return ClientDocument(
            id: id,
            name: name,
            category: DocumentCategory(rawValue: category) ?? .contracts,
            dateAdded: formatter.date(from: date_added) ?? fallback.date(from: date_added) ?? .now,
            fileSize: file_size,
            isNew: is_new,
            fileURL: file_url,
            buildId: build_id,
            buildStageName: nil
        )
    }
}

nonisolated struct ScheduleItemRow: Codable, Sendable {
    let id: String
    let client_id: String
    let title: String
    let subtitle: String
    let icon: String
    let date: String
    let type: String

    init(from item: ScheduleItem, clientId: String) {
        let iso = ISO8601DateFormatter()
        id = item.id
        client_id = clientId
        title = item.title
        subtitle = item.subtitle
        icon = item.icon
        date = iso.string(from: item.date)
        type = item.type.rawValue
    }

    func toScheduleItem() -> ScheduleItem {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        return ScheduleItem(
            id: id,
            title: title,
            subtitle: subtitle,
            icon: icon,
            date: formatter.date(from: date) ?? fallback.date(from: date) ?? .now,
            type: ScheduleItem.ItemType(rawValue: type) ?? .meeting
        )
    }
}
