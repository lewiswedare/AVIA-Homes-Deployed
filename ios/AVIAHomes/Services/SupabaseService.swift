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

    var realtimeChannels: [RealtimeChannelV2] = []

    var isConfigured: Bool {
        !Self.supabaseURL.isEmpty && !Self.supabaseKey.isEmpty
    }

    func removeAllChannels() async {
        for channel in realtimeChannels {
            await client.realtimeV2.removeChannel(channel)
        }
        realtimeChannels.removeAll()
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

    @discardableResult
    func deleteBuild(buildId: String) async -> Bool {
        guard isConfigured else { return false }
        // Delete all child rows before removing the build itself
        let childTables = [
            ("build_milestones",       "build_id"),
            ("build_reminders",        "build_id"),
            ("build_stages",           "build_id"),
            ("build_spec_selections",  "build_id"),
            ("build_colour_selections","build_id"),
            ("build_spec_documents",   "build_id"),
            ("service_requests",       "build_id"),
            ("documents",              "build_id"),
            ("schedule_items",         "build_id"),
        ]
        for (table, column) in childTables {
            _ = try? await client
                .from(table)
                .delete()
                .eq(column, value: buildId)
                .execute()
        }
        _ = try? await client.from("notifications").delete().eq("reference_id", value: buildId).execute()
        do {
            try await client
                .from("builds")
                .delete()
                .eq("id", value: buildId)
                .execute()
            print("[SupabaseService] deleteBuild SUCCESS for id=\(buildId)")
            return true
        } catch {
            print("[SupabaseService] deleteBuild FAILED for id=\(buildId) — error: \(error)")
            return false
        }
    }

    func removeClientFromBuild(buildId: String, clientId: String, newPrimaryId: String?, newAdditionalIds: [String]) async -> Bool {
        guard isConfigured else { return false }
        do {
            let patch = BuildClientPatch(
                client_id: (newPrimaryId?.isEmpty == false) ? newPrimaryId : nil,
                additional_client_ids: newAdditionalIds
            )
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

    func deleteBuildForce(buildId: String) async -> Bool {
        guard isConfigured else { return false }
        let allChildTables: [(String, String)] = [
            ("build_milestones",        "build_id"),
            ("build_reminders",         "build_id"),
            ("build_stages",            "build_id"),
            ("build_spec_selections",   "build_id"),
            ("build_colour_selections", "build_id"),
            ("build_spec_documents",    "build_id"),
            ("service_requests",        "build_id"),
            ("documents",               "build_id"),
            ("schedule_items",          "build_id"),
        ]
        for (table, column) in allChildTables {
            _ = try? await client.from(table).delete().eq(column, value: buildId).execute()
        }
        _ = try? await client.from("notifications").delete().eq("reference_id", value: buildId).execute()
        do {
            try await client.from("builds").delete().eq("id", value: buildId).execute()
            print("[SupabaseService] deleteBuildForce SUCCESS for id=\(buildId)")
            return true
        } catch {
            print("[SupabaseService] deleteBuildForce FAILED: \(error)")
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

    func deleteBuildStage(stageId: String) async {
        guard isConfigured else { return }
        _ = try? await client
            .from("build_stages")
            .delete()
            .eq("id", value: stageId)
            .execute()
    }

    // MARK: - Build Milestones

    func fetchMilestonesForBuild(buildId: String) async -> [BuildMilestone] {
        guard isConfigured else { return [] }
        do {
            let rows: [BuildMilestoneRow] = try await client
                .from("build_milestones")
                .select()
                .eq("build_id", value: buildId)
                .order("due_date", ascending: true)
                .execute()
                .value
            return rows.map { $0.toBuildMilestone() }
        } catch {
            print("[SupabaseService] fetchMilestonesForBuild FAILED: \(error)")
            return []
        }
    }

    func fetchMilestonesForStage(stageId: String) async -> [BuildMilestone] {
        guard isConfigured else { return [] }
        do {
            let rows: [BuildMilestoneRow] = try await client
                .from("build_milestones")
                .select()
                .eq("build_stage_id", value: stageId)
                .order("due_date", ascending: true)
                .execute()
                .value
            return rows.map { $0.toBuildMilestone() }
        } catch {
            print("[SupabaseService] fetchMilestonesForStage FAILED: \(error)")
            return []
        }
    }

    @discardableResult
    func upsertMilestone(_ milestone: BuildMilestone) async -> Bool {
        guard isConfigured else { return false }
        let row = BuildMilestoneRow(from: milestone)
        do {
            try await client
                .from("build_milestones")
                .upsert(row)
                .execute()
            return true
        } catch {
            print("[SupabaseService] upsertMilestone FAILED: \(error)")
            return false
        }
    }

    @discardableResult
    func deleteMilestone(id: String) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client
                .from("build_milestones")
                .delete()
                .eq("id", value: id)
                .execute()
            return true
        } catch {
            print("[SupabaseService] deleteMilestone FAILED: \(error)")
            return false
        }
    }

    @discardableResult
    func completeMilestone(id: String) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client
                .from("build_milestones")
                .update(["status": "completed", "completed_at": ISO8601DateFormatter().string(from: .now)])
                .eq("id", value: id)
                .execute()
            return true
        } catch {
            print("[SupabaseService] completeMilestone FAILED: \(error)")
            return false
        }
    }

    // MARK: - Build Reminders

    func fetchRemindersForClient(clientId: String) async -> [BuildReminder] {
        guard isConfigured else { return [] }
        do {
            let rows: [BuildReminderRow] = try await client
                .from("build_reminders")
                .select()
                .eq("client_id", value: clientId)
                .order("reminder_date", ascending: true)
                .execute()
                .value
            return rows.map { $0.toBuildReminder() }
        } catch {
            print("[SupabaseService] fetchRemindersForClient FAILED: \(error)")
            return []
        }
    }

    func fetchRemindersForBuild(buildId: String) async -> [BuildReminder] {
        guard isConfigured else { return [] }
        do {
            let rows: [BuildReminderRow] = try await client
                .from("build_reminders")
                .select()
                .eq("build_id", value: buildId)
                .order("reminder_date", ascending: true)
                .execute()
                .value
            return rows.map { $0.toBuildReminder() }
        } catch {
            print("[SupabaseService] fetchRemindersForBuild FAILED: \(error)")
            return []
        }
    }

    @discardableResult
    func upsertReminder(_ reminder: BuildReminder) async -> Bool {
        guard isConfigured else { return false }
        let row = BuildReminderRow(from: reminder)
        do {
            try await client
                .from("build_reminders")
                .upsert(row)
                .execute()
            return true
        } catch {
            print("[SupabaseService] upsertReminder FAILED: \(error)")
            return false
        }
    }

    @discardableResult
    func deleteReminder(id: String) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client
                .from("build_reminders")
                .delete()
                .eq("id", value: id)
                .execute()
            return true
        } catch {
            print("[SupabaseService] deleteReminder FAILED: \(error)")
            return false
        }
    }

    @discardableResult
    func markReminderRead(id: String) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client
                .from("build_reminders")
                .update(["is_read": "true"])
                .eq("id", value: id)
                .execute()
            return true
        } catch {
            print("[SupabaseService] markReminderRead FAILED: \(error)")
            return false
        }
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

    /// Writes a package assignment.
    ///
    /// Uses separate INSERT/UPDATE paths because RLS on `package_assignments` has different
    /// permission scopes per command: only staff can INSERT, but clients listed in
    /// `shared_with_client_ids` can UPDATE (to record accept/decline). A PostgREST
    /// upsert always enforces the INSERT policy’s WITH CHECK even when it takes the UPDATE
    /// path, so a plain `.upsert()` fails silently for clients — which broke the
    /// decline/accept flow. See https://github.com/orgs/supabase/discussions/30499
    @discardableResult
    func upsertPackageAssignment(_ assignment: PackageAssignment) async -> Bool {
        guard isConfigured else {
            print("[SupabaseService] upsertPackageAssignment: not configured")
            return false
        }
        let row = PackageAssignmentRow(from: assignment)
        do {
            // First, see if a row with this id already exists. We can’t do this with a
            // simple head-only count because SELECT is RLS-gated too, but every caller who
            // can UPDATE can also SELECT this row (pa_select covers shared clients,
            // partners and staff), so this is safe.
            let existing: [PackageAssignmentRow] = try await client
                .from("package_assignments")
                .select()
                .eq("id", value: assignment.id)
                .limit(1)
                .execute()
                .value

            if existing.isEmpty {
                try await client
                    .from("package_assignments")
                    .insert(row)
                    .execute()
                print("[SupabaseService] upsertPackageAssignment INSERT SUCCESS for pkg=\(assignment.packageId)")
            } else {
                try await client
                    .from("package_assignments")
                    .update(row)
                    .eq("id", value: assignment.id)
                    .execute()
                print("[SupabaseService] upsertPackageAssignment UPDATE SUCCESS for pkg=\(assignment.packageId)")
            }
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
    func upsertServiceRequest(_ request: ServiceRequest, clientId: String, buildId: String? = nil) async -> Bool {
        guard isConfigured else {
            print("[SupabaseService] upsertServiceRequest: not configured")
            return false
        }
        let row = ServiceRequestRow(from: request, clientId: clientId, buildId: buildId)
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

    // MARK: - Build Field Updates

    func updateBuildFields(buildId: String, fields: [String: String]) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client
                .from("builds")
                .update(fields)
                .eq("id", value: buildId)
                .execute()
            return true
        } catch {
            print("[SupabaseService] updateBuildFields FAILED for buildId=\(buildId) — \(error)")
            return false
        }
    }

    func updatePackageAssignmentFields(assignmentId: String, fields: [String: AnyJSON]) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client
                .from("package_assignments")
                .update(fields)
                .eq("id", value: assignmentId)
                .execute()
            return true
        } catch {
            print("[SupabaseService] updatePackageAssignmentFields FAILED — \(error)")
            return false
        }
    }

    func fetchProfilesByRole(role: String) async -> [ClientUser] {
        guard isConfigured else { return [] }
        do {
            let rows: [ProfileRow] = try await client
                .from("profiles")
                .select()
                .eq("role", value: role)
                .execute()
                .value
            return rows.map { $0.toClientUser() }
        } catch {
            print("[SupabaseService] fetchProfilesByRole FAILED: \(error)")
            return []
        }
    }

    func upsertScheduleItem(_ item: ScheduleItem, clientId: String) async -> Bool {
        guard isConfigured else { return false }
        let row = ScheduleItemRow(from: item, clientId: clientId)
        do {
            try await client
                .from("schedule_items")
                .upsert(row)
                .execute()
            return true
        } catch {
            print("[SupabaseService] upsertScheduleItem FAILED: \(error)")
            return false
        }
    }

    func deleteScheduleItem(id: String) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client
                .from("schedule_items")
                .delete()
                .eq("id", value: id)
                .execute()
            return true
        } catch {
            print("[SupabaseService] deleteScheduleItem FAILED: \(error)")
            return false
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

    func upsertSpecRangeTier(_ row: SpecRangeTierRow) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("spec_range_tiers").upsert(row, onConflict: "tier").execute()
            return true
        } catch {
            print("[SupabaseService] upsertSpecRangeTier FAILED: \(error)")
            return false
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

    /// Upsert the spec-to-colour linkage. If `colourCategoryIds` is empty, the row is deleted
    /// so the spec item shows no colour categories in Stage 2 filtering.
    func upsertSpecToColourMapping(specItemId: String, colourCategoryIds: [String]) async -> Bool {
        guard isConfigured else { return false }
        do {
            if colourCategoryIds.isEmpty {
                try await client.from("spec_to_colour_mapping")
                    .delete()
                    .eq("spec_item_id", value: specItemId)
                    .execute()
            } else {
                let row = SpecToColourMappingRow(
                    spec_item_id: specItemId,
                    colour_category_ids: colourCategoryIds
                )
                try await client.from("spec_to_colour_mapping").upsert(row).execute()
            }
            return true
        } catch {
            print("[SupabaseService] upsertSpecToColourMapping FAILED: \(error)")
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

    // MARK: - Cost Management

    func updateSpecItemCosts(_ row: SpecItemFlatRow) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("spec_items").upsert(row).execute()
            return true
        } catch {
            print("[SupabaseService] updateSpecItemCosts FAILED: \(error)")
            return false
        }
    }

    func fetchUpgradePricing() async -> [UpgradePricing] {
        guard isConfigured else { return [] }
        do {
            let rows: [UpgradePricingRow] = try await client
                .from("upgrade_pricing")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            return rows.map { $0.toModel() }
        } catch {
            print("[SupabaseService] fetchUpgradePricing FAILED: \(error)")
            return []
        }
    }

    func upsertUpgradePricing(_ row: UpgradePricingRow) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("upgrade_pricing").upsert(row).execute()
            return true
        } catch {
            print("[SupabaseService] upsertUpgradePricing FAILED: \(error)")
            return false
        }
    }

    func deleteUpgradePricing(id: String) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("upgrade_pricing").delete().eq("id", value: id).execute()
            return true
        } catch {
            print("[SupabaseService] deleteUpgradePricing FAILED: \(error)")
            return false
        }
    }

    func fetchFullRangeUpgradePricing(storeyType: String? = nil) async -> [UpgradePricing] {
        guard isConfigured else { return [] }
        do {
            let allRows: [UpgradePricingRow] = try await client
                .from("upgrade_pricing")
                .select()
                .execute()
                .value
            let fullRange = allRows.filter {
                $0.spec_item_id == nil && $0.colour_category_id == nil && $0.colour_option_id == nil
            }
            let models = fullRange.map { $0.toModel() }
            if let storeyType {
                return models.filter { $0.storeyType == storeyType }
            }
            return models
        } catch {
            print("[SupabaseService] fetchFullRangeUpgradePricing FAILED: \(error)")
            return []
        }
    }

    // MARK: - Build Range Upgrade Requests

    func fetchBuildRangeUpgradeRequests(buildId: String) async -> [BuildRangeUpgradeRequest] {
        guard isConfigured else { return [] }
        do {
            let rows: [BuildRangeUpgradeRequestRow] = try await client
                .from("build_range_upgrade_requests")
                .select()
                .eq("build_id", value: buildId)
                .execute()
                .value
            return rows.map { $0.toModel() }
        } catch {
            print("[SupabaseService] fetchBuildRangeUpgradeRequests FAILED: \(error)")
            return []
        }
    }

    func upsertBuildRangeUpgradeRequest(_ request: BuildRangeUpgradeRequest) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("build_range_upgrade_requests").upsert(request.toRow()).execute()
            return true
        } catch {
            print("[SupabaseService] upsertBuildRangeUpgradeRequest FAILED: \(error)")
            return false
        }
    }

    func deleteBuildRangeUpgradeRequest(id: String) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("build_range_upgrade_requests").delete().eq("id", value: id).execute()
            return true
        } catch {
            print("[SupabaseService] deleteBuildRangeUpgradeRequest FAILED: \(error)")
            return false
        }
    }

    func updateBuildSpecTier(buildId: String, newTier: String) async -> Bool {
        guard isConfigured else { return false }
        do {
            struct TierPatch: Codable { let spec_tier: String }
            try await client.from("builds").update(TierPatch(spec_tier: newTier)).eq("id", value: buildId).execute()
            return true
        } catch {
            print("[SupabaseService] updateBuildSpecTier FAILED: \(error)")
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
            try await client.from("house_land_packages").upsert(row, onConflict: "id").execute()
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
                .neq("selection_type", value: "upgrade_draft")
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
        if !catalog.isLoaded {
            await catalog.loadAll()
        }
        let categories = catalog.allSpecCategories
        guard !categories.isEmpty else {
            print("[SupabaseService] createBuildSpecSnapshot: no spec categories loaded, aborting")
            return false
        }
        let tierKey = specTier.imageKeySuffix

        var selections: [BuildSpecSelection] = []
        var sortIndex = 0

        for category in categories {
            for item in category.items {
                let description = item.description(for: specTier)
                let imageURL = item.customImageURL ?? catalog.specItemBaseImages[item.id]
                // Standard tier items are pre-confirmed by default.
                // Only manually upgraded items will deviate from this state.
                let now = Date.now
                let selection = BuildSpecSelection(
                    id: UUID().uuidString,
                    buildId: buildId,
                    categoryId: category.id,
                    specItemId: item.id,
                    specTier: tierKey,
                    selectionType: .included,
                    clientNotes: nil,
                    adminNotes: nil,
                    clientConfirmed: true,
                    adminConfirmed: true,
                    clientConfirmedAt: now,
                    adminConfirmedAt: now,
                    lockedForClient: false,
                    status: .approved,
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
            // Only update items that are standard included — upgrades stay in their own flow
            guard selections[i].selectionType == .included else { continue }
            selections[i].clientConfirmed = true
            selections[i].clientConfirmedAt = now
            selections[i].lockedForClient = true
            if !selections[i].adminConfirmed {
                selections[i].status = .awaitingAdmin
            }
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
            // Only reopen upgrade-requested items — standard included items stay confirmed
            guard selections[i].selectionType == .upgradeRequested else { continue }
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
        realtimeChannels.append(channel)
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
        realtimeChannels.append(channel)
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
        realtimeChannels.append(channel)
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
        realtimeChannels.append(channel)
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
        realtimeChannels.append(channel)
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
        realtimeChannels.append(channel)
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
        realtimeChannels.append(channel)
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
        realtimeChannels.append(channel)
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

    func subscribeToColourSelectionChanges(onUpdate: @escaping @Sendable () -> Void) {
        guard isConfigured else { return }
        let channel = client.realtimeV2.channel("colour_selections_sync")
        realtimeChannels.append(channel)
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "build_colour_selections"
        )
        Task {
            try? await channel.subscribeWithError()
            for await _ in changes {
                await MainActor.run { onUpdate() }
            }
        }
    }

    func subscribeToScheduleChanges(clientId: String, onUpdate: @escaping @Sendable () -> Void) {
        guard isConfigured else { return }
        let channel = client.realtimeV2.channel("schedule_sync:\(clientId)")
        realtimeChannels.append(channel)
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "schedule_items"
        )
        Task {
            try? await channel.subscribeWithError()
            for await _ in changes {
                await MainActor.run { onUpdate() }
            }
        }
    }

    // MARK: - EOI Submissions

    func submitEOI(_ row: EOISubmissionRow) async -> Bool {
        do {
            try await client.from("eoi_submissions").upsert(row, onConflict: "id").execute()
            try await client.from("package_assignments")
                .update(["eoi_status": row.status])
                .eq("id", value: row.package_assignment_id)
                .execute()
            return true
        } catch {
            print("[SupabaseService] submitEOI error: \(error)")
            return false
        }
    }

    func fetchEOI(forAssignment assignmentId: String) async -> EOISubmissionRow? {
        do {
            let rows: [EOISubmissionRow] = try await client.from("eoi_submissions")
                .select()
                .eq("package_assignment_id", value: assignmentId)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch {
            print("[SupabaseService] fetchEOI error: \(error)")
            return nil
        }
    }

    func fetchAllEOIs(status: String? = nil) async -> [EOISubmissionRow] {
        do {
            var query = client.from("eoi_submissions").select()
            if let status = status {
                query = query.eq("status", value: status)
            }
            let rows: [EOISubmissionRow] = try await query
                .order("created_at", ascending: false)
                .execute()
                .value
            return rows
        } catch {
            print("[SupabaseService] fetchAllEOIs error: \(error)")
            return []
        }
    }

    func reviewEOI(eoiId: String, assignmentId: String, status: String, adminNotes: String?, reviewedBy: String) async -> Bool {
        do {
            var updates: [String: String] = [
                "status": status,
                "reviewed_by": reviewedBy,
                "reviewed_at": ISO8601DateFormatter().string(from: .now)
            ]
            if let notes = adminNotes {
                updates["admin_notes"] = notes
            }
            try await client.from("eoi_submissions")
                .update(updates)
                .eq("id", value: eoiId)
                .execute()
            try await client.from("package_assignments")
                .update(["eoi_status": status])
                .eq("id", value: assignmentId)
                .execute()
            return true
        } catch {
            print("[SupabaseService] reviewEOI error: \(error)")
            return false
        }
    }

    func fetchEOIsForPackage(packageId: String) async -> [EOISubmissionRow] {
        do {
            let rows: [EOISubmissionRow] = try await client.from("eoi_submissions")
                .select()
                .eq("package_id", value: packageId)
                .order("created_at", ascending: false)
                .execute()
                .value
            return rows
        } catch {
            print("[SupabaseService] fetchEOIsForPackage error: \(error)")
            return []
        }
    }

    func declineEOI(eoiId: String, assignmentId: String, reviewedBy: String, adminNotes: String? = nil) async -> Bool {
        do {
            var updates: [String: String] = [
                "status": "declined",
                "reviewed_by": reviewedBy,
                "reviewed_at": ISO8601DateFormatter().string(from: .now)
            ]
            if let notes = adminNotes {
                updates["admin_notes"] = notes
            }
            try await client.from("eoi_submissions")
                .update(updates)
                .eq("id", value: eoiId)
                .execute()
            return true
        } catch {
            print("[SupabaseService] declineEOI error: \(error)")
            return false
        }
    }

    func acceptEOIAndDeclineOthers(acceptedEOIId: String, packageId: String, assignmentId: String, reviewedBy: String) async -> Bool {
        // First approve the selected EOI
        let approveSuccess = await reviewEOI(
            eoiId: acceptedEOIId,
            assignmentId: assignmentId,
            status: "approved",
            adminNotes: nil,
            reviewedBy: reviewedBy
        )
        guard approveSuccess else { return false }

        // Fetch all other EOIs for this package and decline them
        let allEOIs = await fetchEOIsForPackage(packageId: packageId)
        for eoi in allEOIs where eoi.id != acceptedEOIId && eoi.status != "declined" && eoi.status != "approved" {
            _ = await declineEOI(
                eoiId: eoi.id,
                assignmentId: eoi.package_assignment_id,
                reviewedBy: reviewedBy,
                adminNotes: "Auto-declined: another EOI was accepted for this package"
            )
        }
        return true
    }

    // MARK: - Contract Signatures

    func createContractRecord(eoiId: String, assignmentId: String, clientId: String) async -> ContractSignatureRow? {
        do {
            let row = ContractSignatureRow(
                id: UUID().uuidString,
                eoi_id: eoiId,
                package_assignment_id: assignmentId,
                client_id: clientId,
                contract_document_url: nil,
                contract_uploaded_by: nil,
                contract_uploaded_at: nil,
                signature_image_url: nil,
                signed_at: nil,
                signer_name: nil,
                signer_ip: nil,
                signed_document_url: nil,
                status: "awaiting_contract",
                created_at: nil,
                updated_at: nil
            )
            try await client.from("contract_signatures").insert(row).execute()
            try await client.from("package_assignments")
                .update(["contract_status": "awaiting_contract"])
                .eq("id", value: assignmentId)
                .execute()
            return row
        } catch {
            print("[SupabaseService] createContractRecord error: \(error)")
            return nil
        }
    }

    /// Uploads a signed contract PDF. Either the owning client or an admin
    /// can call this. The storage path starts with `<client_id>/` so the
    /// existing per-client storage RLS policies apply.
    ///
    /// After upload the status moves to `awaiting_confirmation` and BOTH
    /// parties must then tick confirm via `confirmContract(...)`.
    func uploadContractDocument(contractId: String, assignmentId: String, clientId: String, fileData: Data, fileName: String, uploadedBy: String) async -> String? {
        do {
            let safeName = fileName.replacingOccurrences(of: " ", with: "_")
            let path = "\(clientId)/\(contractId)/\(safeName)"
            try await client.storage.from("contracts").upload(
                path: path,
                file: fileData,
                options: .init(contentType: "application/pdf", upsert: true)
            )
            let url = try client.storage.from("contracts").getPublicURL(path: path).absoluteString
            try await client.from("contract_signatures")
                .update([
                    "contract_document_url": url,
                    "contract_uploaded_by": uploadedBy,
                    "contract_uploaded_at": ISO8601DateFormatter().string(from: .now),
                    "status": "awaiting_confirmation"
                ])
                .eq("id", value: contractId)
                .execute()
            try await client.from("package_assignments")
                .update(["contract_status": "awaiting_confirmation"])
                .eq("id", value: assignmentId)
                .execute()
            return url
        } catch {
            print("[SupabaseService] uploadContractDocument error: \(error)")
            return nil
        }
    }

    func fetchContractSignature(forAssignment assignmentId: String) async -> ContractSignatureRow? {
        do {
            let rows: [ContractSignatureRow] = try await client.from("contract_signatures")
                .select()
                .eq("package_assignment_id", value: assignmentId)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch {
            print("[SupabaseService] fetchContractSignature error: \(error)")
            return nil
        }
    }

    enum ContractConfirmationRole: String {
        case client
        case admin
    }

    /// Records a confirmation tick from either the client or an admin.
    /// When BOTH sides have confirmed, the contract row + assignment move
    /// to `status = 'signed'`.
    func confirmContract(contractId: String, assignmentId: String, role: ContractConfirmationRole, confirmedBy: String) async -> Bool {
        do {
            let nowStr = ISO8601DateFormatter().string(from: .now)
            var updateFields: [String: String] = [:]
            switch role {
            case .client:
                updateFields["client_confirmed_at"] = nowStr
            case .admin:
                updateFields["admin_confirmed_at"] = nowStr
                updateFields["admin_confirmed_by"] = confirmedBy
            }
            try await client.from("contract_signatures")
                .update(updateFields)
                .eq("id", value: contractId)
                .execute()

            // Re-fetch to decide the new aggregate status atomically.
            let rows: [ContractSignatureRow] = try await client.from("contract_signatures")
                .select()
                .eq("id", value: contractId)
                .limit(1)
                .execute()
                .value
            guard let updated = rows.first else { return true }
            if updated.isFullyConfirmed {
                try await client.from("contract_signatures")
                    .update(["status": "signed"])
                    .eq("id", value: contractId)
                    .execute()
                try await client.from("package_assignments")
                    .update(["contract_status": "signed"])
                    .eq("id", value: assignmentId)
                    .execute()
            }
            return true
        } catch {
            print("[SupabaseService] confirmContract error: \(error)")
            return false
        }
    }

    // MARK: - Contracts (Pipeline)

    @discardableResult
    func createContract(eoiId: String?, packageAssignmentId: String?, clientId: String, adminId: String, contractUrl: String?, notes: String?) async -> ContractRow? {
        guard isConfigured else {
            print("[SupabaseService] createContract: not configured")
            return nil
        }
        let row = ContractRow(
            id: UUID().uuidString,
            eoi_id: eoiId,
            package_assignment_id: packageAssignmentId,
            build_id: nil,
            client_id: clientId,
            admin_id: adminId,
            contract_url: contractUrl,
            signed_contract_url: nil,
            status: contractUrl != nil ? "sent" : "draft",
            sent_at: contractUrl != nil ? ISO8601DateFormatter().string(from: .now) : nil,
            signed_at: nil,
            notes: notes,
            created_at: nil,
            updated_at: nil
        )
        do {
            try await client.from("contracts").insert(row).execute()
            print("[SupabaseService] createContract SUCCESS id=\(row.id)")
            return row
        } catch {
            print("[SupabaseService] createContract error: \(error)")
            return nil
        }
    }

    @discardableResult
    func updateContract(contractId: String, fields: [String: String]) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("contracts")
                .update(fields)
                .eq("id", value: contractId)
                .execute()
            print("[SupabaseService] updateContract SUCCESS id=\(contractId)")
            return true
        } catch {
            print("[SupabaseService] updateContract error: \(error)")
            return false
        }
    }

    func fetchContractsForClient(clientId: String) async -> [ContractRow] {
        guard isConfigured else { return [] }
        do {
            let rows: [ContractRow] = try await client.from("contracts")
                .select()
                .eq("client_id", value: clientId)
                .order("created_at", ascending: false)
                .execute()
                .value
            return rows
        } catch {
            print("[SupabaseService] fetchContractsForClient error: \(error)")
            return []
        }
    }

    func fetchAllContracts() async -> [ContractRow] {
        guard isConfigured else { return [] }
        do {
            let rows: [ContractRow] = try await client.from("contracts")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            return rows
        } catch {
            print("[SupabaseService] fetchAllContracts error: \(error)")
            return []
        }
    }

    func fetchContract(forEOI eoiId: String) async -> ContractRow? {
        guard isConfigured else { return nil }
        do {
            let rows: [ContractRow] = try await client.from("contracts")
                .select()
                .eq("eoi_id", value: eoiId)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch {
            print("[SupabaseService] fetchContract forEOI error: \(error)")
            return nil
        }
    }

    func uploadContractPDF(contractId: String, fileData: Data, fileName: String) async -> String? {
        guard isConfigured else { return nil }
        do {
            let path = "contracts/\(contractId)/\(fileName)"
            try await client.storage.from("contracts").upload(path: path, file: fileData, options: .init(contentType: "application/pdf"))
            let url = try client.storage.from("contracts").getPublicURL(path: path).absoluteString
            try await client.from("contracts")
                .update([
                    "contract_url": url,
                    "status": "sent",
                    "sent_at": ISO8601DateFormatter().string(from: .now)
                ])
                .eq("id", value: contractId)
                .execute()
            print("[SupabaseService] uploadContractPDF SUCCESS id=\(contractId)")
            return url
        } catch {
            print("[SupabaseService] uploadContractPDF error: \(error)")
            return nil
        }
    }

    @discardableResult
    func markContractSigned(contractId: String) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("contracts")
                .update([
                    "status": "signed",
                    "signed_at": ISO8601DateFormatter().string(from: .now)
                ])
                .eq("id", value: contractId)
                .execute()
            print("[SupabaseService] markContractSigned SUCCESS id=\(contractId)")
            return true
        } catch {
            print("[SupabaseService] markContractSigned error: \(error)")
            return false
        }
    }

    // MARK: - Invoices (Pipeline)

    @discardableResult
    func createInvoice(contractId: String?, clientId: String, adminId: String, invoiceNumber: String?, description: String?, amount: Double?, packagePrice: Double?, dueDate: String?, notes: String?) async -> InvoiceRow? {
        guard isConfigured else {
            print("[SupabaseService] createInvoice: not configured")
            return nil
        }
        let row = InvoiceRow(
            id: UUID().uuidString,
            contract_id: contractId,
            client_id: clientId,
            admin_id: adminId,
            invoice_number: invoiceNumber,
            description: description,
            amount: amount,
            package_price: packagePrice,
            status: "sent",
            due_date: dueDate,
            paid_at: nil,
            invoice_url: nil,
            notes: notes,
            created_at: nil,
            updated_at: nil
        )
        do {
            try await client.from("invoices").insert(row).execute()
            print("[SupabaseService] createInvoice SUCCESS id=\(row.id)")
            return row
        } catch {
            print("[SupabaseService] createInvoice error: \(error)")
            return nil
        }
    }

    @discardableResult
    func updateInvoice(invoiceId: String, fields: [String: String]) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("invoices")
                .update(fields)
                .eq("id", value: invoiceId)
                .execute()
            print("[SupabaseService] updateInvoice SUCCESS id=\(invoiceId)")
            return true
        } catch {
            print("[SupabaseService] updateInvoice error: \(error)")
            return false
        }
    }

    func fetchInvoicesForClient(clientId: String) async -> [InvoiceRow] {
        guard isConfigured else { return [] }
        do {
            let rows: [InvoiceRow] = try await client.from("invoices")
                .select()
                .eq("client_id", value: clientId)
                .order("created_at", ascending: false)
                .execute()
                .value
            return rows
        } catch {
            print("[SupabaseService] fetchInvoicesForClient error: \(error)")
            return []
        }
    }

    func fetchAllInvoices() async -> [InvoiceRow] {
        guard isConfigured else { return [] }
        do {
            let rows: [InvoiceRow] = try await client.from("invoices")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            return rows
        } catch {
            print("[SupabaseService] fetchAllInvoices error: \(error)")
            return []
        }
    }

    func fetchInvoice(forContract contractId: String) async -> InvoiceRow? {
        guard isConfigured else { return nil }
        do {
            let rows: [InvoiceRow] = try await client.from("invoices")
                .select()
                .eq("contract_id", value: contractId)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch {
            print("[SupabaseService] fetchInvoice forContract error: \(error)")
            return nil
        }
    }

    @discardableResult
    func markInvoicePaid(invoiceId: String) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("invoices")
                .update([
                    "status": "paid",
                    "paid_at": ISO8601DateFormatter().string(from: .now)
                ])
                .eq("id", value: invoiceId)
                .execute()
            print("[SupabaseService] markInvoicePaid SUCCESS id=\(invoiceId)")
            return true
        } catch {
            print("[SupabaseService] markInvoicePaid error: \(error)")
            return false
        }
    }

    /// Installs a generic AnyAction realtime listener on `table` in the `public` schema
    /// and forwards each event to `onUpdate` on the MainActor.
    private func installChannel(name: String, table: String, onUpdate: @escaping @Sendable () -> Void) {
        guard isConfigured else { return }
        let channel = client.realtimeV2.channel(name)
        realtimeChannels.append(channel)
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: table
        )
        Task {
            try? await channel.subscribeWithError()
            for await _ in changes {
                await MainActor.run { onUpdate() }
            }
        }
    }

    func subscribeToCatalogChanges(onUpdate: @escaping @Sendable () -> Void) {
        // All catalog tables that power the Stage-1 / Stage-2 configurator.
        // Without these an admin edit won't appear on client devices until relaunch.
        let tables = [
            "colour_categories",
            "spec_items",
            "spec_categories",
            "spec_to_colour_mapping",
            "spec_range_tiers",
            "spec_item_images",
            "homefast_schemes"
        ]
        for table in tables {
            installChannel(name: "\(table)_sync", table: table, onUpdate: onUpdate)
        }
    }

    /// Milestones, reminders, and range-upgrade requests — admin-driven changes
    /// that need to appear on client devices without a restart.
    func subscribeToBuildExtras(onUpdate: @escaping @Sendable () -> Void) {
        let tables = [
            "build_milestones",
            "build_reminders",
            "build_range_upgrade_requests"
        ]
        for table in tables {
            installChannel(name: "\(table)_sync", table: table, onUpdate: onUpdate)
        }
    }

    /// Finance + contract mutations that the client must see live.
    func subscribeToFinanceChanges(onUpdate: @escaping @Sendable () -> Void) {
        let tables = [
            "invoices",
            "contracts",
            "contract_signatures",
            "eoi_submissions"
        ]
        for table in tables {
            installChannel(name: "\(table)_sync", table: table, onUpdate: onUpdate)
        }
    }

    // MARK: - Stocklist

    func fetchStocklistEstates() async -> [StocklistEstateRow] {
        guard isConfigured else { return [] }
        do {
            let rows: [StocklistEstateRow] = try await client.from("stocklist_estates")
                .select()
                .eq("is_active", value: true)
                .order("sort_order")
                .execute().value
            return rows
        } catch {
            print("[SupabaseService] fetchStocklistEstates error: \(error)")
            return []
        }
    }

    func fetchStocklistItems(estateId: String? = nil) async -> [StocklistItemRow] {
        guard isConfigured else { return [] }
        do {
            var query = client.from("stocklist_items").select()
            if let estateId = estateId {
                query = query.eq("estate_id", value: estateId)
            }
            let rows: [StocklistItemRow] = try await query.order("sort_order").execute().value
            return rows
        } catch {
            print("[SupabaseService] fetchStocklistItems error: \(error)")
            return []
        }
    }

    func fetchStocklistAltDesigns(itemIds: [String]) async -> [StocklistAltDesignRow] {
        guard isConfigured else { return [] }
        guard !itemIds.isEmpty else { return [] }
        do {
            let rows: [StocklistAltDesignRow] = try await client.from("stocklist_alternative_designs")
                .select()
                .in("stocklist_item_id", values: itemIds)
                .execute().value
            return rows
        } catch {
            print("[SupabaseService] fetchStocklistAltDesigns error: \(error)")
            return []
        }
    }

    @discardableResult
    func upsertStocklistEstate(_ row: StocklistEstateRow) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("stocklist_estates").upsert(row, onConflict: "id").execute()
            return true
        } catch {
            print("[SupabaseService] upsertStocklistEstate error: \(error)")
            return false
        }
    }

    @discardableResult
    func deleteStocklistEstate(id: String) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("stocklist_estates").delete().eq("id", value: id).execute()
            return true
        } catch {
            print("[SupabaseService] deleteStocklistEstate error: \(error)")
            return false
        }
    }

    @discardableResult
    func upsertStocklistItem(_ row: StocklistItemRow) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("stocklist_items").upsert(row, onConflict: "id").execute()
            return true
        } catch {
            print("[SupabaseService] upsertStocklistItem error: \(error)")
            return false
        }
    }

    @discardableResult
    func deleteStocklistItem(id: String) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("stocklist_items").delete().eq("id", value: id).execute()
            return true
        } catch {
            print("[SupabaseService] deleteStocklistItem error: \(error)")
            return false
        }
    }

    @discardableResult
    func submitDesignEnquiry(_ row: DesignEnquiryInsertRow) async -> Bool {
        guard isConfigured else { return false }
        do {
            try await client.from("design_enquiries").insert(row).execute()
            return true
        } catch {
            print("[SupabaseService] submitDesignEnquiry error: \(error)")
            return false
        }
    }
}
