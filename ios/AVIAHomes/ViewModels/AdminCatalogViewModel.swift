import SwiftUI

@Observable
class AdminCatalogViewModel {
    var specItems: [SpecItemFlatRow] = []
    var colourCategories: [ColourCategory] = []
    var homeDesigns: [HomeDesign] = []
    var facades: [Facade] = []
    var blogPosts: [BlogPost] = []
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?

    private let catalog = CatalogDataManager.shared

    var specCategoryOrder: [(id: String, name: String, icon: String)] {
        [
            ("structure", "Structure & Ceiling", "building.2.fill"),
            ("exterior", "External Finishes", "house.fill"),
            ("windows_doors", "Windows & Doors", "door.left.hand.open"),
            ("kitchen", "Kitchen", "fork.knife"),
            ("bathroom", "Bathroom & Ensuite", "shower.fill"),
            ("flooring", "Flooring", "square.grid.3x3.fill"),
            ("internal", "Internal Finishes", "paintbrush.fill"),
            ("electrical", "Electrical & Lighting", "lightbulb.fill"),
            ("outdoor", "Outdoor & Landscaping", "leaf.fill"),
        ]
    }

    func categoryName(for id: String) -> String {
        specCategoryOrder.first { $0.id == id }?.name ?? id
    }

    var specItemsEmpty: Bool { specItems.isEmpty && !isLoading }
    var colourCategoriesEmpty: Bool { colourCategories.isEmpty && !isLoading }

    func loadSpecItems() async {
        isLoading = true
        specItems = await SupabaseService.shared.fetchSpecItemsFlat()
        isLoading = false
    }

    func loadColourCategories() async {
        isLoading = true
        colourCategories = await SupabaseService.shared.fetchColourCategories()
        isLoading = false
    }

    func loadHomeDesigns() async {
        isLoading = true
        homeDesigns = await SupabaseService.shared.fetchHomeDesigns()
        isLoading = false
    }

    func loadFacades() async {
        isLoading = true
        facades = await SupabaseService.shared.fetchFacades()
        isLoading = false
    }

    func loadBlogPosts() async {
        isLoading = true
        blogPosts = await SupabaseService.shared.fetchBlogPosts()
        isLoading = false
    }

    func saveBlogPost(_ post: BlogPost) async {
        errorMessage = nil
        let row = BlogPostRow(from: post)
        let success = await SupabaseService.shared.upsertBlogPost(row)
        if success {
            successMessage = "Article saved"
            await loadBlogPosts()
        } else {
            errorMessage = "Failed to save article"
        }
    }

    func deleteBlogPost(id: String) async {
        errorMessage = nil
        let success = await SupabaseService.shared.deleteBlogPost(id: id)
        if success {
            successMessage = "Article deleted"
            await loadBlogPosts()
        } else {
            errorMessage = "Failed to delete article"
        }
    }

    func saveFacade(_ facade: Facade) async {
        errorMessage = nil
        let row = FacadeRow(from: facade)
        let success = await SupabaseService.shared.upsertFacade(row)
        if success {
            successMessage = "Facade saved"
            await loadFacades()
        } else {
            errorMessage = "Failed to save facade"
        }
    }

    func deleteFacade(id: String) async {
        errorMessage = nil
        let success = await SupabaseService.shared.deleteFacade(id: id)
        if success {
            successMessage = "Facade deleted"
            await loadFacades()
        } else {
            errorMessage = "Failed to delete facade"
        }
    }

    func saveSpecItem(
        _ row: SpecItemFlatRow,
        tierImages: [String: String] = [:],
        linkedColourCategoryIds: [String]? = nil
    ) async {
        errorMessage = nil
        let success = await SupabaseService.shared.upsertSpecItem(row)
        guard success else {
            errorMessage = "Failed to save spec item"
            return
        }

        let hasAnyTierImage = !tierImages.isEmpty
        let existingRow = await SupabaseService.shared.fetchSpecItemImageRow(specItemId: row.id)
        if hasAnyTierImage || existingRow != nil {
            let mergedTierImages = tierImages.isEmpty ? nil : tierImages
            let imageRow = SpecItemImageRow(
                spec_item_id: row.id,
                base_image_url: row.image_url,
                tier_images: mergedTierImages ?? existingRow?.tier_images
            )
            let imgOk = await SupabaseService.shared.upsertSpecItemImageRow(imageRow)
            if !imgOk {
                errorMessage = "Spec item saved but tier images failed"
                await loadSpecItems()
                await catalog.loadAll()
                return
            }
        }

        if let linkedColourCategoryIds {
            let mappingOk = await SupabaseService.shared.upsertSpecToColourMapping(
                specItemId: row.id,
                colourCategoryIds: linkedColourCategoryIds
            )
            if !mappingOk {
                errorMessage = "Spec item saved but colour linkage failed"
                await loadSpecItems()
                await catalog.loadAll()
                return
            }
        }

        successMessage = "Spec item saved"
        await loadSpecItems()
        await catalog.loadAll()
    }

    func deleteSpecItem(id: String) async {
        errorMessage = nil
        let success = await SupabaseService.shared.deleteSpecItem(id: id)
        if success {
            successMessage = "Spec item deleted"
            await loadSpecItems()
            await catalog.loadAll()
        } else {
            errorMessage = "Failed to delete spec item"
        }
    }

    func saveColourCategory(_ category: ColourCategory, sortOrder: Int) async {
        errorMessage = nil
        let row = ColourCategoryUpsertRow(from: category, sortOrder: sortOrder)
        let success = await SupabaseService.shared.upsertColourCategory(row)
        if success {
            successMessage = "Colour category saved"
            await loadColourCategories()
            await catalog.loadAll()
        } else {
            errorMessage = "Failed to save colour category"
        }
    }

    func deleteColourCategory(id: String) async {
        errorMessage = nil
        let success = await SupabaseService.shared.deleteColourCategory(id: id)
        if success {
            successMessage = "Colour category deleted"
            await loadColourCategories()
            await catalog.loadAll()
        } else {
            errorMessage = "Failed to delete colour category"
        }
    }

    func saveHomeDesign(_ design: HomeDesign) async {
        errorMessage = nil
        let row = HomeDesignRow(from: design)
        let success = await SupabaseService.shared.upsertHomeDesign(row)
        if success {
            successMessage = "Home design saved"
            await loadHomeDesigns()
        } else {
            errorMessage = "Failed to save home design"
        }
    }

    func deleteHomeDesign(id: String) async {
        errorMessage = nil
        let success = await SupabaseService.shared.deleteHomeDesign(id: id)
        if success {
            successMessage = "Home design deleted"
            await loadHomeDesigns()
        } else {
            errorMessage = "Failed to delete home design"
        }
    }

    func seedSpecItemsFromDefaults() async {
        isLoading = true
        errorMessage = nil
        var count = 0
        for category in SpecCategory.seedCategories {
            for (index, item) in category.items.enumerated() {
                let row = SpecItemFlatRow(
                    id: item.id,
                    category_id: category.id,
                    name: item.name,
                    volos_description: item.volosDescription,
                    messina_description: item.messinaDescription,
                    portobello_description: item.portobelloDescription,
                    is_upgradeable: item.isUpgradeable,
                    image_url: SpecItem.seedBaseImageMapping[item.id],
                    sort_order: index
                )
                let ok = await SupabaseService.shared.upsertSpecItem(row)
                if ok { count += 1 }
            }
        }
        successMessage = "Seeded \(count) spec items to database"
        await loadSpecItems()
        await catalog.loadAll()
        isLoading = false
    }
}
