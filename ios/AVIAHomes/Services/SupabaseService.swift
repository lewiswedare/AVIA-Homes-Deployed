import Foundation
import Supabase

@Observable
class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private static var supabaseURL: String {
        Config.EXPO_PUBLIC_SUPABASE_URL
    }

    private static var supabaseKey: String {
        Config.EXPO_PUBLIC_SUPABASE_ANON_KEY
    }

    private init() {
        let url = Self.supabaseURL.isEmpty ? "https://placeholder.supabase.co" : Self.supabaseURL
        let key = Self.supabaseKey.isEmpty ? "placeholder-key" : Self.supabaseKey

        client = SupabaseClient(
            supabaseURL: URL(string: url)!,
            supabaseKey: key
        )
    }

    var isConfigured: Bool {
        !Self.supabaseURL.isEmpty && !Self.supabaseKey.isEmpty
    }

    func fetchProfile(userId: String) async -> ClientUser? {
        guard isConfigured else {
            print("[SupabaseService] fetchProfile: not configured")
            return nil
        }
        let normalizedId = userId.lowercased()
        do {
            let row: ProfileRow = try await client
                .from("profiles")
                .select()
                .eq("id", value: normalizedId)
                .single()
                .execute()
                .value
            print("[SupabaseService] fetchProfile SUCCESS for id=\(normalizedId), profileCompleted=\(row.profile_completed), role=\(row.role)")
            return row.toClientUser()
        } catch {
            print("[SupabaseService] fetchProfile FAILED for id=\(normalizedId) — error: \(error)")
            return nil
        }
    }

    @discardableResult
    func upsertProfile(_ user: ClientUser) async -> Bool {
        guard isConfigured else {
            print("[SupabaseService] upsertProfile: not configured")
            return false
        }
        guard !user.id.isEmpty else {
            print("[SupabaseService] upsertProfile: user.id is empty — aborting")
            return false
        }
        var normalizedUser = user
        normalizedUser.id = user.id.lowercased()
        let row = ProfileUpsertRow(from: normalizedUser)
        print("[SupabaseService] upsertProfile attempting for id=\(normalizedUser.id), email=\(normalizedUser.email), name=\(normalizedUser.firstName) \(normalizedUser.lastName), phone=\(normalizedUser.phone), address=\(normalizedUser.address)")
        do {
            try await client
                .from("profiles")
                .upsert(row)
                .execute()
            print("[SupabaseService] upsertProfile SUCCESS for id=\(normalizedUser.id)")
            return true
        } catch {
            print("[SupabaseService] upsertProfile FAILED for id=\(normalizedUser.id) — error: \(error.localizedDescription) — full: \(error)")
            return false
        }
    }

    @discardableResult
    func updateProfileFields(userId: String, firstName: String, lastName: String, phone: String, address: String, email: String, role: String = "Client") async -> Bool {
        guard isConfigured else {
            print("[SupabaseService] updateProfileFields: not configured")
            return false
        }
        let normalizedId = userId.lowercased()
        let payload = ProfileUpdatePayload(
            first_name: firstName,
            last_name: lastName,
            phone: phone,
            address: address,
            email: email,
            role: role,
            profile_completed: true
        )
        print("[SupabaseService] updateProfileFields attempting for id=\(normalizedId), name=\(firstName) \(lastName), phone=\(phone), address=\(address), email=\(email)")
        do {
            try await client
                .from("profiles")
                .update(payload)
                .eq("id", value: normalizedId)
                .execute()
            print("[SupabaseService] updateProfileFields SUCCESS for id=\(normalizedId)")
            return true
        } catch {
            print("[SupabaseService] updateProfileFields FAILED for id=\(normalizedId) — error: \(error.localizedDescription) — full: \(error)")
            return false
        }
    }

    func fetchAllProfiles() async -> [ClientUser] {
        guard isConfigured else { return [] }
        do {
            let rows: [ProfileRow] = try await client
                .from("profiles")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            return rows.map { $0.toClientUser() }
        } catch {
            return []
        }
    }

    func updateProfileField(userId: String, fields: [String: String]) async {
        guard isConfigured else { return }
        do {
            try await client
                .from("profiles")
                .update(fields)
                .eq("id", value: userId)
                .execute()
        } catch {
            print("[SupabaseService] updateProfileField FAILED for user: \(userId) — \(error)")
        }
    }

    // MARK: - Builds

    func fetchBuilds() async -> [ClientBuild] {
        guard isConfigured else { return [] }
        do {
            let buildRows: [BuildRow] = try await client
                .from("builds")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            var builds: [ClientBuild] = []
            for row in buildRows {
                let stages = await fetchBuildStages(buildId: row.id)
                let clientUser = await fetchProfile(userId: row.client_id) ?? .empty
                var additionalClients: [ClientUser] = []
                for additionalId in (row.additional_client_ids ?? []) where !additionalId.isEmpty {
                    if let user = await fetchProfile(userId: additionalId) {
                        additionalClients.append(user)
                    }
                }
                builds.append(row.toClientBuild(client: clientUser, stages: stages, additionalClients: additionalClients))
            }
            return builds
        } catch {
            return []
        }
    }

    func fetchBuildStages(buildId: String) async -> [BuildStage] {
        guard isConfigured else { return [] }
        do {
            let rows: [BuildStageRow] = try await client
                .from("build_stages")
                .select()
                .eq("build_id", value: buildId)
                .order("sort_order", ascending: true)
                .execute()
                .value
            return rows.map { $0.toBuildStage() }
        } catch {
            return []
        }
    }

    @discardableResult
    func upsertBuild(_ build: ClientBuild) async -> Bool {
        guard isConfigured else {
            print("[SupabaseService] upsertBuild: not configured")
            return false
        }
        let row = BuildRow(from: build)
        do {
            try await client
                .from("builds")
                .upsert(row)
                .execute()
            print("[SupabaseService] upsertBuild SUCCESS for id=\(build.id), client=\(build.client.id)")
        } catch {
            print("[SupabaseService] upsertBuild FAILED for id=\(build.id) — error: \(error)")
            return false
        }
        for (index, stage) in build.buildStages.enumerated() {
            let stageRow = BuildStageRow(from: stage, buildId: build.id, sortOrder: index)
            do {
                try await client
                    .from("build_stages")
                    .upsert(stageRow)
                    .execute()
            } catch {
                print("[SupabaseService] upsertBuildStage FAILED for stage=\(stage.id) — error: \(error)")
            }
        }
        return true
    }

    func deleteBuild(buildId: String) async {
        guard isConfigured else { return }
        _ = try? await client
            .from("build_stages")
            .delete()
            .eq("build_id", value: buildId)
            .execute()
        _ = try? await client
            .from("build_spec_selections")
            .delete()
            .eq("build_id", value: buildId)
            .execute()
        _ = try? await client
            .from("build_colour_selections")
            .delete()
            .eq("build_id", value: buildId)
            .execute()
        _ = try? await client
            .from("builds")
            .delete()
            .eq("id", value: buildId)
            .execute()
    }

    func removeClientFromBuild(buildId: String, clientId: String, newPrimaryId: String?, newAdditionalIds: [String]) async -> Bool {
        guard isConfigured else { return false }
        do {
            let patch: BuildClientPatch
            if newPrimaryId == nil || newPrimaryId!.isEmpty {
                patch = BuildClientPatch(client_id: "", additional_client_ids: [])
            } else {
                patch = BuildClientPatch(client_id: newPrimaryId!, additional_client_ids: newAdditionalIds)
            }
            try await client
                .from("builds")
                .update(patch)
                .eq("id", value: buildId)
                .execute()
            print("[SupabaseService] removeClientFromBuild SUCCESS for buildId=\(buildId), removed=\(clientId)")
            return true
        } catch {
            print("[SupabaseService] removeClientFromBuild FAILED: \(error)")
            return false
        }
    }

    func updateBuildStage(_ stage: BuildStage, buildId: String, sortOrder: Int) async {
        guard isConfigured else { return }
        let row = BuildStageRow(from: stage, buildId: buildId, sortOrder: sortOrder)
        _ = try? await client
            .from("build_stages")
            .upsert(row)
            .execute()
    }

    // MARK: - Package Assignments

    func fetchPackageAssignments() async -> [PackageAssignment] {
        guard isConfigured else { return [] }
        do {
            let rows: [PackageAssignmentRow] = try await client
                .from("package_assignments")
                .select()
                .execute()
                .value
            return rows.map { $0.toPackageAssignment() }
        } catch {
            return []
        }
    }

    @discardableResult
    func upsertPackageAssignment(_ assignment: PackageAssignment) async -> Bool {
        guard isConfigured else {
            print("[SupabaseService] upsertPackageAssignment: not configured")
            return false
        }
        let row = PackageAssignmentRow(from: assignment)
        do {
            try await client
                .from("package_assignments")
                .upsert(row)
                .execute()
            print("[SupabaseService] upsertPackageAssignment SUCCESS for pkg=\(assignment.packageId)")
            return true
        } catch {
            print("[SupabaseService] upsertPackageAssignment FAILED for pkg=\(assignment.packageId) — error: \(error)")
            return false
        }
    }

    // MARK: - Service Requests

    func fetchServiceRequests(clientId: String? = nil) async -> [ServiceRequest] {
        guard isConfigured else { return [] }
        do {
            let rows: [ServiceRequestRow]
            if let clientId {
                rows = try await client
                    .from("service_requests")
                    .select()
                    .eq("client_id", value: clientId)
                    .order("date_created", ascending: false)
                    .execute()
                    .value
            } else {
                rows = try await client
                    .from("service_requests")
                    .select()
                    .order("date_created", ascending: false)
                    .execute()
                    .value
            }
            return rows.map { $0.toServiceRequest() }
        } catch {
            return []
        }
    }

    @discardableResult
    func upsertServiceRequest(_ request: ServiceRequest, clientId: String) async -> Bool {
        guard isConfigured else {
            print("[SupabaseService] upsertServiceRequest: not configured")
            return false
        }
        let row = ServiceRequestRow(from: request, clientId: clientId)
        do {
            try await client
                .from("service_requests")
                .upsert(row)
                .execute()
            print("[SupabaseService] upsertServiceRequest SUCCESS for id=\(request.id)")
            return true
        } catch {
            print("[SupabaseService] upsertServiceRequest FAILED for id=\(request.id) — error: \(error)")
            return false
        }
    }

    // MARK: - Content Data (Home Designs, Packages, Blog Posts, Estates, Facades)

    func fetchHomeDesigns() async -> [HomeDesign] {
        guard isConfigured else { return [] }
        do {
            let rows: [HomeDesignRow] = try await client
                .from("home_designs")
                .select()
                .order("name", ascending: true)
                .execute()
                .value
            return rows.map { $0.toHomeDesign() }
        } catch {
            print("[SupabaseService] fetchHomeDesigns FAILED: \(error)")
            return []
        }
    }

    func fetchHouseLandPackages() async -> [HouseLandPackage] {
        guard isConfigured else { return [] }
        do {
            let rows: [HouseLandPackageRow] = try await client
                .from("house_land_packages")
                .select()
                .order("id", ascending: true)
                .execute()
                .value
            return rows.map { $0.toHouseLandPackage() }
        } catch {
            print("[SupabaseService] fetchHouseLandPackages FAILED: \(error)")
            return []
        }
    }

    func fetchBlogPosts() async -> [BlogPost] {
        guard isConfigured else { return [] }
        do {
            let rows: [BlogPostRow] = try await client
                .from("blog_posts")
                .select()
                .order("date", ascending: false)
                .execute()
                .value
            return rows.map { $0.toBlogPost() }
        } catch {
            print("[SupabaseService] fetchBlogPosts FAILED: \(error)")
            return []
        }
    }

    func fetchLandEstates() async -> [LandEstate] {
        guard isConfigured else { return [] }
        do {
            let rows: [LandEstateRow] = try await client
                .from("land_estates")
                .select()
                .order("name", ascending: true)
                .execute()
                .value
            return rows.map { $0.toLandEstate() }
        } catch {
            print("[SupabaseService] fetchLandEstates FAILED: \(error)")
            return []
        }
    }

    func fetchFacades() async -> [Facade] {
        guard isConfigured else { return [] }
        do {
            let rows: [FacadeRow] = try await client
                .from("facades")
                .select()
                .order("name", ascending: true)
                .execute()
                .value
            return rows.map { $0.toFacade() }
        } catch {
            print("[SupabaseService] fetchFacades FAILED: \(error)")
            return []
        }
    }

    func fetchDocuments(clientId: String) async -> [ClientDocument] {
        guard isConfigured else { return [] }
        do {
            let rows: [ClientDocumentRow] = try await client
                .from("documents")
                .select()
                .eq("client_id", value: clientId)
                .order("date_added", ascending: false)
                .execute()
                .value
            return rows.map { $0.toClientDocument() }
        } catch {
            print("[SupabaseService] fetchDocuments FAILED: \(error)")
            return []
        }
    }

    func fetchAllDocuments() async -> [ClientDocument] {
        guard isConfigured else { return [] }
        do {
            let rows: [ClientDocumentRow] = try await client
                .from("documents")
                .select()
                .order("date_added", ascending: false)
                .execute()
                .value
            return rows.map { $0.toClientDocument() }
        } catch {
            print("[SupabaseService] fetchAllDocuments FAILED: \(error)")
            return []
        }
    }

    func upsertDocument(_ doc: ClientDocument, clientId: String) async {
        guard isConfigured else { return }
        let row = ClientDocumentRow(from: doc, clientId: clientId)
        _ = try? await client
            .from("documents")
            .upsert(row)
            .execute()
    }

    func deleteDocument(id: String) async {
        guard isConfigured else { return }
        _ = try? await client
            .from("documents")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func uploadDocument(
        buildId: String,
        clientIds: [String],
        name: String,
        category: DocumentCategory,
        fileData: Data,
        fileName: String,
        buildStageId: String? = nil,
        buildStageName: String? = nil
    ) async -> ClientDocument? {
        guard isConfigured else { return nil }

        guard let fileURL = await PDFUploadService.shared.uploadPDF(fileData, fileName: fileName, buildId: buildId) else {
            return nil
        }

        let fileSizeBytes = fileData.count
        let fileSizeStr: String
        if fileSizeBytes < 1024 {
            fileSizeStr = "\(fileSizeBytes) B"
        } else if fileSizeBytes < 1024 * 1024 {
            fileSizeStr = String(format: "%.1f KB", Double(fileSizeBytes) / 1024)
        } else {
            fileSizeStr = String(format: "%.1f MB", Double(fileSizeBytes) / (1024 * 1024))
        }

        let docId = UUID().uuidString
        let doc = ClientDocument(
            id: docId,
            name: name,
            category: category,
            dateAdded: .now,
            fileSize: fileSizeStr,
            isNew: true,
            fileURL: fileURL,
            buildId: buildId,
            buildStageName: buildStageName
        )

        for clientId in clientIds where !clientId.isEmpty {
            let row = ClientDocumentRow(from: doc, clientId: clientId, buildId: buildId, buildStageId: buildStageId)
            _ = try? await client.from("documents").insert(row).execute()
        }

        return doc
    }

    func deleteDocumentFromBuild(documentId: String) async -> Bool {
        guard isConfigured else { return false }
        do {
            _ = try await client.from("documents").delete().eq("id", value: documentId).execute()
            return true
        } catch {
            print("[SupabaseService] deleteDocument FAILED: \(error)")
            return false
        }
    }

    func deleteAllDocuments() async -> Bool {
        guard isConfigured else { return false }
        do {
            _ = try await client.from("documents").delete().neq("id", value: "").execute()
            return true
        } catch {
            print("[SupabaseService] deleteAllDocuments FAILED: \(error)")
            return false
        }
    }

    func fetchRequestClientId(requestId: String) async -> String? {
        guard isConfigured else { return nil }
        do {
            let rows: [ServiceRequestRow] = try await client
                .from("service_requests")
                .select()
                .eq("id", value: requestId)
                .limit(1)
                .execute()
                .value
            return rows.first?.client_id
        } catch {
            return nil
        }
    }

    func fetchScheduleItems(clientId: String) async -> [ScheduleItem] {
        guard isConfigured else { return [] }
        do {
            let rows: [ScheduleItemRow] = try await client
                .from("schedule_items")
                .select()
                .eq("client_id", value: clientId)
                .order("date", ascending: true)
                .execute()
                .value
            return rows.map { $0.toScheduleItem() }
        } catch {
            print("[SupabaseService] fetchScheduleItems FAILED: \(error)")
            return []
        }
    }

    // MARK: - Catalogue Data (Colours, Specs, Schemes, Ranges)

    func fetchColourCategories() async -> [ColourCategory] {
        guard isConfigured else { return [] }
        do {
            let rows: [ColourCategoryRow] = try await client
                .from("colour_categories")
                .select()
                .order("sort_order", ascending: true)
                .execute()
                .value
            return rows.map { $0.toColourCategory() }
        } catch {
            print("[SupabaseService] fetchColourCategories FAILED: \(error)")
            return []
        }
    }

    func fetchSpecCategories() async -> [SpecCategory] {
        guard isConfigured else { return [] }

        let flatItems = await fetchSpecItemsFlat()
        if !flatItems.isEmpty {
            return assembleCategories(from: flatItems)
        }

        do {
            let rows: [SpecCategoryRow] = try await client
                .from("spec_categories")
                .select()
                .order("sort_order", ascending: true)
                .execute()
                .value
            return rows.map { $0.toSpecCategory() }
        } catch {
            print("[SupabaseService] fetchSpecCategories FAILED: \(error)")
            return []
        }
    }

    func fetchSpecItemsFlat() async -> [SpecItemFlatRow] {
        guard isConfigured else { return [] }
        do {
            let rows: [SpecItemFlatRow] = try await client
                .from("spec_items")
                .select()
                .order("sort_order", ascending: true)
                .execute()
                .value
            return rows
        } catch {
            print("[SupabaseService] fetchSpecItemsFlat FAILED: \(error)")
            return []
        }
    }

    private func assembleCategories(from items: [SpecItemFlatRow]) -> [SpecCategory] {
        let categoryOrder: [(id: String, name: String, icon: String)] = [
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

        let grouped = Dictionary(grouping: items, by: { $0.category_id })

        return categoryOrder.compactMap { cat in
            guard let catItems = grouped[cat.id], !catItems.isEmpty else { return nil }
            return SpecCategory(
                id: cat.id,
                name: cat.name,
                icon: cat.icon,
                items: catItems.map { $0.toSpecItem() }
            )
        }
    }

    func fetchSpecRangeTiers() async -> [String: SpecRangeTierRow] {
        guard isConfigured else { return [:] }
        do {
            let rows: [SpecRangeTierRow] = try await client
                .from("spec_range_tiers")
                .select()
                .execute()
                .value
            var result: [String: SpecRangeTierRow] = [:]
            for row in rows {
                result[row.tier] = row
            }
            return result
        } catch {
            print("[SupabaseService] fetchSpecRangeTiers FAILED: \(error)")
            return [:]
        }
    }

    func fetchHomeFastSchemes() async -> [HomeFastScheme] {
        guard isConfigured else { return [] }
        do {
            let rows: [HomeFastSchemeRow] = try await client
                .from("homefast_schemes")
                .select()
                .order("sort_order", ascending: true)
                .execute()
                .value
            return rows.map { $0.toHomeFastScheme() }
        } catch {
            print("[SupabaseService] fetchHomeFastSchemes FAILED: \(error)")
            return []
        }
    }

    func fetchSpecToColourMapping() async -> [String: [String]] {
        guard isConfigured else { return [:] }
        do {
            let rows: [SpecToColourMappingRow] = try await client
                .from("spec_to_colour_mapping")
                .select()
                .execute()
                .value
            var result: [String: [String]] = [:]
            for row in rows {
                result[row.spec_item_id] = row.colour_category_ids
            }
            return result
        } catch {
            print("[SupabaseService] fetchSpecToColourMapping FAILED: \(error)")
            return [:]
        }
    }

    func fetchSpecItemImages() async -> (base: [String: String], tier: [String: String]) {
        guard isConfigured else { return ([:], [:]) }
        do {
            let rows: [SpecItemImageRow] = try await client
                .from("spec_item_images")
                .select()
                .execute()
                .value
            var baseMap: [String: String] = [:]
            var tierMap: [String: String] = [:]
            for row in rows {
                if let base = row.base_image_url {
                    baseMap[row.spec_item_id] = base
                }
                if let tiers = row.tier_images {
                    for (tier, url) in tiers {
                        tierMap["\(row.spec_item_id)_\(tier)"] = url
                    }
                }
            }
            return (baseMap, tierMap)
        } catch {
            print("[SupabaseService] fetchSpecItemImages FAILED: \(error)")
            return ([:], [:])
        }
    }

    // MARK: - Admin Catalog CRUD

    func fetchSpecItemImageRow(specItemId: String) async -> SpecItemImageRow? {
        guard isConfigured else { return nil }
        do {
            let rows: [SpecItemImageRow] = try await client
                .from("spec_item_images")
                .select()
                .eq("spec_item_id", value: specItemId)
                .execute()
                .value
            return rows.first
        } catch {
            print("[SupabaseService] fetchSpecItemImageRow FAILED: \(error)")
            return nil
        }
    }

    func upsertSpecItemImageRow(_ row: SpecItemImageRow) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("spec_item_images").upsert(row).execute()
            return true
        } catch {
            print("[SupabaseService] upsertSpecItemImageRow FAILED: \(error)")
            return false
        }
    }

    func upsertSpecItem(_ row: SpecItemFlatRow) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("spec_items").upsert(row).execute()
            return true
        } catch {
            print("[SupabaseService] upsertSpecItem FAILED: \(error)")
            return false
        }
    }

    func deleteSpecItem(id: String) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("spec_items").delete().eq("id", value: id).execute()
            return true
        } catch {
            print("[SupabaseService] deleteSpecItem FAILED: \(error)")
            return false
        }
    }

    func upsertColourCategory(_ row: ColourCategoryUpsertRow) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("colour_categories").upsert(row).execute()
            return true
        } catch {
            print("[SupabaseService] upsertColourCategory FAILED: \(error)")
            return false
        }
    }

    func deleteColourCategory(id: String) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("colour_categories").delete().eq("id", value: id).execute()
            return true
        } catch {
            print("[SupabaseService] deleteColourCategory FAILED: \(error)")
            return false
        }
    }

    func upsertHomeDesign(_ row: HomeDesignRow) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("home_designs").upsert(row).execute()
            return true
        } catch {
            print("[SupabaseService] upsertHomeDesign FAILED: \(error)")
            return false
        }
    }

    func deleteHomeDesign(id: String) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("home_designs").delete().eq("id", value: id).execute()
            return true
        } catch {
            print("[SupabaseService] deleteHomeDesign FAILED: \(error)")
            return false
        }
    }

    // MARK: - Facades CRUD

    func upsertFacade(_ row: FacadeRow) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("facades").upsert(row).execute()
            return true
        } catch {
            print("[SupabaseService] upsertFacade FAILED: \(error)")
            return false
        }
    }

    func deleteFacade(id: String) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("facades").delete().eq("id", value: id).execute()
            return true
        } catch {
            print("[SupabaseService] deleteFacade FAILED: \(error)")
            return false
        }
    }

    // MARK: - House & Land Packages CRUD

    func upsertHouseLandPackage(_ row: HouseLandPackageRow) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("house_land_packages").upsert(row).execute()
            return true
        } catch {
            print("[SupabaseService] upsertHouseLandPackage FAILED: \(error)")
            return false
        }
    }

    func deleteHouseLandPackage(id: String) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("house_land_packages").delete().eq("id", value: id).execute()
            return true
        } catch {
            print("[SupabaseService] deleteHouseLandPackage FAILED: \(error)")
            return false
        }
    }

    // MARK: - Build Spec Selections

    func fetchAllPendingSpecReviews() async -> [BuildSpecSelection] {
        guard isConfigured else { return [] }
        do {
            let rows: [BuildSpecSelectionRow] = try await client
                .from("build_spec_selections")
                .select()
                .eq("status", value: "awaiting_admin")
                .order("updated_at", ascending: false)
                .execute()
                .value
            return rows.map { $0.toModel() }
        } catch {
            print("[SupabaseService] fetchAllPendingSpecReviews FAILED: \(error)")
            return []
        }
    }

    func fetchBuildSpecSelections(buildId: String) async -> [BuildSpecSelection] {
        guard isConfigured else { return [] }
        do {
            let rows: [BuildSpecSelectionRow] = try await client
                .from("build_spec_selections")
                .select()
                .eq("build_id", value: buildId)
                .order("sort_order", ascending: true)
                .execute()
                .value
            return rows.map { $0.toModel() }
        } catch {
            print("[SupabaseService] fetchBuildSpecSelections FAILED: \(error)")
            return []
        }
    }

    func upsertBuildSpecSelection(_ selection: BuildSpecSelection) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("build_spec_selections").upsert(selection.toRow()).execute()
            return true
        } catch {
            print("[SupabaseService] upsertBuildSpecSelection FAILED: \(error)")
            return false
        }
    }

    func upsertBuildSpecSelections(_ selections: [BuildSpecSelection]) async -> Bool {
        guard isConfigured else { return false }
        let rows = selections.map { $0.toRow() }
        do {
            try await client.from("build_spec_selections").upsert(rows).execute()
            return true
        } catch {
            print("[SupabaseService] upsertBuildSpecSelections FAILED: \(error)")
            return false
        }
    }

    func createBuildSpecSnapshot(buildId: String, specTier: SpecTier) async -> Bool {
        guard isConfigured else { return false }
        let catalog = CatalogDataManager.shared
        let categories = catalog.allSpecCategories
        let tierKey = specTier.imageKeySuffix

        var selections: [BuildSpecSelection] = []
        var sortIndex = 0

        for category in categories {
            for item in category.items {
                let description = item.description(for: specTier)
                let imageURL = item.customImageURL ?? catalog.specItemBaseImages[item.id]
                let selection = BuildSpecSelection(
                    id: UUID().uuidString,
                    buildId: buildId,
                    categoryId: category.id,
                    specItemId: item.id,
                    specTier: tierKey,
                    selectionType: .included,
                    clientNotes: nil,
                    adminNotes: nil,
                    clientConfirmed: false,
                    adminConfirmed: false,
                    clientConfirmedAt: nil,
                    adminConfirmedAt: nil,
                    lockedForClient: false,
                    status: .draft,
                    snapshotName: item.name,
                    snapshotDescription: description,
                    snapshotImageURL: imageURL,
                    snapshotCategoryName: category.name,
                    sortOrder: sortIndex
                )
                selections.append(selection)
                sortIndex += 1
            }
        }

        return await upsertBuildSpecSelections(selections)
    }

    func submitClientSpecConfirmation(buildId: String) async -> Bool {
        guard isConfigured else { return false }
        var selections = await fetchBuildSpecSelections(buildId: buildId)
        guard !selections.isEmpty else { return false }
        let now = Date.now
        for i in selections.indices {
            selections[i].clientConfirmed = true
            selections[i].clientConfirmedAt = now
            selections[i].lockedForClient = true
            selections[i].status = .awaitingAdmin
        }
        return await upsertBuildSpecSelections(selections)
    }

    func approveBuildSpecSelections(buildId: String) async -> Bool {
        guard isConfigured else { return false }
        var selections = await fetchBuildSpecSelections(buildId: buildId)
        guard !selections.isEmpty else { return false }
        let now = Date.now
        for i in selections.indices {
            selections[i].adminConfirmed = true
            selections[i].adminConfirmedAt = now
            selections[i].status = .approved
        }
        return await upsertBuildSpecSelections(selections)
    }

    func reopenBuildSpecSelections(buildId: String) async -> Bool {
        guard isConfigured else { return false }
        var selections = await fetchBuildSpecSelections(buildId: buildId)
        guard !selections.isEmpty else { return false }
        for i in selections.indices {
            selections[i].lockedForClient = false
            selections[i].clientConfirmed = false
            selections[i].clientConfirmedAt = nil
            selections[i].adminConfirmed = false
            selections[i].adminConfirmedAt = nil
            selections[i].status = .reopenedByAdmin
        }
        return await upsertBuildSpecSelections(selections)
    }

    // MARK: - Build Colour Selections

    func fetchBuildColourSelections(buildId: String) async -> [BuildColourSelection] {
        guard isConfigured else { return [] }
        do {
            let rows: [BuildColourSelectionRow] = try await client
                .from("build_colour_selections")
                .select()
                .eq("build_id", value: buildId)
                .execute()
                .value
            return rows.map { $0.toModel() }
        } catch {
            print("[SupabaseService] fetchBuildColourSelections FAILED: \(error)")
            return []
        }
    }

    func submitClientColourSelections(buildId: String) async -> Bool {
        guard isConfigured else { return false }
        var selections = await fetchBuildColourSelections(buildId: buildId)
        guard !selections.isEmpty else { return false }
        for i in selections.indices {
            selections[i].selectionStatus = .submitted
        }
        var success = true
        for s in selections {
            let ok = await upsertBuildColourSelection(s)
            if !ok { success = false }
        }
        return success
    }

    func approveClientColourSelections(buildId: String) async -> Bool {
        guard isConfigured else { return false }
        var selections = await fetchBuildColourSelections(buildId: buildId)
        guard !selections.isEmpty else { return false }
        for i in selections.indices {
            selections[i].selectionStatus = .approved
        }
        var success = true
        for s in selections {
            let ok = await upsertBuildColourSelection(s)
            if !ok { success = false }
        }
        return success
    }

    func upsertBuildColourSelection(_ selection: BuildColourSelection) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("build_colour_selections").upsert(selection.toRow()).execute()
            return true
        } catch {
            print("[SupabaseService] upsertBuildColourSelection FAILED: \(error)")
            return false
        }
    }

    // MARK: - Build Spec Documents

    func fetchBuildSpecDocuments(buildId: String) async -> [BuildSpecDocument] {
        guard isConfigured else { return [] }
        do {
            let rows: [BuildSpecDocumentRow] = try await client
                .from("build_spec_documents")
                .select()
                .eq("build_id", value: buildId)
                .order("version", ascending: false)
                .execute()
                .value
            return rows.map { $0.toModel() }
        } catch {
            print("[SupabaseService] fetchBuildSpecDocuments FAILED: \(error)")
            return []
        }
    }

    func upsertBuildSpecDocument(_ doc: BuildSpecDocument) async -> Bool {
        guard isConfigured else { return false }
        let row = BuildSpecDocumentRow(
            id: doc.id,
            build_id: doc.buildId,
            storage_path: doc.storagePath ?? "",
            public_url: doc.publicURL,
            version: doc.version,
            generated_at: doc.generatedAt.map { ISO8601DateFormatter().string(from: $0) },
            generated_by: doc.generatedBy
        )
        do {
            try await client.from("build_spec_documents").upsert(row).execute()
            return true
        } catch {
            print("[SupabaseService] upsertBuildSpecDocument FAILED: \(error)")
            return false
        }
    }

    // MARK: - Real-Time Subscriptions

    func subscribeToBuildChanges(onUpdate: @escaping @Sendable () -> Void) {
        guard isConfigured else { return }
        let channel = client.realtimeV2.channel("builds_sync")
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "build_stages"
        )
        Task {
            try? await channel.subscribeWithError()
            for await _ in changes {
                await MainActor.run { onUpdate() }
            }
        }
    }

    func subscribeToAssignmentChanges(onUpdate: @escaping @Sendable () -> Void) {
        guard isConfigured else { return }
        let channel = client.realtimeV2.channel("assignments_sync")
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "package_assignments"
        )
        Task {
            try? await channel.subscribeWithError()
            for await _ in changes {
                await MainActor.run { onUpdate() }
            }
        }
    }

    func subscribeToRequestChanges(onUpdate: @escaping @Sendable () -> Void) {
        guard isConfigured else { return }
        let channel = client.realtimeV2.channel("requests_sync")
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "service_requests"
        )
        Task {
            try? await channel.subscribeWithError()
            for await _ in changes {
                await MainActor.run { onUpdate() }
            }
        }
    }

    func subscribeToProfileChanges(userId: String, onUpdate: @escaping @Sendable () -> Void) {
        guard isConfigured else { return }
        let channel = client.realtimeV2.channel("profile_sync:\(userId)")
        let changes = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "profiles",
            filter: .eq("id", value: userId)
        )
        Task {
            try? await channel.subscribeWithError()
            for await _ in changes {
                await MainActor.run { onUpdate() }
            }
        }
    }

    func subscribeToDocumentChanges(onUpdate: @escaping @Sendable () -> Void) {
        guard isConfigured else { return }
        let channel = client.realtimeV2.channel("documents_sync")
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "documents"
        )
        Task {
            try? await channel.subscribeWithError()
            for await _ in changes {
                await MainActor.run { onUpdate() }
            }
        }
    }

    func subscribeToBuildTableChanges(onUpdate: @escaping @Sendable () -> Void) {
        guard isConfigured else { return }
        let channel = client.realtimeV2.channel("builds_table_sync")
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "builds"
        )
        Task {
            try? await channel.subscribeWithError()
            for await _ in changes {
                await MainActor.run { onUpdate() }
            }
        }
    }

    func subscribeToMessageChanges(onUpdate: @escaping @Sendable () -> Void) {
        guard isConfigured else { return }
        let channel = client.realtimeV2.channel("conversations_sync")
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "conversations"
        )
        Task {
            try? await channel.subscribeWithError()
            for await _ in changes {
                await MainActor.run { onUpdate() }
            }
        }
    }

    func subscribeToSpecSelectionChanges(onUpdate: @escaping @Sendable () -> Void) {
        guard isConfigured else { return }
        let channel = client.realtimeV2.channel("spec_selections_sync")
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "build_spec_selections"
        )
        Task {
            try? await channel.subscribeWithError()
            for await _ in changes {
                await MainActor.run { onUpdate() }
            }
        }
    }
}
