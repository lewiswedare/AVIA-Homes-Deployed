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
    /// Admin-defined product categories (Tile, Stone, Tapware…) keyed by id.
    var productCategories: [String: ProductCategoryRow] = [:]
    /// Variant × Room × Range × Facade × Slot assignments keyed by composite
    /// key (`variantId|roomId|rangeId|facadeId|slotId`). Drives the room-first
    /// client experience. Facade-agnostic rows use `-` as the facade segment.
    /// Multiple slots of the same (variant, room, range) coexist with
    /// different slot ids — see `selection_slot_id` on the schema.
    var variantRoomAssignments: [String: VariantRoomAssignmentRow] = [:]
    /// All raw assignments — used when iterating facade scopes for a given
    /// (variant, room, range).
    var allVariantAssignments: [VariantRoomAssignmentRow] = []
    /// Variant ids grouped by (roomId|rangeId) for fast room lookups
    /// (deduplicated across facade scopes).
    var variantsByRoomRange: [String: [String]] = [:]
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
        async let productCategoriesTask = SupabaseService.shared.fetchProductCategories()
        async let variantAssignmentsTask = SupabaseService.shared.fetchVariantRoomAssignments()

        let (colours, specs, flatItems, ranges, schemes, mapping, images, products, productColours, memberships) = await (
            coloursTask, specsTask, flatItemsTask, rangesTask, schemesTask, mappingTask, imagesTask,
            productsTask, productColoursTask, rangeMembershipsTask
        )
        let (prodCategories, variantAssignments) = await (productCategoriesTask, variantAssignmentsTask)

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

        var pcMap: [String: ProductCategoryRow] = [:]
        for c in prodCategories { pcMap[c.id] = c }
        productCategories = pcMap

        var vraMap: [String: VariantRoomAssignmentRow] = [:]
        var byRoomRange: [String: Set<String>] = [:]
        for a in variantAssignments {
            vraMap[a.compositeKey] = a
            byRoomRange["\(a.room_id)|\(a.range_id)", default: []].insert(a.variant_id)
        }
        variantRoomAssignments = vraMap
        allVariantAssignments = variantAssignments
        variantsByRoomRange = byRoomRange.mapValues { Array($0) }

        isLoaded = true
        warmImageCache()
        print("[CatalogDataManager] Loaded — colours: \(colours.count), specs: \(specs.count), flatItems: \(flatItems.count), ranges: \(ranges.count), schemes: \(schemes.count), mapping: \(mapping.count), products: \(products.count), productColours: \(productColours.count), memberships: \(memberships.count), productCategories: \(prodCategories.count), variantAssignments: \(variantAssignments.count)")
    }

    // MARK: - Image prefetching

    /// Push every URL we know about into `ImagePrefetcher` so the first scroll
    /// through Selections / Spec Ranges / Colours never shows a blank tile.
    private func warmImageCache() {
        var urls: [String?] = []
        urls.append(contentsOf: specItemBaseImages.values.map { Optional($0) })
        urls.append(contentsOf: specItemTierImages.values.map { Optional($0) })
        for c in colourCategories {
            urls.append(c.imageURL)
            urls.append(contentsOf: c.options.map { $0.imageURL })
        }
        for (_, row) in specRangeTiers {
            urls.append(row.hero_image_url)
        }
        for cols in coloursByProduct.values {
            urls.append(contentsOf: cols.map { $0.image_url })
        }
        urls.append(contentsOf: allVariantAssignments.map { $0.image_url })

        ImagePrefetcher.prefetch(urlStrings: urls)
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

    /// Returns the default product for a spec item in a range. Only returns
    /// products that are *included* in the range — never auto-selects an
    /// upgrade product, so clients always start at the standard price and
    /// have to opt in to upgrades.
    func defaultProductId(for specItemId: String, rangeId: String) -> String? {
        let candidates = products(for: specItemId, rangeId: rangeId)
        if let pickedDefault = candidates.first(where: { $0.membership.is_default == true && ($0.membership.inclusion_override == "included") }) {
            return pickedDefault.product.id
        }
        if let firstIncluded = candidates.first(where: { $0.membership.inclusion_override == "included" }) {
            return firstIncluded.product.id
        }
        return nil
    }

    /// Returns the default colour for a product, but only when it is included
    /// (no extra cost). Prevents a paid upgrade colour from being silently
    /// pre-selected on a new build.
    func defaultIncludedColourId(for productId: String) -> String? {
        let cols = productColours(for: productId)
        if let pickedDefault = cols.first(where: { $0.is_default == true && ($0.extra_cost ?? 0) == 0 }) {
            return pickedDefault.id
        }
        return cols.first(where: { ($0.extra_cost ?? 0) == 0 })?.id
    }

    func defaultColourId(for productId: String) -> String? {
        let cols = productColours(for: productId)
        return cols.first(where: { $0.is_default == true })?.id ?? cols.first?.id
    }

    // MARK: - Room-first helpers

    /// All product categories ordered by sort_order.
    var allProductCategories: [ProductCategoryRow] {
        productCategories.values.sorted { $0.sort_order < $1.sort_order }
    }

    /// Returns *an* assignment for a specific (variant, room, range, facade).
    /// With slots, there may be multiple rows; this helper returns the first
    /// one found (preferring facade-specific over facade-agnostic). Callers
    /// that care about a specific slot should use `assignment(slotId:rangeId:)`
    /// or `assignments(variantId:roomId:rangeId:facadeId:)` instead.
    func assignment(variantId: String, roomId: String, rangeId: String, facadeId: String? = nil) -> VariantRoomAssignmentRow? {
        let matches = allVariantAssignments.filter {
            $0.variant_id == variantId && $0.room_id == roomId && $0.range_id == rangeId
        }
        if let fid = facadeId,
           let specific = matches.first(where: { $0.facade_id == fid }) {
            return specific
        }
        return matches.first(where: { $0.facade_id == nil })
    }

    /// All assignments matching `(variant, room, range)` with the given
    /// facade scope. Used when iterating per-slot rows for the same variant.
    func assignments(variantId: String, roomId: String, rangeId: String, facadeId: String? = nil) -> [VariantRoomAssignmentRow] {
        allVariantAssignments.filter { a in
            guard a.variant_id == variantId, a.room_id == roomId, a.range_id == rangeId else { return false }
            if let aFid = a.facade_id { return aFid == facadeId }
            return true
        }
    }

    /// Returns the assignment row matching the given slot id for the given
    /// range — each slot has exactly one row per range.
    func assignment(slotId: String, rangeId: String) -> VariantRoomAssignmentRow? {
        allVariantAssignments.first { $0.selection_slot_id == slotId && $0.range_id == rangeId }
    }

    /// Distinct slot ids for an item in a room, scoped to `(range, facade)`.
    /// Used to materialise per-slot client selections when a build snapshot
    /// is created, and to filter slots on the admin Room editor.
    func slotIds(forSpecItem specItemId: String, roomId: String, rangeId: String, facadeId: String? = nil) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        let matching = allVariantAssignments
            .filter { a in
                guard a.room_id == roomId, a.range_id == rangeId else { return false }
                guard self.specItemId(forVariantId: a.variant_id) == specItemId else { return false }
                if let aFid = a.facade_id { return aFid == facadeId }
                return true
            }
            .sorted { ($0.sort_order ?? 0) < ($1.sort_order ?? 0) }
        for a in matching {
            guard let slot = a.selection_slot_id else { continue }
            if seen.insert(slot).inserted { ordered.append(slot) }
        }
        return ordered
    }

    /// Distinct slot ids assigned to a room across any range / facade. Used
    /// by the admin Room editor where ranges are presented side-by-side.
    func slotIds(forRoom roomId: String) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        let rows = allVariantAssignments
            .filter { $0.room_id == roomId && $0.facade_id == nil }
            .sorted { ($0.sort_order ?? 0) < ($1.sort_order ?? 0) }
        for a in rows {
            guard let slot = a.selection_slot_id else { continue }
            if seen.insert(slot).inserted { ordered.append(slot) }
        }
        return ordered
    }

    /// All assignment rows (any range) that share the given slot id.
    func rows(forSlot slotId: String) -> [VariantRoomAssignmentRow] {
        allVariantAssignments.filter { $0.selection_slot_id == slotId }
    }

    /// Every variant assigned to a given room+range, in sort_order. Used by the
    /// room-first client experience.
    ///
    /// When `facadeId` is provided, scopes the list to variants that either
    /// have a facade-agnostic assignment OR a facade-specific assignment
    /// matching `facadeId`. Variants whose only assignments are scoped to a
    /// *different* facade are excluded so the client only sees what's
    /// available for their build.
    func variantIds(forRoom roomId: String, rangeId: String, facadeId: String? = nil) -> [String] {
        let ids = variantsByRoomRange["\(roomId)|\(rangeId)"] ?? []
        let filtered = ids.filter { vid in
            isVariantAvailable(variantId: vid, roomId: roomId, rangeId: rangeId, facadeId: facadeId)
        }
        return filtered.sorted { lhs, rhs in
            let a = assignment(variantId: lhs, roomId: roomId, rangeId: rangeId, facadeId: facadeId)?.sort_order ?? 0
            let b = assignment(variantId: rhs, roomId: roomId, rangeId: rangeId, facadeId: facadeId)?.sort_order ?? 0
            return a < b
        }
    }

    /// Whether a variant is available in `(room, range)` for the given
    /// facade context. A variant is available when it has either a
    /// facade-agnostic assignment OR a facade-specific assignment matching
    /// `facadeId`. If `facadeId` is nil, the variant is available as long as
    /// it has *any* assignment for that room+range.
    func isVariantAvailable(variantId: String, roomId: String, rangeId: String, facadeId: String?) -> Bool {
        let hasAgnostic = variantRoomAssignments["\(variantId)|\(roomId)|\(rangeId)|-"] != nil
        guard let fid = facadeId else {
            // No facade context — include any variant with an assignment.
            if hasAgnostic { return true }
            return allVariantAssignments.contains { $0.variant_id == variantId && $0.room_id == roomId && $0.range_id == rangeId }
        }
        if hasAgnostic { return true }
        return variantRoomAssignments["\(variantId)|\(roomId)|\(rangeId)|\(fid)"] != nil
    }

    /// Cheapest upgrade-variant cost for a given spec item in a specific room
    /// + range. Returns `nil` when the item has no upgrade variant assigned to
    /// that room in that range. Used by client-facing tier-upgrade flows to
    /// price items off `variant_room_assignments` instead of the legacy
    /// per-tier cost columns on `spec_items`.
    func cheapestUpgradeCost(forSpecItem specItemId: String, roomId: String, rangeId: String, facadeId: String? = nil) -> Double? {
        let costs: [Double] = variantIds(forRoom: roomId, rangeId: rangeId, facadeId: facadeId)
            .compactMap { vid -> Double? in
                guard self.specItemId(forVariantId: vid) == specItemId else { return nil }
                guard let a = assignment(variantId: vid, roomId: roomId, rangeId: rangeId, facadeId: facadeId),
                      a.inclusionValue == .upgrade else { return nil }
                return a.cost
            }
        return costs.min()
    }

    /// Room-agnostic fallback for tier-upgrade flows that don't yet know which
    /// room an item belongs to (e.g. whole-range bulk upgrade). Scans every
    /// room assignment for the item in `rangeId` and returns the cheapest
    /// upgrade cost, or `nil` when none exists.
    func cheapestUpgradeCost(forSpecItem specItemId: String, rangeId: String) -> Double? {
        var best: Double?
        for (_, a) in variantRoomAssignments where a.range_id == rangeId && a.inclusionValue == .upgrade {
            guard self.specItemId(forVariantId: a.variant_id) == specItemId else { continue }
            if best == nil || a.cost < best! { best = a.cost }
        }
        return best
    }

    /// All room ids the given spec item has at least one variant assigned to,
    /// scoped to `rangeId` and (optionally) `facadeId`. Drives room-first
    /// client navigation — an item appears in every room it's been assigned
    /// to, regardless of its legacy `spec_items.category_id`.
    func roomIds(forSpecItem specItemId: String, rangeId: String, facadeId: String? = nil) -> Set<String> {
        var result: Set<String> = []
        for a in allVariantAssignments where a.range_id == rangeId {
            guard self.specItemId(forVariantId: a.variant_id) == specItemId else { continue }
            // Respect facade scope: facade-agnostic rows always apply; facade-
            // specific rows only apply when matching the build's facade.
            if let fid = a.facade_id, fid != facadeId { continue }
            result.insert(a.room_id)
        }
        return result
    }

    /// Whether the spec item has ANY variant_room_assignments at all (any
    /// range/facade). Used to decide between new room-first routing and the
    /// legacy snapshot-category fallback for items that haven't been
    /// reassigned yet.
    func hasAnyRoomAssignment(forSpecItem specItemId: String) -> Bool {
        for a in allVariantAssignments {
            if self.specItemId(forVariantId: a.variant_id) == specItemId { return true }
        }
        return false
    }

    /// Per-room display title override for a spec item. When a `slotId` is
    /// supplied the title is sourced from that specific slot first (each
    /// slot in a room can have its own title — "Floor Tiles" vs "Wall
    /// Tiles"). Falls back to the saved variant’s row, then any matching
    /// row in `(room, range, facade)`. Returns `nil` when no override is set.
    func displayTitle(forSpecItem specItemId: String, roomId: String, rangeId: String, facadeId: String? = nil, preferredVariantId: String? = nil, slotId: String? = nil) -> String? {
        // 1. Specific slot row for this range.
        if let slot = slotId, let a = assignment(slotId: slot, rangeId: rangeId),
           let t = a.display_title, !t.isEmpty {
            return t
        }
        // 1b. Specific slot in any range (titles are shared across the 3 ranges).
        if let slot = slotId,
           let t = allVariantAssignments.first(where: { $0.selection_slot_id == slot && ($0.display_title?.isEmpty == false) })?.display_title {
            return t
        }
        // 2. Saved variant in this exact (room, range, facade).
        if let vid = preferredVariantId,
           let a = assignment(variantId: vid, roomId: roomId, rangeId: rangeId, facadeId: facadeId),
           let t = a.display_title, !t.isEmpty {
            return t
        }
        // 3. Any variant of this item in this (room, range) with the right facade scope.
        for a in allVariantAssignments where a.room_id == roomId && a.range_id == rangeId {
            if let fid = a.facade_id, fid != facadeId { continue }
            guard self.specItemId(forVariantId: a.variant_id) == specItemId else { continue }
            if let t = a.display_title, !t.isEmpty { return t }
        }
        // 4. Any variant of this item in this room (any range, matching facade scope).
        for a in allVariantAssignments where a.room_id == roomId {
            if let fid = a.facade_id, fid != facadeId { continue }
            guard self.specItemId(forVariantId: a.variant_id) == specItemId else { continue }
            if let t = a.display_title, !t.isEmpty { return t }
        }
        return nil
    }

    /// Returns the parent spec item id for a variant (via spec_products).
    func specItemId(forVariantId variantId: String) -> String? {
        guard let colour = coloursByProduct.values.flatMap({ $0 }).first(where: { $0.id == variantId }) else {
            return nil
        }
        return specProducts[colour.product_id]?.spec_item_id
    }
}
