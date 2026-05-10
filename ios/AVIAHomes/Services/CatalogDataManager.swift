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
    /// All spec products keyed by product id.
    var specProducts: [String: SpecProductRow] = [:]
    /// Product ids grouped by spec item id (sorted by sort_order).
    var productsBySpecItem: [String: [String]] = [:]
    /// Range memberships keyed by (range_id, product_id).
    var rangeProductMemberships: [String: SpecRangeItemProductRow] = [:]
    /// Colour rows keyed by product id (sorted by sort_order).
    var coloursByProduct: [String: [SpecProductColourRow]] = [:]
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

    /// Returns every colour category that is linked (via spec_to_colour_mapping)
    /// to any spec item. Spec items themselves are not tier-gated — tier is
    /// expressed via per-tier description/cost, not availability — so the tier
    /// parameter is retained for future use but currently informational.
    ///
    /// Stage-2 colour filtering is build-aware and uses
    /// `colourCategoryIds(forApprovedSpecItems:)` instead.
    func availableColourCategoryIds(for tier: SpecTier) -> Set<String> {
        let mapping = activeSpecToColourMapping
        var ids = Set<String>()
        for category in allSpecCategories {
            for item in category.items {
                if let colourIds = mapping[item.id] {
                    ids.formUnion(colourIds)
                }
            }
        }
        return ids
    }

    /// Stage-2 filtering: given a set of spec item IDs that have been approved
    /// for a specific build, return the colour categories that should be offered
    /// for colour selection. This is the build-aware version of
    /// `availableColourCategoryIds(for:)` and is what `BuildColourSelectionViewModel`
    /// uses to enforce "only pick colours for items you've already locked in".
    func colourCategoryIds(forApprovedSpecItems approvedIds: Set<String>) -> Set<String> {
        let mapping = activeSpecToColourMapping
        var ids = Set<String>()
        for itemId in approvedIds {
            if let colourIds = mapping[itemId] {
                ids.formUnion(colourIds)
            }
        }
        return ids
    }

    func filteredExteriorCategories(for tier: SpecTier) -> [ColourCategory] {
        let available = availableColourCategoryIds(for: tier)
        let tierFiltered = exteriorCategories.filter { $0.isAvailable(for: tier) && available.contains($0.id) }
        return filterCategoriesWithTierOptions(tierFiltered, tier: tier)
    }

    func filteredInteriorCategories(for tier: SpecTier) -> [ColourCategory] {
        let available = availableColourCategoryIds(for: tier)
        let tierFiltered = interiorCategories.filter { $0.isAvailable(for: tier) && available.contains($0.id) }
        return filterCategoriesWithTierOptions(tierFiltered, tier: tier)
    }

    func filteredAllCategories(for tier: SpecTier) -> [ColourCategory] {
        filteredExteriorCategories(for: tier) + filteredInteriorCategories(for: tier)
    }

    func categoriesForTier(_ tier: SpecTier) -> [ColourCategory] {
        colourCategories.filter { $0.isAvailable(for: tier) }.compactMap { category in
            let visibleOptions = filterOptionsForTier(category.options, tier: tier)
            guard !visibleOptions.isEmpty else { return nil }
            return ColourCategory(
                id: category.id,
                name: category.name,
                icon: category.icon,
                section: category.section,
                options: visibleOptions,
                note: category.note,
                imageURL: category.imageURL,
                defaultOptionCost: category.defaultOptionCost,
                applicableTiers: category.applicableTiers,
                specItemId: category.specItemId
            )
        }
    }

    func specItem(for specItemId: String) -> SpecItem? {
        for category in specCategories {
            if let item = category.items.first(where: { $0.id == specItemId }) {
                return item
            }
        }
        return nil
    }

    private func filterOptionsForTier(_ options: [ColourOption], tier: SpecTier) -> [ColourOption] {
        options.filter { option in
            let tierOk = option.applicableTiers == nil || option.applicableTiers!.isEmpty || option.applicableTiers!.contains(tier.rawValue)
            let availOk = option.availableTiers.isEmpty || option.isAvailable(for: tier) || option.isUpgradeOption(for: tier)
            return tierOk && availOk
        }
    }

    private func filterCategoriesWithTierOptions(_ categories: [ColourCategory], tier: SpecTier) -> [ColourCategory] {
        categories.compactMap { category in
            let visibleOptions = filterOptionsForTier(category.options, tier: tier)
            guard !visibleOptions.isEmpty else { return nil }
            return ColourCategory(
                id: category.id,
                name: category.name,
                icon: category.icon,
                section: category.section,
                options: visibleOptions,
                note: category.note,
                imageURL: category.imageURL,
                defaultOptionCost: category.defaultOptionCost,
                applicableTiers: category.applicableTiers,
                specItemId: category.specItemId
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
        async let productsTask = SupabaseService.shared.fetchAllSpecProducts()
        async let productColoursTask = SupabaseService.shared.fetchAllSpecProductColours()
        async let rangeMembershipsTask = SupabaseService.shared.fetchAllRangeItemProducts()

        let (colours, specs, flatItems, ranges, schemes, mapping, images, products, productColours, memberships) = await (
            coloursTask, specsTask, flatItemsTask, rangesTask, schemesTask, mappingTask, imagesTask,
            productsTask, productColoursTask, rangeMembershipsTask
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

        var byProduct: [String: SpecProductRow] = [:]
        var byItem: [String: [String]] = [:]
        for p in products {
            byProduct[p.id] = p
            byItem[p.spec_item_id, default: []].append(p.id)
        }
        for key in byItem.keys {
            byItem[key]?.sort { (byProduct[$0]?.sort_order ?? 0) < (byProduct[$1]?.sort_order ?? 0) }
        }
        specProducts = byProduct
        productsBySpecItem = byItem

        var coloursMap: [String: [SpecProductColourRow]] = [:]
        for c in productColours {
            coloursMap[c.product_id, default: []].append(c)
        }
        for key in coloursMap.keys {
            coloursMap[key]?.sort { ($0.sort_order ?? 0) < ($1.sort_order ?? 0) }
        }
        coloursByProduct = coloursMap

        var memMap: [String: SpecRangeItemProductRow] = [:]
        for m in memberships {
            memMap["\(m.range_id)|\(m.product_id)"] = m
        }
        rangeProductMemberships = memMap

        isLoaded = true
        print("[CatalogDataManager] Loaded — colours: \(colours.count), specs: \(specs.count), flatItems: \(flatItems.count), ranges: \(ranges.count), schemes: \(schemes.count), mapping: \(mapping.count), products: \(products.count), productColours: \(productColours.count), memberships: \(memberships.count)")
    }

    // MARK: - Product helpers

    /// Returns products available for a spec item in a given range. Filters out
    /// memberships marked Unavailable in the current range, but ALSO surfaces
    /// products that are Included or Upgrade in any higher-tier range — the
    /// client can always pay more to upgrade, but never sees options that are
    /// only available in cheaper ranges. Each tuple is (product, membership).
    func products(for specItemId: String, rangeId: String) -> [(product: SpecProductRow, membership: SpecRangeItemProductRow)] {
        let ids = productsBySpecItem[specItemId] ?? []
        let currentTier = SpecTier(rawValue: rangeId.lowercased())
        // Tiers strictly higher than the client's range, ordered cheapest -> most expensive.
        let higherTiers: [SpecTier] = {
            guard let cur = currentTier else { return [] }
            return SpecTier.allCases
                .filter { $0.tierIndex > cur.tierIndex }
                .sorted { $0.tierIndex < $1.tierIndex }
        }()

        return ids.compactMap { pid -> (SpecProductRow, SpecRangeItemProductRow)? in
            guard let p = specProducts[pid] else { return nil }

            // 1) Prefer the membership in the client's current range.
            if let m = rangeProductMemberships["\(rangeId)|\(pid)"] {
                let inclusion = ProductRangeInclusion(rawValue: m.inclusion_override ?? "unavailable") ?? .unavailable
                if inclusion != .unavailable {
                    return (p, m)
                }
            }

            // 2) Otherwise, surface from the lowest higher tier where the
            //    product is Included or Upgrade — exposed to the client as an
            //    upgrade option from that range.
            for tier in higherTiers {
                guard let m = rangeProductMemberships["\(tier.rawValue)|\(pid)"] else { continue }
                let inclusion = ProductRangeInclusion(rawValue: m.inclusion_override ?? "unavailable") ?? .unavailable
                guard inclusion != .unavailable else { continue }
                let synthetic = SpecRangeItemProductRow(
                    id: m.id,
                    range_id: rangeId,
                    spec_item_id: m.spec_item_id,
                    product_id: m.product_id,
                    is_default: false,
                    inclusion_override: ProductRangeInclusion.upgrade.rawValue,
                    upgrade_price_override: m.upgrade_price_override,
                    sort_order: m.sort_order
                )
                return (p, synthetic)
            }

            return nil
        }
    }

    func productColours(for productId: String) -> [SpecProductColourRow] {
        coloursByProduct[productId] ?? []
    }

    func defaultProductId(for specItemId: String, rangeId: String) -> String? {
        let candidates = products(for: specItemId, rangeId: rangeId)
        if let pickedDefault = candidates.first(where: { $0.membership.is_default == true && ($0.membership.inclusion_override == "included") }) {
            return pickedDefault.product.id
        }
        if let firstIncluded = candidates.first(where: { $0.membership.inclusion_override == "included" }) {
            return firstIncluded.product.id
        }
        return candidates.first?.product.id
    }

    func defaultColourId(for productId: String) -> String? {
        let cols = productColours(for: productId)
        return cols.first(where: { $0.is_default == true })?.id ?? cols.first?.id
    }
}
