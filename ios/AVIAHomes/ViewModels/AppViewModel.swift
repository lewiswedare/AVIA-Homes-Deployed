import SwiftUI
import Supabase

extension Notification.Name {
    /// Posted when a realtime event or push notification indicates the
    /// currently-open build needs a fresh load. userInfo contains "buildId".
    static let aviaBuildNeedsRefresh = Notification.Name("aviaBuildNeedsRefresh")
    /// Posted when incoming pushes tell us the open colour picker should reload.
    static let aviaColoursNeedRefresh = Notification.Name("aviaColoursNeedRefresh")
}

@Observable
class AppViewModel {
    var authService = AuthService()
    var notificationService = NotificationService()
    var messagingService = MessagingService()
    var pushManager = PushNotificationManager()
    var isLoading = false
    var currentUser: ClientUser = .empty
    var buildStages: [BuildStage] = []
    var documents: [ClientDocument] = []
    var requests: [ServiceRequest] = []
    var scheduleItems: [ScheduleItem] = []
    var allClientBuilds: [ClientBuild] = []
    var packageAssignments: [PackageAssignment] = []

    var cachedUsers: [ClientUser] = []
    var pendingSpecReviews: [BuildSpecSelection] = []
    var buildMilestones: [String: [BuildMilestone]] = [:]
    var buildReminders: [BuildReminder] = []

    // Tracks which build the user is actively viewing so realtime callbacks
    // can refresh the right detail view (Stage-2 colour picker, etc).
    var activeBuildId: String?

    // Guards setupRealtimeSubscriptions() against being installed repeatedly
    // by multiple role-branch views each calling loadUserData().
    private var realtimeInstalled = false

    var allHomeDesigns: [HomeDesign] = []
    var allPackages: [HouseLandPackage] = []
    var allBlogPosts: [BlogPost] = []
    var allLandEstates: [LandEstate] = []
    var allFacades: [Facade] = []
    var contentLoaded: Bool = false
    var catalogManager = CatalogDataManager.shared

    var isAuthenticated: Bool { authService.isAuthenticated }
    var hasCompletedProfile: Bool { authService.hasCompletedProfile }
    var currentRole: UserRole { authService.currentRole }

    var totalBadgeCount: Int {
        notificationService.unreadCount + messagingService.totalUnreadCount
    }

    var clientHasBuild: Bool {
        guard currentRole == .client else { return true }
        return !clientBuildsForCurrentUser.isEmpty
    }

    var upcomingScheduleItems: [ScheduleItem] {
        scheduleItems
            .filter { !$0.isPast }
            .sorted { $0.date < $1.date }
    }

    var nextScheduleItem: ScheduleItem? {
        upcomingScheduleItems.first
    }

    init() {
        if let savedUser = authService.loadUserProfile() {
            currentUser = savedUser
        }
    }

    func restoreSession() async {
        if let userId = await authService.restoreSession() {
            if let profile = await SupabaseService.shared.fetchProfile(userId: userId) {
                currentUser = profile
                authService.updateRole(profile.role)
                authService.saveUserProfile(profile)
                if profile.profileCompleted {
                    authService.completeProfile()
                } else {
                    authService.hasCompletedProfile = false
                    UserDefaults.standard.set(false, forKey: "avia_profile_completed")
                }
            }
            authService.finishRestoring()
            await fetchAllUsersFromSupabase()
            await loadUserData()

            // One-time demo data cleanup — runs only once
            let demoCleanedKey = "avia_demo_docs_cleared_v1"
            if !UserDefaults.standard.bool(forKey: demoCleanedKey) && currentRole.isAnyStaffRole {
                let cleared = await SupabaseService.shared.deleteAllDocuments()
                if cleared {
                    UserDefaults.standard.set(true, forKey: demoCleanedKey)
                    print("[AppViewModel] Demo documents cleared")
                }
            }
        } else {
            authService.finishRestoring()
        }
    }

    var currentBuildStage: BuildStage? {
        if !buildStages.isEmpty {
            return buildStages.first { $0.status == .inProgress }
        }
        return clientBuildsForCurrentUser.first?.currentStage
    }

    var overallProgress: Double {
        guard !buildStages.isEmpty else {
            return clientBuildsForCurrentUser.first?.overallProgress ?? 0
        }
        let total = Double(buildStages.count)
        let completed = Double(buildStages.filter { $0.status == .completed }.count)
        let inProgress = buildStages.first { $0.status == .inProgress }
        let progressContribution = (inProgress?.progress ?? 0) / total
        return (completed / total) + progressContribution
    }

    var openRequestCount: Int {
        requests.filter { $0.status != .resolved }.count
    }

    var newDocumentCount: Int {
        documents.filter { $0.isNew }.count
    }

    var clientBuildsForCurrentUser: [ClientBuild] {
        switch currentRole {
        case .pending:
            return []
        case .client:
            return allClientBuilds.filter { $0.hasClient(id: currentUser.id) }
        case .staff:
            return allClientBuilds.filter { $0.assignedStaffId == currentUser.id }
        case .preConstruction:
            return allClientBuilds.filter { $0.preConstructionStaffId == currentUser.id }
        case .buildingSupport:
            return allClientBuilds.filter { $0.buildingSupportStaffId == currentUser.id }
        case .admin, .salesAdmin, .superAdmin:
            return allClientBuilds
        case .partner, .salesPartner:
            return allClientBuilds.filter { $0.salesPartnerId == currentUser.id }
        }
    }

    var activeClientCount: Int {
        clientBuildsForCurrentUser.count
    }

    var totalBuildsInProgress: Int {
        clientBuildsForCurrentUser.filter { $0.currentStage != nil }.count
    }

    func syncBuildStagesForCurrentUser() {
        if currentRole == .client, let myBuild = clientBuildsForCurrentUser.first {
            buildStages = myBuild.buildStages
        }
    }

    var unreadReminders: [BuildReminder] {
        buildReminders.filter { !$0.isRead }
    }

    var upcomingReminders: [BuildReminder] {
        buildReminders
            .filter { !$0.isRead }
            .sorted { ($0.reminderDate ?? .distantFuture) < ($1.reminderDate ?? .distantFuture) }
    }

    func milestonesForBuild(_ buildId: String) -> [BuildMilestone] {
        buildMilestones[buildId] ?? []
    }

    var nextMilestoneForCurrentUser: BuildMilestone? {
        let builds = clientBuildsForCurrentUser
        for build in builds {
            if let milestones = buildMilestones[build.id] {
                if let next = milestones.first(where: { $0.status != .completed }) {
                    return next
                }
            }
        }
        return nil
    }

    var actionRequiredMilestones: [BuildMilestone] {
        let builds = clientBuildsForCurrentUser
        return builds.flatMap { build in
            (buildMilestones[build.id] ?? []).filter { $0.isActionRequired }
        }
    }

    func loadUserData() async {
        await loadContentFromSupabase()
        await fetchAllUsersFromSupabase()
        await loadBuildsFromSupabase()
        await loadAssignmentsFromSupabase()
        await loadRequestsFromSupabase()
        await loadDocumentsFromSupabase()
        await loadScheduleItemsFromSupabase()
        await loadPendingSpecReviews()
        await loadMilestonesForCurrentBuilds()
        await loadRemindersForCurrentUser()
        await notificationService.loadNotifications(for: currentUser.id)
        await messagingService.loadConversations(for: currentUser.id)
        notificationService.onNotificationReceived = { [weak self] notif in
            guard let self else { return }
            self.pushManager.scheduleLocalNotification(title: notif.pushTitle, body: notif.pushBody, identifier: notif.id)
            self.pushManager.updateBadgeCount(self.totalBadgeCount)
        }
        notificationService.subscribeToNotifications(for: currentUser.id)
        setupRealtimeSubscriptions()
        await pushManager.checkPermission()
        pushManager.registerUser(currentUser.id)
        if pushManager.isAuthorized {
            await pushManager.saveTokenToServer(userId: currentUser.id)
        }
        pushManager.updateBadgeCount(totalBadgeCount)
        syncBuildStagesForCurrentUser()
    }

    /// Refetches every remote data source in parallel. Use on foreground,
    /// on pull-to-refresh, and after push notification taps.
    func refreshAllData() async {
        guard !currentUser.id.isEmpty else { return }
        async let a: () = loadContentFromSupabase()
        async let b: () = fetchAllUsersFromSupabase()
        async let c: () = loadBuildsFromSupabase()
        async let d: () = loadAssignmentsFromSupabase()
        async let e: () = loadRequestsFromSupabase()
        async let f: () = loadDocumentsFromSupabase()
        async let g: () = loadScheduleItemsFromSupabase()
        async let h: () = loadPendingSpecReviews()
        async let i: () = loadMilestonesForCurrentBuilds()
        async let j: () = loadRemindersForCurrentUser()
        async let k: () = notificationService.loadNotifications(for: currentUser.id)
        async let l: () = messagingService.loadConversations(for: currentUser.id)
        async let m: () = catalogManager.loadAll()
        _ = await (a, b, c, d, e, f, g, h, i, j, k, l, m)
        syncBuildStagesForCurrentUser()
    }

