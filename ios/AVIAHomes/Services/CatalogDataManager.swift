import Foundation

@Observable
class CatalogDataManager {
    static let shared = CatalogDataManager()

    var colourCategories: [ColourCategory] = []
    var specCategories: [SpecCategory] = []
    var specRangeTiers: [String: SpecRangeTierRow] = [:]
    var homeFastSchemes: [HomeFastScheme] = []
    var specToColourMapping: [String: [String]] = [:]
    var specItemBaseImages: [String: String] = [:]
    var specItemTierImages: [String: String] = [:]
    var isLoaded: Bool = false

    private init() {}

    var exteriorCategories: [ColourCategory] {
        colourCategories.filter { $0.section == .exterior }
    }

    var interiorCategories: [ColourCategory] {
        colourCategories.filter { $0.section == .interior }
    }

    var allColourCategories: [ColourCategory] {
        colourCategories
    }

    var allSpecCategories: [SpecCategory] {
        specCategories
    }

    var allSchemes: [HomeFastScheme] {
        homeFastSchemes
    }

    var activeSpecToColourMapping: [String: [String]] {
        specToColourMapping
    }

    func specRangeData(for tier: SpecTier) -> SpecRangeData {
        if let row = specRangeTiers[tier.imageKeySuffix] {
            return row.toSpecRangeData()
        }
        return SpecRangeData.empty
    }

    func specRangeRoomImages(for tier: SpecTier) -> [(name: String, imageURL: String)] {
        if let row = specRangeTiers[tier.imageKeySuffix] {
            return row.toRoomImages()
        }
        return []
    }

    func baseImageURL(for specItemId: String) -> URL? {
        if let urlString = specItemBaseImages[specItemId] {
            return URL(string: urlString)
        }
        return nil
    }

    func tierImageURL(for specItemId: String, tier: SpecTier) -> URL? {
        let key = "\(specItemId)_\(tier.imageKeySuffix)"
        if let urlString = specItemTierImages[key] {
            return URL(string: urlString)
        }
        return nil
    }

    func availableColourCategoryIds(for tier: SpecTier) -> Set<String> {
        let mapping = activeSpecToColourMapping
        var ids = Set<String>()
        for category in allSpecCategories {
            for item in category.items {
                if let colourIds = mapping[item.id] {
                    for colourId in colourIds {
                        ids.insert(colourId)
                    }
                }
            }
        }
        return ids
    }

    func filteredExteriorCategories(for tier: SpecTier) -> [ColourCategory] {
        let available = availableColourCategoryIds(for: tier)
        return filterCategoriesWithTierOptions(exteriorCategories.filter { available.contains($0.id) }, tier: tier)
    }

    func filteredInteriorCategories(for tier: SpecTier) -> [ColourCategory] {
        let available = availableColourCategoryIds(for: tier)
        return filterCategoriesWithTierOptions(interiorCategories.filter { available.contains($0.id) }, tier: tier)
    }

    func filteredAllCategories(for tier: SpecTier) -> [ColourCategory] {
        filteredExteriorCategories(for: tier) + filteredInteriorCategories(for: tier)
    }

    private func filterCategoriesWithTierOptions(_ categories: [ColourCategory], tier: SpecTier) -> [ColourCategory] {
        categories.compactMap { category in
            let visibleOptions = category.options.filter { option in
                option.availableTiers.isEmpty || option.isAvailable(for: tier) || option.isUpgradeOption(for: tier)
            }
            guard !visibleOptions.isEmpty else { return nil }
            return ColourCategory(
                id: category.id,
                name: category.name,
                icon: category.icon,
                section: category.section,
                options: visibleOptions,
                note: category.note,
                imageURL: category.imageURL,
                defaultOptionCost: category.defaultOptionCost
            )
        }
    }

    func loadAll() async {
        async let coloursTask = SupabaseService.shared.fetchColourCategories()
        async let specsTask = SupabaseService.shared.fetchSpecCategories()
        async let flatItemsTask = SupabaseService.shared.fetchSpecItemsFlat()
        async let rangesTask = SupabaseService.shared.fetchSpecRangeTiers()
        async let schemesTask = SupabaseService.shared.fetchHomeFastSchemes()
        async let mappingTask = SupabaseService.shared.fetchSpecToColourMapping()
        async let imagesTask = SupabaseService.shared.fetchSpecItemImages()

        let (colours, specs, flatItems, ranges, schemes, mapping, images) = await (
            coloursTask, specsTask, flatItemsTask, rangesTask, schemesTask, mappingTask, imagesTask
        )

        colourCategories = colours
        specCategories = specs
        specRangeTiers = ranges
        homeFastSchemes = schemes
        specToColourMapping = mapping

        var mergedBaseImages = images.base
        for item in flatItems {
            if let url = item.image_url, !url.isEmpty {
                mergedBaseImages[item.id] = url
            }
        }
        specItemBaseImages = mergedBaseImages
        specItemTierImages = images.tier

        isLoaded = true
        print("[CatalogDataManager] Loaded — colours: \(colours.count), specs: \(specs.count), flatItems: \(flatItems.count), ranges: \(ranges.count), schemes: \(schemes.count), mapping: \(mapping.count)")
    }
}