    /// Called from AVIAHomesApp when the scene becomes active.
    /// Tears down realtime channels (they'll have been broken by the OS while backgrounded),
    /// rebuilds them from scratch, and does a full refetch so the UI is never stale.
    func handleForeground() async {
        guard !currentUser.id.isEmpty else { return }
        await SupabaseService.shared.removeAllChannels()
        realtimeInstalled = false
        setupRealtimeSubscriptions()
        notificationService.subscribeToNotifications(for: currentUser.id)
        await refreshAllData()
    }

    /// Called from AVIAHomesApp when the scene goes to background.
    /// Cleanly removes all realtime channels so they can be rebuilt on foreground.
    func handleBackground() async {
        await SupabaseService.shared.removeAllChannels()
        realtimeInstalled = false
    }

    func fetchAllUsersFromSupabase() async {
        let users = await SupabaseService.shared.fetchAllProfiles()
        if !users.isEmpty {
            cachedUsers = users
        }
    }

    func loadBuildsFromSupabase() async {
        let builds = await SupabaseService.shared.fetchBuilds()
        allClientBuilds = builds
        syncBuildStagesForCurrentUser()
    }

    func loadAssignmentsFromSupabase() async {
        let assignments = await SupabaseService.shared.fetchPackageAssignments()
        packageAssignments = assignments
    }

    func refreshBuildsAndAssignments() async {
        await loadBuildsFromSupabase()
        await loadAssignmentsFromSupabase()
    }

    func loadRequestsFromSupabase() async {
        let reqs: [ServiceRequest]
        if currentRole == .client {
            reqs = await SupabaseService.shared.fetchServiceRequests(clientId: currentUser.id)
        } else {
            reqs = await SupabaseService.shared.fetchServiceRequests()
        }
        requests = reqs
    }

    func loadContentFromSupabase() async {
        async let designsTask = SupabaseService.shared.fetchHomeDesigns()
        async let packagesTask = SupabaseService.shared.fetchHouseLandPackages()
        async let postsTask = SupabaseService.shared.fetchBlogPosts()
        async let estatesTask = SupabaseService.shared.fetchLandEstates()
        async let facadesTask = SupabaseService.shared.fetchFacades()
        async let catalogTask: () = catalogManager.loadAll()

        let (designs, packages, posts, estates, facades, _) = await (designsTask, packagesTask, postsTask, estatesTask, facadesTask, catalogTask)

        allHomeDesigns = designs
        allPackages = packages
        allBlogPosts = posts
        allLandEstates = estates
        allFacades = facades

        contentLoaded = true
    }

    func loadDocumentsFromSupabase() async {
        guard !currentUser.id.isEmpty else { return }
        if currentRole.isAnyStaffRole {
            let docs = await SupabaseService.shared.fetchAllDocuments()
            documents = docs
        } else {
            let docs = await SupabaseService.shared.fetchDocuments(clientId: currentUser.id)
            documents = docs
        }
    }

    func loadPendingSpecReviews() async {
        guard currentRole.isAnyStaffRole else { return }
        let reviews = await SupabaseService.shared.fetchAllPendingSpecReviews()
        pendingSpecReviews = reviews
    }

    func loadScheduleItemsFromSupabase() async {
        guard !currentUser.id.isEmpty else { return }
        let items = await SupabaseService.shared.fetchScheduleItems(clientId: currentUser.id)
        scheduleItems = items
    }

    func loadMilestonesForCurrentBuilds() async {
        let builds = clientBuildsForCurrentUser
        var result: [String: [BuildMilestone]] = [:]
        for build in builds {
            let milestones = await SupabaseService.shared.fetchMilestonesForBuild(buildId: build.id)
            result[build.id] = milestones
        }
        buildMilestones = result
    }

    func loadRemindersForCurrentUser() async {
        guard !currentUser.id.isEmpty else { return }
        if currentRole == .client {
            buildReminders = await SupabaseService.shared.fetchRemindersForClient(clientId: currentUser.id)
        } else if currentRole.isAnyStaffRole {
            var allReminders: [BuildReminder] = []
            for build in clientBuildsForCurrentUser {
                let reminders = await SupabaseService.shared.fetchRemindersForBuild(buildId: build.id)
                allReminders.append(contentsOf: reminders)
            }
            buildReminders = allReminders
        }
    }

    func refreshMilestonesAndReminders() async {
        await loadMilestonesForCurrentBuilds()
        await loadRemindersForCurrentUser()
    }

    func addMilestone(_ milestone: BuildMilestone) {
        var current = buildMilestones[milestone.buildId] ?? []
        current.append(milestone)
        buildMilestones[milestone.buildId] = current
        Task {
            await SupabaseService.shared.upsertMilestone(milestone)
            await loadMilestonesForCurrentBuilds()
        }
    }

    func updateMilestone(_ milestone: BuildMilestone) {
        if var current = buildMilestones[milestone.buildId],
           let idx = current.firstIndex(where: { $0.id == milestone.id }) {
            current[idx] = milestone
            buildMilestones[milestone.buildId] = current
        }
        Task {
            await SupabaseService.shared.upsertMilestone(milestone)
            await loadMilestonesForCurrentBuilds()
        }
    }

    func completeMilestone(id: String, buildId: String) {
        if var current = buildMilestones[buildId],
           let idx = current.firstIndex(where: { $0.id == id }) {
            let old = current[idx]
            let updated = BuildMilestone(
                id: old.id,
                buildStageId: old.buildStageId,
                buildId: old.buildId,
                title: old.title,
                description: old.description,
                dueDate: old.dueDate,
                completedAt: .now,
                status: .completed,
                requiresClientAction: old.requiresClientAction,
                clientActionDescription: old.clientActionDescription,
                createdAt: old.createdAt
            )
            current[idx] = updated
            buildMilestones[buildId] = current
        }
        Task {
            await SupabaseService.shared.completeMilestone(id: id)
        }
    }

    func deleteMilestone(id: String, buildId: String) {
        if var current = buildMilestones[buildId] {
            current.removeAll { $0.id == id }
            buildMilestones[buildId] = current
        }
        Task {
            await SupabaseService.shared.deleteMilestone(id: id)
        }
    }

    func addReminder(_ reminder: BuildReminder) {
        buildReminders.append(reminder)
        Task {
            await SupabaseService.shared.upsertReminder(reminder)
        }
    }

    func markReminderRead(id: String) {
        if let idx = buildReminders.firstIndex(where: { $0.id == id }) {
            buildReminders[idx].isRead = true
        }
        Task {
            await SupabaseService.shared.markReminderRead(id: id)
        }
    }

    func deleteReminder(id: String) {
        buildReminders.removeAll { $0.id == id }
        Task {
            await SupabaseService.shared.deleteReminder(id: id)
        }
    }

    private func setupRealtimeSubscriptions() {
        // Hard guard against duplicate installs. ContentView mounts multiple
        // role-branch tab views each calling loadUserData(); without this
        // guard we'd stack dozens of duplicate channels per session.
        guard !realtimeInstalled else { return }
        realtimeInstalled = true

        SupabaseService.shared.subscribeToBuildChanges { [weak self] in
            guard let self else { return }
            Task { await self.loadBuildsFromSupabase() }
        }
        SupabaseService.shared.subscribeToAssignmentChanges { [weak self] in
            guard let self else { return }
            Task { await self.loadAssignmentsFromSupabase() }
        }
        SupabaseService.shared.subscribeToRequestChanges { [weak self] in
            guard let self else { return }
            Task { await self.loadRequestsFromSupabase() }
        }
        SupabaseService.shared.subscribeToProfileChanges(userId: currentUser.id) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                if let profile = await SupabaseService.shared.fetchProfile(userId: self.currentUser.id) {
                    self.currentUser = profile
                    self.authService.updateRole(profile.role)
                    self.authService.saveUserProfile(profile)
                }
            }
        }
        SupabaseService.shared.subscribeToDocumentChanges { [weak self] in
            guard let self else { return }
            Task { await self.loadDocumentsFromSupabase() }
        }
        SupabaseService.shared.subscribeToBuildTableChanges { [weak self] in
            guard let self else { return }
            Task { await self.loadBuildsFromSupabase() }
        }
        SupabaseService.shared.subscribeToMessageChanges { [weak self] in
            guard let self else { return }
            Task { await self.messagingService.loadConversations(for: self.currentUser.id) }
        }
        SupabaseService.shared.subscribeToSpecSelectionChanges { [weak self] in
            guard let self else { return }
            Task {
                await self.loadPendingSpecReviews()
                // Also refresh the active build so the Stage-1 view updates live.
                if let active = self.activeBuildId {
                    NotificationCenter.default.post(
                        name: .aviaBuildNeedsRefresh,
                        object: nil,
                        userInfo: ["buildId": active]
                    )
                }
            }
        }
        SupabaseService.shared.subscribeToColourSelectionChanges { [weak self] in
            guard let self else { return }
            Task {
                // Keep the list fresh.
                await self.loadBuildsFromSupabase()
                // Route to the active build so the Stage-2 colour picker
                // reflects admin approvals / cross-device edits live.
                if let active = self.activeBuildId {
                    NotificationCenter.default.post(
                        name: .aviaBuildNeedsRefresh,
                        object: nil,
                        userInfo: ["buildId": active]
                    )
                }
            }
        }
        SupabaseService.shared.subscribeToScheduleChanges(clientId: currentUser.id) { [weak self] in
            guard let self else { return }
            Task { await self.loadScheduleItemsFromSupabase() }
        }
        SupabaseService.shared.subscribeToCatalogChanges { [weak self] in
            guard let self else { return }
            Task {
                await self.catalogManager.loadAll()
                await self.loadContentFromSupabase()
            }
        }
        // Cross-user finance/contracts changes (invoices, contracts, eoi).
        SupabaseService.shared.subscribeToFinanceChanges { [weak self] in
            guard let self else { return }
            Task { await self.loadBuildsFromSupabase() }
        }
        // Milestones / reminders / upgrade requests — admin-driven changes
        // that must show up on the client without a restart.
        SupabaseService.shared.subscribeToBuildExtras { [weak self] in
            guard let self else { return }
            Task {
                await self.loadMilestonesForCurrentBuilds()
                await self.loadRemindersForCurrentUser()
                await self.loadPendingSpecReviews()
            }
        }
    }

    func signIn(email: String, password: String) async -> Bool {
        let success = await authService.signIn(email: email, password: password)
        if success {
            if let userId = authService.supabaseUserId {
                if let profile = await SupabaseService.shared.fetchProfile(userId: userId) {
                    currentUser = profile
                    authService.updateRole(profile.role)
                    authService.saveUserProfile(profile)
                    if profile.profileCompleted {
                        authService.completeProfile()
                    }
                } else {
                    var user = ClientUser.empty
                    user.id = userId
                    user.email = email
                    user.role = .client
                    currentUser = user
                }
            } else if let saved = authService.loadUserProfile() {
                currentUser = saved
                authService.updateRole(saved.role)
            } else {
                var user = ClientUser.empty
                user.id = UUID().uuidString
                user.email = email
                user.role = .client
                currentUser = user
            }
            await loadUserData()
        }
        return success
    }

    func handleSignUp(email: String) async {
        var user = ClientUser.empty
        let rawId = authService.supabaseUserId ?? UUID().uuidString
        user.id = rawId.lowercased()
        user.email = email
        user.role = .client
        user.profileCompleted = false
        currentUser = user
        authService.updateRole(.client)
        authService.saveUserProfile(user)
        print("[AppViewModel] handleSignUp: creating initial profile for id=\(user.id), email=\(email)")
        try? await Task.sleep(for: .seconds(0.5))
        let success = await SupabaseService.shared.upsertProfile(user)
        if !success {
            print("[AppViewModel] handleSignUp: first upsert failed, retrying in 2s...")
            try? await Task.sleep(for: .seconds(2))
            let retrySuccess = await SupabaseService.shared.upsertProfile(user)
            if !retrySuccess {
                print("[AppViewModel] handleSignUp: RETRY ALSO FAILED for id=\(user.id)")
            }
        }
    }

    func completeProfileSetup(user: ClientUser) async {
        var updatedUser = user
        if let supaId = authService.supabaseUserId {
            updatedUser.id = supaId.lowercased()
        }
        updatedUser.role = .client
        updatedUser.profileCompleted = true
        currentUser = updatedUser
        authService.updateRole(.client)
        authService.completeProfile()
        authService.saveUserProfile(updatedUser)
        print("[AppViewModel] completeProfileSetup: id=\(updatedUser.id), name=\(updatedUser.firstName) \(updatedUser.lastName), phone=\(updatedUser.phone), address=\(updatedUser.address), email=\(updatedUser.email)")

        await authService.updateUserMetadata(
            firstName: updatedUser.firstName,
            lastName: updatedUser.lastName,
            phone: updatedUser.phone
        )

        let directSuccess = await SupabaseService.shared.updateProfileFields(
            userId: updatedUser.id,
            firstName: updatedUser.firstName,
            lastName: updatedUser.lastName,
            phone: updatedUser.phone,
            address: updatedUser.address,
            email: updatedUser.email,
            role: updatedUser.role.rawValue
        )
        if directSuccess {
            print("[AppViewModel] completeProfileSetup: direct update SUCCESS")
        } else {
            print("[AppViewModel] completeProfileSetup: direct update failed, trying full upsert...")
            let upsertSuccess = await SupabaseService.shared.upsertProfile(updatedUser)
            if !upsertSuccess {
                print("[AppViewModel] completeProfileSetup: upsert also failed, retrying in 2s...")
                try? await Task.sleep(for: .seconds(2))
                let retrySuccess = await SupabaseService.shared.upsertProfile(updatedUser)
                if !retrySuccess {
                    print("[AppViewModel] completeProfileSetup: RETRY ALSO FAILED for id=\(updatedUser.id)")
                }
            }
        }
    }

    func updateProfile(user: ClientUser) async {
        var normalizedUser = user
        if let supaId = authService.supabaseUserId {
            normalizedUser.id = supaId.lowercased()
        }
        currentUser = normalizedUser
        authService.saveUserProfile(normalizedUser)
        print("[AppViewModel] updateProfile: id=\(normalizedUser.id), name=\(normalizedUser.firstName) \(normalizedUser.lastName)")
        let success = await SupabaseService.shared.upsertProfile(normalizedUser)
        if !success {
            print("[AppViewModel] updateProfile: first upsert failed, retrying...")
            try? await Task.sleep(for: .seconds(1))
            let retrySuccess = await SupabaseService.shared.upsertProfile(normalizedUser)
            if !retrySuccess {
                print("[AppViewModel] updateProfile: RETRY ALSO FAILED for id=\(normalizedUser.id)")
            }
        }
    }

    var allRegisteredUsers: [ClientUser] {
        cachedUsers
    }

    func assignRole(_ role: UserRole, to userId: String) {
        if let cacheIdx = cachedUsers.firstIndex(where: { $0.id == userId }) {
            cachedUsers[cacheIdx].role = role
        }
        if userId == currentUser.id {
            currentUser.role = role
            authService.updateRole(role)
            authService.saveUserProfile(currentUser)
        }
        Task {
            await SupabaseService.shared.updateProfileField(userId: userId, fields: ["role": role.rawValue])
            await fetchAllUsersFromSupabase()
            await notificationService.createNotification(
                recipientId: userId,
                senderId: currentUser.id,
                senderName: currentUser.fullName,
                type: .roleAssigned,
                title: "Role Updated",
                message: "Your role has been updated to \(role.rawValue)",
                referenceType: "profile"
            )
        }
    }

    func signOut() {
        Task {
            await pushManager.removeToken(userId: currentUser.id)
            await SupabaseService.shared.removeAllChannels()
        }
        authService.signOut()
        currentUser = .empty
        cachedUsers = []
        allClientBuilds = []
        packageAssignments = []
        requests = []
        documents = []
        scheduleItems = []
        buildStages = []
        pendingSpecReviews = []
        buildMilestones = [:]
        buildReminders = []
        allHomeDesigns = []
        allPackages = []
        allBlogPosts = []
        allLandEstates = []
        allFacades = []
        contentLoaded = false
        notificationService.notifications = []
        messagingService.conversations = []
        messagingService.currentMessages = []
        pushManager.updateBadgeCount(0)
    }

    func assignBuildToClient(buildId: String, clientId: String) {
        guard let index = allClientBuilds.firstIndex(where: { $0.id == buildId }) else { return }
        guard !clientId.isEmpty else { return }
        let client = allRegisteredUsers.first { $0.id == clientId } ?? .empty
        guard !client.id.isEmpty else { return }
        let oldBuild = allClientBuilds[index]
        let updated = ClientBuild(
            id: oldBuild.id,
            client: client,
            homeDesign: oldBuild.homeDesign,
            lotNumber: oldBuild.lotNumber,
            estate: oldBuild.estate,
            contractDate: oldBuild.contractDate,
            buildStages: oldBuild.buildStages,
            assignedStaffId: oldBuild.assignedStaffId,
            salesPartnerId: oldBuild.salesPartnerId,
            isCustom: oldBuild.isCustom,
            selectedFacadeId: oldBuild.selectedFacadeId,
            customBedrooms: oldBuild.customBedrooms,
            customBathrooms: oldBuild.customBathrooms,
            customGarages: oldBuild.customGarages,
            customSquareMeters: oldBuild.customSquareMeters,
            customStoreys: oldBuild.customStoreys,
            additionalClients: oldBuild.additionalClients,
            preConstructionStaffId: oldBuild.preConstructionStaffId,
            buildingSupportStaffId: oldBuild.buildingSupportStaffId,
            handoverTriggeredAt: oldBuild.handoverTriggeredAt,
            buildStatus: oldBuild.buildStatus,
            specTier: oldBuild.specTier
        )
        allClientBuilds[index] = updated
        syncBuildStagesForCurrentUser()
        Task {
            let success = await SupabaseService.shared.upsertBuild(updated)
            if success {
                await refreshBuildsAndAssignments()
                if !clientId.isEmpty {
                    await notificationService.createNotification(
                        recipientId: clientId,
                        senderId: currentUser.id,
                        senderName: currentUser.fullName,
                        type: .buildUpdate,
                        title: "Build Assigned",
                        message: "You have been assigned to a new build",
                        referenceId: buildId,
                        referenceType: "build"
                    )
                }
            }
        }
    }

    func addClientToBuild(buildId: String, clientId: String) {
        guard let index = allClientBuilds.firstIndex(where: { $0.id == buildId }) else { return }
        guard !clientId.isEmpty else { return }
        let oldBuild = allClientBuilds[index]
        guard !oldBuild.hasClient(id: clientId) else { return }
        let newClient = allRegisteredUsers.first { $0.id == clientId } ?? .empty
        guard !newClient.id.isEmpty else { return }
        var additional = oldBuild.additionalClients
        additional.append(newClient)
        let updated = ClientBuild(
            id: oldBuild.id,
            client: oldBuild.client,
            homeDesign: oldBuild.homeDesign,
            lotNumber: oldBuild.lotNumber,
            estate: oldBuild.estate,
            contractDate: oldBuild.contractDate,
            buildStages: oldBuild.buildStages,
            assignedStaffId: oldBuild.assignedStaffId,
            salesPartnerId: oldBuild.salesPartnerId,
            isCustom: oldBuild.isCustom,
            selectedFacadeId: oldBuild.selectedFacadeId,
            customBedrooms: oldBuild.customBedrooms,
            customBathrooms: oldBuild.customBathrooms,
            customGarages: oldBuild.customGarages,
            customSquareMeters: oldBuild.customSquareMeters,
            customStoreys: oldBuild.customStoreys,
            additionalClients: additional,
            preConstructionStaffId: oldBuild.preConstructionStaffId,
            buildingSupportStaffId: oldBuild.buildingSupportStaffId,
            handoverTriggeredAt: oldBuild.handoverTriggeredAt,
            buildStatus: oldBuild.buildStatus,
            specTier: oldBuild.specTier
        )
        allClientBuilds[index] = updated
        syncBuildStagesForCurrentUser()
        Task {
            let success = await SupabaseService.shared.upsertBuild(updated)
            if success {
                await refreshBuildsAndAssignments()
            }
        }
    }

    func removeClientFromBuild(buildId: String, clientId: String) {
        guard let index = allClientBuilds.firstIndex(where: { $0.id == buildId }) else { return }
        let oldBuild = allClientBuilds[index]
        let updated: ClientBuild
        if oldBuild.client.id == clientId {
            let remaining = oldBuild.additionalClients
            let newPrimary = remaining.first ?? .empty
            let newAdditional = remaining.isEmpty ? [] : Array(remaining.dropFirst())
            updated = ClientBuild(
                id: oldBuild.id,
                client: newPrimary,
                homeDesign: oldBuild.homeDesign,
                lotNumber: oldBuild.lotNumber,
                estate: oldBuild.estate,
                contractDate: oldBuild.contractDate,
                buildStages: oldBuild.buildStages,
                assignedStaffId: oldBuild.assignedStaffId,
                salesPartnerId: oldBuild.salesPartnerId,
                isCustom: oldBuild.isCustom,
                selectedFacadeId: oldBuild.selectedFacadeId,
                customBedrooms: oldBuild.customBedrooms,
                customBathrooms: oldBuild.customBathrooms,
                customGarages: oldBuild.customGarages,
                customSquareMeters: oldBuild.customSquareMeters,
                customStoreys: oldBuild.customStoreys,
                additionalClients: newAdditional,
                preConstructionStaffId: oldBuild.preConstructionStaffId,
                buildingSupportStaffId: oldBuild.buildingSupportStaffId,
                handoverTriggeredAt: oldBuild.handoverTriggeredAt,
                buildStatus: oldBuild.buildStatus,
                specTier: oldBuild.specTier
            )
        } else {
            let newAdditional = oldBuild.additionalClients.filter { $0.id != clientId }
            updated = ClientBuild(
                id: oldBuild.id,
                client: oldBuild.client,
                homeDesign: oldBuild.homeDesign,
                lotNumber: oldBuild.lotNumber,
                estate: oldBuild.estate,
                contractDate: oldBuild.contractDate,
                buildStages: oldBuild.buildStages,
                assignedStaffId: oldBuild.assignedStaffId,
                salesPartnerId: oldBuild.salesPartnerId,
                isCustom: oldBuild.isCustom,
                selectedFacadeId: oldBuild.selectedFacadeId,
                customBedrooms: oldBuild.customBedrooms,
                customBathrooms: oldBuild.customBathrooms,
                customGarages: oldBuild.customGarages,
                customSquareMeters: oldBuild.customSquareMeters,
                customStoreys: oldBuild.customStoreys,
                additionalClients: newAdditional,
                preConstructionStaffId: oldBuild.preConstructionStaffId,
                buildingSupportStaffId: oldBuild.buildingSupportStaffId,
                handoverTriggeredAt: oldBuild.handoverTriggeredAt,
                buildStatus: oldBuild.buildStatus,
                specTier: oldBuild.specTier
            )
        }
        allClientBuilds[index] = updated
        syncBuildStagesForCurrentUser()
        Task {
            let newPrimaryId: String? = updated.client.id.isEmpty ? nil : updated.client.id
            let newAdditionalIds = updated.additionalClients.map(\.id).filter { !$0.isEmpty }
            let success = await SupabaseService.shared.removeClientFromBuild(
                buildId: buildId,
                clientId: clientId,
                newPrimaryId: newPrimaryId,
                newAdditionalIds: newAdditionalIds
            )
            if success {
                // Don't refresh — local state already updated above
                await notificationService.createNotification(
                    recipientId: clientId,
                    senderId: currentUser.id,
                    senderName: currentUser.fullName,
                    type: .buildUpdate,
                    title: "Build Access Removed",
                    message: "Your access to this build has been removed. Please contact AVIA Homes if you believe this is an error.",
                    referenceId: buildId,
                    referenceType: "build"
                )
            } else {
                // Restore original build if server update failed
                await MainActor.run {
                    if let idx = allClientBuilds.firstIndex(where: { $0.id == buildId }) {
                        allClientBuilds[idx] = oldBuild
                    }
                    syncBuildStagesForCurrentUser()
                }
            }
        }
    }

    func deleteBuild(buildId: String) {
        // Optimistically remove from local state
        let removedBuild = allClientBuilds.first { $0.id == buildId }
        allClientBuilds.removeAll { $0.id == buildId }
        syncBuildStagesForCurrentUser()
        Task {
            let success = await SupabaseService.shared.deleteBuild(buildId: buildId)
            if !success {
                // Restore the build if server delete failed
                if let removedBuild = removedBuild {
                    await MainActor.run {
                        allClientBuilds.append(removedBuild)
                        syncBuildStagesForCurrentUser()
                    }
                }
                print("[AppViewModel] deleteBuild: server delete failed for buildId=\(buildId)")
            }
            // Do NOT call refreshBuildsAndAssignments() — the local state is already correct
        }
    }

    func assignStaffToBuild(buildId: String, staffId: String) {
        guard let index = allClientBuilds.firstIndex(where: { $0.id == buildId }) else { return }
        let oldBuild = allClientBuilds[index]
        let updated = ClientBuild(
            id: oldBuild.id,
            client: oldBuild.client,
            homeDesign: oldBuild.homeDesign,
            lotNumber: oldBuild.lotNumber,
            estate: oldBuild.estate,
            contractDate: oldBuild.contractDate,
            buildStages: oldBuild.buildStages,
            assignedStaffId: staffId,
            salesPartnerId: oldBuild.salesPartnerId,
            isCustom: oldBuild.isCustom,
            selectedFacadeId: oldBuild.selectedFacadeId,
            customBedrooms: oldBuild.customBedrooms,
            customBathrooms: oldBuild.customBathrooms,
            customGarages: oldBuild.customGarages,
            customSquareMeters: oldBuild.customSquareMeters,
            customStoreys: oldBuild.customStoreys,
            additionalClients: oldBuild.additionalClients,
            preConstructionStaffId: oldBuild.preConstructionStaffId,
            buildingSupportStaffId: oldBuild.buildingSupportStaffId,
            handoverTriggeredAt: oldBuild.handoverTriggeredAt,
            buildStatus: oldBuild.buildStatus,
            specTier: oldBuild.specTier
        )
        allClientBuilds[index] = updated
        Task {
            let success = await SupabaseService.shared.upsertBuild(updated)
            if success {
                await refreshBuildsAndAssignments()
            }
        }
    }

    func updateBuildDetails(buildId: String, homeDesign: String, lotNumber: String, estate: String, contractDate: Date, specTier: String? = nil) {
        guard let index = allClientBuilds.firstIndex(where: { $0.id == buildId }) else { return }
        let oldBuild = allClientBuilds[index]
        let updated = ClientBuild(
            id: oldBuild.id,
            client: oldBuild.client,
            homeDesign: homeDesign,
            lotNumber: lotNumber,
            estate: estate,
            contractDate: contractDate,
            buildStages: oldBuild.buildStages,
            assignedStaffId: oldBuild.assignedStaffId,
            salesPartnerId: oldBuild.salesPartnerId,
            isCustom: oldBuild.isCustom,
            selectedFacadeId: oldBuild.selectedFacadeId,
            customBedrooms: oldBuild.customBedrooms,
            customBathrooms: oldBuild.customBathrooms,
            customGarages: oldBuild.customGarages,
            customSquareMeters: oldBuild.customSquareMeters,
            customStoreys: oldBuild.customStoreys,
            additionalClients: oldBuild.additionalClients,
            preConstructionStaffId: oldBuild.preConstructionStaffId,
            buildingSupportStaffId: oldBuild.buildingSupportStaffId,
            handoverTriggeredAt: oldBuild.handoverTriggeredAt,
            buildStatus: oldBuild.buildStatus,
            specTier: specTier ?? oldBuild.specTier
        )
        allClientBuilds[index] = updated
        Task {
            let success = await SupabaseService.shared.upsertBuild(updated)
            if success {
                await refreshBuildsAndAssignments()
            }
        }
    }

    func updateBuildStageProgress(buildId: String, stageId: String, progress: Double, notes: String?) {
        guard let buildIndex = allClientBuilds.firstIndex(where: { $0.id == buildId }) else { return }
        var stages = allClientBuilds[buildIndex].buildStages
        guard let stageIndex = stages.firstIndex(where: { $0.id == stageId }) else { return }
        let old = stages[stageIndex]
        let newStatus: BuildStage.StageStatus = progress >= 1.0 ? .completed : (progress > 0 ? .inProgress : .upcoming)
        let updatedStage = BuildStage(
            id: old.id,
            name: old.name,
            description: old.description,
            status: newStatus,
            progress: min(progress, 1.0),
            startDate: old.startDate ?? (progress > 0 ? .now : nil),
            completionDate: progress >= 1.0 ? .now : old.completionDate,
            notes: notes ?? old.notes,
            photoCount: old.photoCount
        )
        stages[stageIndex] = updatedStage
        let oldBuild = allClientBuilds[buildIndex]
        allClientBuilds[buildIndex] = ClientBuild(
            id: oldBuild.id,
            client: oldBuild.client,
            homeDesign: oldBuild.homeDesign,
            lotNumber: oldBuild.lotNumber,
            estate: oldBuild.estate,
            contractDate: oldBuild.contractDate,
            buildStages: stages,
            assignedStaffId: oldBuild.assignedStaffId,
            salesPartnerId: oldBuild.salesPartnerId,
            isCustom: oldBuild.isCustom,
            selectedFacadeId: oldBuild.selectedFacadeId,
            customBedrooms: oldBuild.customBedrooms,
            customBathrooms: oldBuild.customBathrooms,
            customGarages: oldBuild.customGarages,
            customSquareMeters: oldBuild.customSquareMeters,
            customStoreys: oldBuild.customStoreys,
            additionalClients: oldBuild.additionalClients,
            preConstructionStaffId: oldBuild.preConstructionStaffId,
            buildingSupportStaffId: oldBuild.buildingSupportStaffId,
            handoverTriggeredAt: oldBuild.handoverTriggeredAt,
            buildStatus: oldBuild.buildStatus,
            specTier: oldBuild.specTier
        )
        syncBuildStagesForCurrentUser()
        Task { await SupabaseService.shared.updateBuildStage(updatedStage, buildId: buildId, sortOrder: stageIndex) }
    }

    func addAwaitingRegistrationStage(buildId: String, estimatedDate: Date?, notes: String?) {
        guard let buildIndex = allClientBuilds.firstIndex(where: { $0.id == buildId }) else { return }
        let oldBuild = allClientBuilds[buildIndex]
        guard oldBuild.awaitingRegistrationStage == nil else { return }

        let regStage = BuildStage(
            id: "reg_\(UUID().uuidString.prefix(8))",
            name: "Awaiting Registration",
            description: "Site registration required before construction can begin",
            status: .upcoming,
            progress: 0,
            startDate: nil,
            completionDate: nil,
            notes: notes,
            photoCount: 0,
            estimatedStartDate: nil,
            estimatedEndDate: estimatedDate
        )
        let newStages = [regStage] + oldBuild.buildStages
        allClientBuilds[buildIndex] = ClientBuild(
            id: oldBuild.id, client: oldBuild.client, homeDesign: oldBuild.homeDesign,
            lotNumber: oldBuild.lotNumber, estate: oldBuild.estate, contractDate: oldBuild.contractDate,
            buildStages: newStages, assignedStaffId: oldBuild.assignedStaffId,
            salesPartnerId: oldBuild.salesPartnerId, isCustom: oldBuild.isCustom,
            selectedFacadeId: oldBuild.selectedFacadeId, customBedrooms: oldBuild.customBedrooms,
            customBathrooms: oldBuild.customBathrooms, customGarages: oldBuild.customGarages,
            customSquareMeters: oldBuild.customSquareMeters, customStoreys: oldBuild.customStoreys,
            additionalClients: oldBuild.additionalClients,
            preConstructionStaffId: oldBuild.preConstructionStaffId,
            buildingSupportStaffId: oldBuild.buildingSupportStaffId,
            handoverTriggeredAt: oldBuild.handoverTriggeredAt, buildStatus: oldBuild.buildStatus,
            eoiId: oldBuild.eoiId, specTier: oldBuild.specTier, estimatedStartDate: oldBuild.estimatedStartDate,
            estimatedCompletionDate: oldBuild.estimatedCompletionDate,
            actualStartDate: oldBuild.actualStartDate, actualCompletionDate: oldBuild.actualCompletionDate
        )
        syncBuildStagesForCurrentUser()
        Task {
            await SupabaseService.shared.updateBuildStage(regStage, buildId: buildId, sortOrder: 0)
            // Update sort_order for all other stages
            for (idx, stage) in oldBuild.buildStages.enumerated() {
                await SupabaseService.shared.updateBuildStage(stage, buildId: buildId, sortOrder: idx + 1)
            }
        }
    }

    func removeAwaitingRegistrationStage(buildId: String) {
        guard let buildIndex = allClientBuilds.firstIndex(where: { $0.id == buildId }) else { return }
        let oldBuild = allClientBuilds[buildIndex]
        guard let regStage = oldBuild.awaitingRegistrationStage else { return }

        let newStages = oldBuild.buildStages.filter { $0.name != "Awaiting Registration" }
        allClientBuilds[buildIndex] = ClientBuild(
            id: oldBuild.id, client: oldBuild.client, homeDesign: oldBuild.homeDesign,
            lotNumber: oldBuild.lotNumber, estate: oldBuild.estate, contractDate: oldBuild.contractDate,
            buildStages: newStages, assignedStaffId: oldBuild.assignedStaffId,
            salesPartnerId: oldBuild.salesPartnerId, isCustom: oldBuild.isCustom,
            selectedFacadeId: oldBuild.selectedFacadeId, customBedrooms: oldBuild.customBedrooms,
            customBathrooms: oldBuild.customBathrooms, customGarages: oldBuild.customGarages,
            customSquareMeters: oldBuild.customSquareMeters, customStoreys: oldBuild.customStoreys,
            additionalClients: oldBuild.additionalClients,
            preConstructionStaffId: oldBuild.preConstructionStaffId,
            buildingSupportStaffId: oldBuild.buildingSupportStaffId,
            handoverTriggeredAt: oldBuild.handoverTriggeredAt, buildStatus: oldBuild.buildStatus,
            eoiId: oldBuild.eoiId, specTier: oldBuild.specTier, estimatedStartDate: oldBuild.estimatedStartDate,
            estimatedCompletionDate: oldBuild.estimatedCompletionDate,
            actualStartDate: oldBuild.actualStartDate, actualCompletionDate: oldBuild.actualCompletionDate
        )
        syncBuildStagesForCurrentUser()
        Task {
            await SupabaseService.shared.deleteBuildStage(stageId: regStage.id)
            // Re-index sort_order for remaining stages
            for (idx, stage) in newStages.enumerated() {
                await SupabaseService.shared.updateBuildStage(stage, buildId: buildId, sortOrder: idx)
            }
        }
    }

    func addNewBuild(homeDesign: String, lotNumber: String, estate: String, contractDate: Date, clientId: String, staffId: String, isCustom: Bool = false, selectedFacadeId: String? = nil, customBedrooms: Int? = nil, customBathrooms: Int? = nil, customGarages: Int? = nil, customSquareMeters: Double? = nil, customStoreys: Int? = nil, estimatedStartDate: Date? = nil, estimatedCompletionDate: Date? = nil, customStages: [BuildStage]? = nil, awaitingRegistration: Bool = false, estimatedRegistrationDate: Date? = nil, registrationNotes: String? = nil) {
        let client: ClientUser
        if !clientId.isEmpty, let found = allRegisteredUsers.first(where: { $0.id == clientId }) {
            client = found
        } else {
            var empty = ClientUser.empty
            empty.id = clientId
            client = empty
        }
        let stages: [BuildStage]
        if let customStages, !customStages.isEmpty {
            stages = customStages
        } else {
            let defaultStages = [
                "Pre-Construction", "Site Preparation", "Slab & Foundation", "Frame Stage",
                "Roofing & Wrap", "Lock-Up", "Rough-In", "Fix Stage",
                "Practical Completion", "Handover"
            ]
            let stageDescriptions = [
                "Plans, permits, contracts and approvals",
                "Site clearing, levelling and services",
                "Foundation and concrete slab pour",
                "Structural framing and roof trusses",
                "Roofing, sarking and building wrap",
                "External cladding, windows and doors",
                "Plumbing, electrical and HVAC rough-in",
                "Internal fit-out, cabinetry and finishes",
                "Final inspections and defect check",
                "Keys and welcome to your new home"
            ]
            let offset = awaitingRegistration ? 1 : 0
            var builtStages: [BuildStage] = []
            if awaitingRegistration {
                builtStages.append(BuildStage(
                    id: "new_\(UUID().uuidString.prefix(8))_reg",
                    name: "Awaiting Registration",
                    description: "Site registration required before construction can begin",
                    status: .upcoming,
                    progress: 0,
                    startDate: nil,
                    completionDate: nil,
                    notes: registrationNotes,
                    photoCount: 0,
                    estimatedStartDate: nil,
                    estimatedEndDate: estimatedRegistrationDate
                ))
            }
            builtStages.append(contentsOf: defaultStages.enumerated().map { index, name in
                BuildStage(
                    id: "new_\(UUID().uuidString.prefix(8))_\(index + offset)",
                    name: name,
                    description: stageDescriptions[index],
                    status: .upcoming,
                    progress: 0,
                    startDate: nil,
                    completionDate: nil,
                    notes: nil,
                    photoCount: 0
                )
            })
            stages = builtStages
        }
        let build = ClientBuild(
            id: UUID().uuidString,
            client: client,
            homeDesign: homeDesign,
            lotNumber: lotNumber,
            estate: estate,
            contractDate: contractDate,
            buildStages: stages,
            assignedStaffId: staffId,
            salesPartnerId: nil,
            isCustom: isCustom,
            selectedFacadeId: selectedFacadeId,
            customBedrooms: customBedrooms,
            customBathrooms: customBathrooms,
            customGarages: customGarages,
            customSquareMeters: customSquareMeters,
            customStoreys: customStoreys,
            estimatedStartDate: estimatedStartDate,
            estimatedCompletionDate: estimatedCompletionDate
        )
        allClientBuilds.append(build)
        syncBuildStagesForCurrentUser()
        Task {
            let success = await SupabaseService.shared.upsertBuild(build)
            if success {
                await refreshBuildsAndAssignments()
                if !clientId.isEmpty {
                    await notificationService.createNotification(
                        recipientId: clientId,
                        senderId: currentUser.id,
                        senderName: currentUser.fullName,
                        type: .buildUpdate,
                        title: "Build Created",
                        message: "\(currentUser.fullName) has created a new build for you",
                        referenceId: build.id,
                        referenceType: "build"
                    )
                }
            }
        }
    }

    func addNewBuildWithSpec(homeDesign: String, lotNumber: String, estate: String, contractDate: Date, clientId: String, staffId: String, specTier: SpecTier, isCustom: Bool = false, selectedFacadeId: String? = nil, customBedrooms: Int? = nil, customBathrooms: Int? = nil, customGarages: Int? = nil, customSquareMeters: Double? = nil, customStoreys: Int? = nil, estimatedStartDate: Date? = nil, estimatedCompletionDate: Date? = nil, awaitingRegistration: Bool = false, estimatedRegistrationDate: Date? = nil, registrationNotes: String? = nil) {
        addNewBuild(homeDesign: homeDesign, lotNumber: lotNumber, estate: estate, contractDate: contractDate, clientId: clientId, staffId: staffId, isCustom: isCustom, selectedFacadeId: selectedFacadeId, customBedrooms: customBedrooms, customBathrooms: customBathrooms, customGarages: customGarages, customSquareMeters: customSquareMeters, customStoreys: customStoreys, estimatedStartDate: estimatedStartDate, estimatedCompletionDate: estimatedCompletionDate, awaitingRegistration: awaitingRegistration, estimatedRegistrationDate: estimatedRegistrationDate, registrationNotes: registrationNotes)
        if let build = allClientBuilds.last {
            Task {
                await SupabaseService.shared.createBuildSpecSnapshot(buildId: build.id, specTier: specTier)
                await MainActor.run { AVIAHaptic.success.trigger() }
            }
        }
    }

    var staffUsers: [ClientUser] {
        allRegisteredUsers.filter { $0.role.isAnyStaffRole }
    }

    var clientUsers: [ClientUser] {
        allRegisteredUsers.filter { $0.role == .client }
    }

    var partnerUsers: [ClientUser] {
        allRegisteredUsers.filter { $0.role == .partner || $0.role == .salesPartner }
    }

    func packagesForCurrentUser() -> [HouseLandPackage] {
        switch currentRole {
        case .staff, .admin, .salesAdmin:
            return allPackages
        case .partner, .salesPartner:
            let assignedPackageIds = packageAssignments
                .filter { $0.assignedPartnerIds.contains(currentUser.id) }
                .map(\.packageId)
            return allPackages.filter { assignedPackageIds.contains($0.id) }
        case .client:
            // Client can see packages shared with them UNLESS they have declined.
            // Once declined, the package is removed from their view and stays hidden
            // until an admin re-shares it (which clears the client's response on
            // the server side via the admin flow).
            let visibleAssignments = packageAssignments.filter { assignment in
                guard assignment.sharedWithClientIds.contains(currentUser.id) else { return false }
                let myResponse = assignment.clientResponses.first { $0.clientId == currentUser.id }
                return myResponse?.status != .declined
            }
            let sharedPackageIds = visibleAssignments.map(\.packageId)
            return allPackages.filter { sharedPackageIds.contains($0.id) }
        default:
            return []
        }
    }

    func assignmentForPackage(_ packageId: String) -> PackageAssignment? {
        packageAssignments.first { $0.packageId == packageId }
    }

    func assignPartnerToPackage(packageId: String, partnerId: String) {
        if let index = packageAssignments.firstIndex(where: { $0.packageId == packageId }) {
            if !packageAssignments[index].assignedPartnerIds.contains(partnerId) {
                packageAssignments[index].assignedPartnerIds.append(partnerId)
            }
            syncAssignment(packageAssignments[index])
        } else {
            let assignment = PackageAssignment(packageId: packageId, assignedPartnerIds: [partnerId])
            packageAssignments.append(assignment)
            syncAssignment(assignment)
        }
    }

    func removePartnerFromPackage(packageId: String, partnerId: String) {
        guard let index = packageAssignments.firstIndex(where: { $0.packageId == packageId }) else { return }
        packageAssignments[index].assignedPartnerIds.removeAll { $0 == partnerId }
        syncAssignment(packageAssignments[index])
    }

    func togglePackageExclusive(packageId: String) {
        if let index = packageAssignments.firstIndex(where: { $0.packageId == packageId }) {
            packageAssignments[index].isExclusive.toggle()
            syncAssignment(packageAssignments[index])
        } else {
            var assignment = PackageAssignment(packageId: packageId)
            assignment.isExclusive = true
            packageAssignments.append(assignment)
            syncAssignment(assignment)
        }
    }

    @discardableResult
    private func syncAssignmentAsync(_ assignment: PackageAssignment) async -> Bool {
        let success = await SupabaseService.shared.upsertPackageAssignment(assignment)
        if success {
            await refreshBuildsAndAssignments()
        } else {
            print("[AppViewModel] syncAssignment FAILED for pkg=\(assignment.packageId)")
        }
        return success
    }

    private func syncAssignment(_ assignment: PackageAssignment) {
        Task {
            await syncAssignmentAsync(assignment)
        }
    }

    func sharePackageWithClient(packageId: String, clientId: String) {
        Task {
            await sharePackageWithClientAsync(packageId: packageId, clientId: clientId)
        }
    }

    func sharePackageWithClientAsync(packageId: String, clientId: String) async {
        if let index = packageAssignments.firstIndex(where: { $0.packageId == packageId }) {
            if !packageAssignments[index].sharedWithClientIds.contains(clientId) {
                packageAssignments[index].sharedWithClientIds.append(clientId)
                let response = ClientPackageResponse(clientId: clientId)
                packageAssignments[index].clientResponses.append(response)
            }
            let success = await syncAssignmentAsync(packageAssignments[index])
            guard success else { return }
        } else {
            let response = ClientPackageResponse(clientId: clientId)
            let assignment = PackageAssignment(packageId: packageId, sharedWithClientIds: [clientId], clientResponses: [response])
            packageAssignments.append(assignment)
            let success = await syncAssignmentAsync(assignment)
            guard success else { return }
        }
        let pkg = allPackages.first { $0.id == packageId }
        await notificationService.createNotification(
            recipientId: clientId,
            senderId: currentUser.id,
            senderName: currentUser.fullName,
            type: .packageShared,
            title: "New Package Shared",
            message: "\(currentUser.fullName) shared \(pkg?.title ?? "a package") with you",
            referenceId: packageId,
            referenceType: "package"
        )
        let staffRecipients = allRegisteredUsers.filter { $0.role.isAnyStaffRole && $0.id != currentUser.id }
        let partnerIds = packageAssignments.first { $0.packageId == packageId }?.assignedPartnerIds ?? []
        let packageTitle = pkg?.title ?? "a package"
        let clientName = allRegisteredUsers.first { $0.id == clientId }?.fullName ?? "a client"
        for staff in staffRecipients {
            await notificationService.createNotification(
                recipientId: staff.id,
                senderId: currentUser.id,
                senderName: currentUser.fullName,
                type: .packageShared,
                title: "Package Shared with Client",
                message: "\(currentUser.fullName) shared \(packageTitle) with \(clientName)",
                referenceId: packageId,
                referenceType: "package"
            )
        }
        for partnerId in partnerIds where partnerId != currentUser.id {
            await notificationService.createNotification(
                recipientId: partnerId,
                senderId: currentUser.id,
                senderName: currentUser.fullName,
                type: .packageShared,
                title: "Package Shared with Client",
                message: "\(currentUser.fullName) shared \(packageTitle) with \(clientName)",
                referenceId: packageId,
                referenceType: "package"
            )
        }
    }

    func removeClientFromPackage(packageId: String, clientId: String) {
        guard let index = packageAssignments.firstIndex(where: { $0.packageId == packageId }) else { return }
        packageAssignments[index].sharedWithClientIds.removeAll { $0 == clientId }
        packageAssignments[index].clientResponses.removeAll { $0.clientId == clientId }
        Task {
            await syncAssignmentAsync(packageAssignments[index])
        }
    }

    func respondToPackage(packageId: String, status: PackageResponseStatus, notes: String? = nil) {
        Task {
            await respondToPackageAsync(packageId: packageId, status: status, notes: notes)
        }
    }

    func respondToPackageAsync(packageId: String, status: PackageResponseStatus, notes: String? = nil) async {
        guard let index = packageAssignments.firstIndex(where: { $0.packageId == packageId }) else {
            print("[AppViewModel] respondToPackage: no assignment found for pkg=\(packageId)")
            return
        }
        packageAssignments[index].clientResponses.removeAll { $0.clientId == currentUser.id }
        let response = ClientPackageResponse(clientId: currentUser.id, status: status, respondedDate: .now, notes: notes)
        packageAssignments[index].clientResponses.append(response)

        let success = await syncAssignmentAsync(packageAssignments[index])
        guard success else {
            print("[AppViewModel] respondToPackage: DB write failed, reverting local state")
            packageAssignments[index].clientResponses.removeAll { $0.clientId == currentUser.id }
            await MainActor.run { AVIAHaptic.error.trigger() }
            return
        }

        // Microinteraction: success for accept, warning for decline.
        await MainActor.run {
            switch status {
            case .accepted: AVIAHaptic.success.trigger()
            case .declined: AVIAHaptic.warning.trigger()
            case .pending: break
            }
        }

        await loadAssignmentsFromSupabase()

        guard let refreshedIndex = packageAssignments.firstIndex(where: { $0.packageId == packageId }) else {
            return
        }
        let assignment = packageAssignments[refreshedIndex]
        let pkg = allPackages.first { $0.id == packageId }
        let notifType: NotificationType = status == .accepted ? .packageApproved : .packageDeclined
        let verb = status == .accepted ? "approved" : "declined"
        var recipientIdSet = Set(assignment.assignedPartnerIds)
        for user in allRegisteredUsers where user.role.isAnyStaffRole {
            recipientIdSet.insert(user.id)
        }
        for user in allRegisteredUsers where user.role == .admin {
            recipientIdSet.insert(user.id)
        }
        recipientIdSet.remove(currentUser.id)
        let packageTitle = pkg?.title ?? "a package"
        for recipientId in recipientIdSet {
            await notificationService.createNotification(
                recipientId: recipientId,
                senderId: currentUser.id,
                senderName: currentUser.fullName,
                type: notifType,
                title: "Package \(verb.capitalized)",
                message: "\(currentUser.fullName) \(verb) \(packageTitle)",
                referenceId: packageId,
                referenceType: "package"
            )
        }
    }

    func clientResponseForPackage(_ packageId: String, clientId: String) -> ClientPackageResponse? {
        packageAssignments.first { $0.packageId == packageId }?.clientResponses.first { $0.clientId == clientId }
    }

    var clientSharedPackages: [HouseLandPackage] {
        packagesForCurrentUser()
    }

    func partnerSharePackageWithClient(packageId: String, clientId: String) {
        Task {
            if let index = packageAssignments.firstIndex(where: { $0.packageId == packageId }) {
                if !packageAssignments[index].sharedWithClientIds.contains(clientId) {
                    packageAssignments[index].sharedWithClientIds.append(clientId)
                    let response = ClientPackageResponse(clientId: clientId)
                    packageAssignments[index].clientResponses.append(response)
                }
                let success = await syncAssignmentAsync(packageAssignments[index])
                guard success else { return }
            } else {
                let response = ClientPackageResponse(clientId: clientId)
                let assignment = PackageAssignment(packageId: packageId, assignedPartnerIds: [currentUser.id], sharedWithClientIds: [clientId], clientResponses: [response])
                packageAssignments.append(assignment)
                let success = await syncAssignmentAsync(assignment)
                guard success else { return }
            }
            let pkg = allPackages.first { $0.id == packageId }
            await notificationService.createNotification(
                recipientId: clientId,
                senderId: currentUser.id,
                senderName: currentUser.fullName,
                type: .packageShared,
                title: "New Package Shared",
                message: "\(currentUser.fullName) shared \(pkg?.title ?? "a package") with you",
                referenceId: packageId,
                referenceType: "package"
            )
        }
    }

    func partnerRemoveClientFromPackage(packageId: String, clientId: String) {
        guard let index = packageAssignments.firstIndex(where: { $0.packageId == packageId }) else { return }
        packageAssignments[index].sharedWithClientIds.removeAll { $0 == clientId }
        packageAssignments[index].clientResponses.removeAll { $0.clientId == clientId }
        Task {
            await syncAssignmentAsync(packageAssignments[index])
        }
    }

    func partnerSharedClientsForPackage(_ packageId: String) -> [String] {
        packageAssignments.first { $0.packageId == packageId }?.sharedWithClientIds ?? []
    }

    func submitRequest(title: String, description: String, category: RequestCategory, photos: [Data] = []) {
        let request = ServiceRequest(
            id: UUID().uuidString,
            title: title,
            description: description,
            category: category,
            status: .open,
            dateCreated: .now,
            lastUpdated: .now,
            responses: [],
            attachedPhotos: photos
        )
        requests.insert(request, at: 0)

        let staffRecipients = allRegisteredUsers.filter { $0.role.isAnyStaffRole }
        let buildId = clientBuildsForCurrentUser.first?.id
        Task {
            await SupabaseService.shared.upsertServiceRequest(request, clientId: currentUser.id, buildId: buildId)
            for staff in staffRecipients {
                await notificationService.createNotification(
                    recipientId: staff.id,
                    senderId: currentUser.id,
                    senderName: currentUser.fullName,
                    type: .requestSubmitted,
                    title: "New Request",
                    message: "\(currentUser.fullName) submitted: \(title)",
                    referenceId: request.id,
                    referenceType: "service_request"
                )
            }
        }
    }

    func updateBuildStageWithNotification(buildId: String, stageId: String, progress: Double, notes: String?) {
        updateBuildStageProgress(buildId: buildId, stageId: stageId, progress: progress, notes: notes)

        guard let build = allClientBuilds.first(where: { $0.id == buildId }),
              let stage = build.buildStages.first(where: { $0.id == stageId }) else { return }

        Task {
            for clientUser in build.allClients {
                await notificationService.createNotification(
                    recipientId: clientUser.id,
                    senderId: currentUser.id,
                    senderName: currentUser.fullName,
                    type: .buildUpdate,
                    title: "Build Progress Update",
                    message: "\(stage.name) is now \(Int(progress * 100))% complete",
                    referenceId: buildId,
                    referenceType: "build"
                )
            }
        }
    }

    func partnerSharePackageWithClientNotified(packageId: String, clientId: String) {
        partnerSharePackageWithClient(packageId: packageId, clientId: clientId)
        let pkg = allPackages.first { $0.id == packageId }
        Task {
            await notificationService.createNotification(
                recipientId: clientId,
                senderId: currentUser.id,
                senderName: currentUser.fullName,
                type: .packageShared,
                title: "New Package Shared",
                message: "\(currentUser.fullName) shared \(pkg?.title ?? "a package") with you",
                referenceId: packageId,
                referenceType: "package"
            )
        }
    }

    func createPackage(_ package: HouseLandPackage) {
        allPackages.append(package)
        let row = HouseLandPackageRow(from: package)
        Task {
            let success = await SupabaseService.shared.upsertHouseLandPackage(row)
            if !success {
                print("[AppViewModel] createPackage: upsert failed for id=\(package.id)")
            }
        }
    }

    func updatePackage(_ package: HouseLandPackage) {
        if let index = allPackages.firstIndex(where: { $0.id == package.id }) {
            allPackages[index] = package
        }
        let row = HouseLandPackageRow(from: package)
        Task {
            let success = await SupabaseService.shared.upsertHouseLandPackage(row)
            if success {
                let refreshed = await SupabaseService.shared.fetchHouseLandPackages()
                if !refreshed.isEmpty {
                    allPackages = refreshed
                }
            } else {
                print("[AppViewModel] updatePackage: upsert failed for id=\(package.id)")
            }
        }
    }

    func deletePackage(_ packageId: String) {
        allPackages.removeAll { $0.id == packageId }
        packageAssignments.removeAll { $0.packageId == packageId }
        Task {
            let success = await SupabaseService.shared.deleteHouseLandPackage(id: packageId)
            if !success {
                print("[AppViewModel] deletePackage: delete failed for id=\(packageId)")
            }
        }
    }

    /// Marks a package assignment as having been converted into a build.
    /// The assignment + package are preserved (clients can still reference the original package);
    /// this just records the link and hides the assignment from the 'Accepted' convert action.
    func markAssignmentConverted(assignmentId: String, buildId: String) {
        let iso = ISO8601DateFormatter()
        let nowStr = iso.string(from: .now)

        // Optimistic local update
        if let idx = packageAssignments.firstIndex(where: { $0.id == assignmentId }) {
            packageAssignments[idx].convertedToBuildId = buildId
            packageAssignments[idx].convertedAt = nowStr
        }

        Task {
            let fields: [String: AnyJSON] = [
                "converted_to_build_id": .string(buildId),
                "converted_at": .string(nowStr)
            ]
            let success = await SupabaseService.shared.updatePackageAssignmentFields(
                assignmentId: assignmentId, fields: fields
            )
            if !success {
                print("[AppViewModel] markAssignmentConverted: update failed for assignment=\(assignmentId)")
            }
        }
    }

    func createPackageAndAssignClients(_ package: HouseLandPackage, clientIds: [String]) {
        createPackage(package)
        for clientId in clientIds {
            sharePackageWithClient(packageId: package.id, clientId: clientId)
        }
    }

    func findDesign(byName name: String) -> HomeDesign? {
        let designName = name.components(separatedBy: " ").first ?? ""
        return allHomeDesigns.first { $0.name.lowercased() == designName.lowercased() }
    }

    func findEstate(byName name: String) -> LandEstate? {
        allLandEstates.first { $0.name == name }
    }

    func findFacade(byId id: String) -> Facade? {
        allFacades.first { $0.id == id }
    }

    func respondToRequest(requestId: String, responseText: String, newStatus: RequestStatus) async {
        guard let index = requests.firstIndex(where: { $0.id == requestId }) else { return }
        let oldRequest = requests[index]
        let response = RequestResponse(
            id: UUID().uuidString,
            author: currentUser.fullName,
            message: responseText,
            date: .now,
            isFromClient: currentRole == .client
        )
        var updatedResponses = oldRequest.responses
        updatedResponses.append(response)
        let updated = ServiceRequest(
            id: oldRequest.id,
            title: oldRequest.title,
            description: oldRequest.description,
            category: oldRequest.category,
            status: newStatus,
            dateCreated: oldRequest.dateCreated,
            lastUpdated: .now,
            responses: updatedResponses,
            attachedPhotos: oldRequest.attachedPhotos
        )
        requests[index] = updated
        await SupabaseService.shared.upsertServiceRequest(updated, clientId: currentUser.id)

        let clientId = await findRequestClientId(requestId: requestId)
        if let clientId, clientId != currentUser.id {
            await notificationService.createNotification(
                recipientId: clientId,
                senderId: currentUser.id,
                senderName: currentUser.fullName,
                type: .requestResponse,
                title: "Request Response",
                message: "\(currentUser.fullName) responded to: \(oldRequest.title)",
                referenceId: requestId,
                referenceType: "service_request"
            )
        }
    }

    private func findRequestClientId(requestId: String) async -> String? {
        await SupabaseService.shared.fetchRequestClientId(requestId: requestId)
    }

    func uploadDocumentForClient(clientId: String, name: String, category: DocumentCategory, fileSize: String) async {
        let doc = ClientDocument(
            id: UUID().uuidString,
            name: name,
            category: category,
            dateAdded: .now,
            fileSize: fileSize,
            isNew: true
        )
        documents.insert(doc, at: 0)
        await SupabaseService.shared.upsertDocument(doc, clientId: clientId)

        await notificationService.createNotification(
            recipientId: clientId,
            senderId: currentUser.id,
            senderName: currentUser.fullName,
            type: .documentAdded,
            title: "New Document",
            message: "\(currentUser.fullName) uploaded: \(name)",
            referenceId: doc.id,
            referenceType: "document"
        )
    }

    func deleteDocument(docId: String) async {
        documents.removeAll { $0.id == docId }
        await SupabaseService.shared.deleteDocument(id: docId)
    }
}
