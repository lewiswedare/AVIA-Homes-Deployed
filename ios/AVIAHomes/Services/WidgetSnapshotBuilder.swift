import Foundation

@MainActor
enum WidgetSnapshotBuilder {
    static func update(from app: AppViewModel) async {
        let user = app.currentUser
        guard !user.id.isEmpty else {
            WidgetSnapshotStore.clear()
            return
        }

        let firstName = user.firstName

        let news = Array(
            app.allBlogPosts
                .sorted { $0.date > $1.date }
                .prefix(3)
        ).map { post in
            WidgetNewsItem(
                id: post.id,
                title: post.title,
                excerpt: post.subtitle,
                imageURL: post.imageURL,
                publishedAt: post.date
            )
        }

        // Only clients see build/package widgets. Staff/admin see news only.
        guard app.currentRole == .client else {
            writeNoBuild(firstName: firstName, news: news)
            return
        }

        if let build = app.clientBuildsForCurrentUser.first {
            await buildSnapshotForBuild(build: build, app: app, firstName: firstName, news: news)
            return
        }

        if let pkgSummary = packageSummary(for: user, app: app) {
            let snapshot = WidgetSnapshot(
                kind: .packageAssigned,
                userFirstName: firstName,
                homeDesign: pkgSummary.homeDesign,
                estate: pkgSummary.location,
                lotNumber: "",
                currentStageName: "",
                currentStageDescription: "",
                overallProgress: 0,
                stageProgress: 0,
                totalStages: 0,
                completedStages: 0,
                isAwaitingRegistration: false,
                specsRemaining: 0,
                specsTotal: 0,
                coloursRemaining: 0,
                coloursTotal: 0,
                nextStepTitle: "Review your package",
                nextStepDetail: "Tap to view full package details and respond to your AVIA team.",
                staff: nil,
                package: pkgSummary,
                news: news,
                updatedAt: .now
            )
            WidgetSnapshotStore.write(snapshot)
            return
        }

        writeNoBuild(firstName: firstName, news: news)
    }

    private static func writeNoBuild(firstName: String, news: [WidgetNewsItem]) {
        let snapshot = WidgetSnapshot(
            kind: .noBuild,
            userFirstName: firstName,
            homeDesign: "",
            estate: "",
            lotNumber: "",
            currentStageName: "",
            currentStageDescription: "",
            overallProgress: 0,
            stageProgress: 0,
            totalStages: 0,
            completedStages: 0,
            isAwaitingRegistration: false,
            specsRemaining: 0,
            specsTotal: 0,
            coloursRemaining: 0,
            coloursTotal: 0,
            nextStepTitle: "",
            nextStepDetail: "",
            staff: nil,
            package: nil,
            news: news,
            updatedAt: .now
        )
        WidgetSnapshotStore.write(snapshot)
    }

    private static func buildSnapshotForBuild(
        build: ClientBuild,
        app: AppViewModel,
        firstName: String,
        news: [WidgetNewsItem]
    ) async {
        async let specsTask = SupabaseService.shared.fetchBuildSpecSelections(buildId: build.id)
        async let coloursTask = SupabaseService.shared.fetchBuildColourSelections(buildId: build.id)
        let (specs, colours) = await (specsTask, coloursTask)

        let specsTotal = specs.count
        let specsRemaining = specs.filter { !$0.clientConfirmed || $0.status == .reopenedByAdmin }.count

        let coloursTotal = colours.count
        let coloursRemaining = colours.filter { sel in
            switch sel.selectionStatus {
            case .approved, .submitted, .upgradeAcceptedByClient, .upgradeRequested:
                return false
            default:
                return true
            }
        }.count

        let stage = build.currentStage
        let completedStages = build.constructionStages.filter { $0.status == .completed }.count
        let totalStages = build.constructionStages.count

        let kind: WidgetSnapshotKind
        if build.isAwaitingRegistration && specsRemaining > 0 {
            kind = .awaitingSpecs
        } else if specsTotal > 0 && specsRemaining > 0 && (stage == nil || stage?.name.lowercased().contains("spec") == true || build.isAwaitingRegistration) {
            kind = .awaitingSpecs
        } else if coloursTotal > 0 && coloursRemaining > 0 && (stage == nil || stage?.name.lowercased().contains("colour") == true || build.isAwaitingRegistration) {
            kind = .awaitingColours
        } else {
            kind = .buildProgress
        }

        let staff = staffContact(for: build, app: app, kind: kind)
        let (nextTitle, nextDetail) = nextSteps(for: build, kind: kind, specsRemaining: specsRemaining, coloursRemaining: coloursRemaining)

        let snapshot = WidgetSnapshot(
            kind: kind,
            userFirstName: firstName,
            homeDesign: build.homeDesign,
            estate: build.estate,
            lotNumber: build.lotNumber,
            currentStageName: build.statusLabel,
            currentStageDescription: stage?.description ?? "",
            overallProgress: build.overallProgress,
            stageProgress: stage?.progress ?? 0,
            totalStages: totalStages,
            completedStages: completedStages,
            isAwaitingRegistration: build.isAwaitingRegistration,
            specsRemaining: specsRemaining,
            specsTotal: specsTotal,
            coloursRemaining: coloursRemaining,
            coloursTotal: coloursTotal,
            nextStepTitle: nextTitle,
            nextStepDetail: nextDetail,
            staff: staff,
            package: nil,
            news: news,
            updatedAt: .now
        )

        WidgetSnapshotStore.write(snapshot)
    }

    private static func staffContact(
        for build: ClientBuild,
        app: AppViewModel,
        kind: WidgetSnapshotKind
    ) -> WidgetStaffContact? {
        // Pick the most relevant staff member for the current phase.
        let users = app.allRegisteredUsers
        func find(_ id: String?) -> ClientUser? {
            guard let id, !id.isEmpty else { return nil }
            return users.first { $0.id == id }
        }

        let preConstruction = find(build.preConstructionStaffId)
        let buildingSupport = find(build.buildingSupportStaffId)
        let primary = find(build.assignedStaffId)

        let chosen: ClientUser?
        if build.isAwaitingRegistration || kind == .awaitingSpecs || kind == .awaitingColours {
            chosen = preConstruction ?? primary ?? buildingSupport
        } else if kind == .buildProgress {
            chosen = buildingSupport ?? primary ?? preConstruction
        } else {
            chosen = primary ?? preConstruction ?? buildingSupport
        }

        guard let staff = chosen else { return nil }

        let roleLabel: String
        if let title = staff.displayTitle, !title.isEmpty {
            roleLabel = title
        } else {
            switch staff.role {
            case .preConstruction: roleLabel = "Pre-Construction"
            case .buildingSupport: roleLabel = "Building Support"
            case .staff: roleLabel = "Your AVIA Contact"
            case .admin, .salesAdmin, .superAdmin: roleLabel = "AVIA Team"
            default: roleLabel = "AVIA Contact"
            }
        }

        return WidgetStaffContact(
            name: staff.fullName.trimmingCharacters(in: .whitespaces),
            roleLabel: roleLabel,
            phone: staff.phone,
            email: staff.email
        )
    }

    private static func nextSteps(
        for build: ClientBuild,
        kind: WidgetSnapshotKind,
        specsRemaining: Int,
        coloursRemaining: Int
    ) -> (String, String) {
        switch kind {
        case .awaitingSpecs:
            return ("Confirm specifications", "\(specsRemaining) spec item\(specsRemaining == 1 ? "" : "s") still need your review.")
        case .awaitingColours:
            return ("Make colour selections", "\(coloursRemaining) colour\(coloursRemaining == 1 ? "" : "s") still to choose.")
        case .buildProgress:
            if build.isAwaitingRegistration {
                if let est = build.awaitingRegistrationStage?.estimatedEndDate {
                    return ("Awaiting site registration", "Estimated registration \(est.formatted(.dateTime.month(.abbreviated).day().year()))")
                }
                return ("Awaiting site registration", "Your AVIA team will be in touch with updates.")
            }
            // Find next upcoming stage after current.
            let stages = build.constructionStages
            if let currentIdx = stages.firstIndex(where: { $0.status == .inProgress }) {
                if currentIdx + 1 < stages.count {
                    let next = stages[currentIdx + 1]
                    if let est = next.estimatedStartDate {
                        return ("Next: \(next.name)", "Estimated start \(est.formatted(.dateTime.month(.abbreviated).day()))")
                    }
                    return ("Next: \(next.name)", next.description)
                }
                return ("Final stretch", "You're in the last stage of your build.")
            }
            if let firstUpcoming = stages.first(where: { $0.status == .upcoming }) {
                return ("Next: \(firstUpcoming.name)", firstUpcoming.description)
            }
            return ("On track", "Your AVIA team will share the next update soon.")
        case .noBuild, .packageAssigned:
            return ("", "")
        }
    }

    private static func packageSummary(for user: ClientUser, app: AppViewModel) -> WidgetPackageSummary? {
        let visible = app.packageAssignments.first { assignment in
            guard assignment.sharedWithClientIds.contains(user.id) else { return false }
            let myResponse = assignment.clientResponses.first { $0.clientId == user.id }
            return myResponse?.status != .declined
        }
        guard let assignment = visible,
              let pkg = app.allPackages.first(where: { $0.id == assignment.packageId }) else {
            return nil
        }

        let myResponse = assignment.clientResponses.first { $0.clientId == user.id }
        let statusLabel = myResponse?.status.rawValue ?? "Awaiting review"

        return WidgetPackageSummary(
            title: pkg.title,
            location: pkg.location,
            homeDesign: pkg.homeDesign,
            price: pkg.price,
            bedrooms: pkg.bedrooms,
            bathrooms: pkg.bathrooms,
            garages: pkg.garages,
            imageURL: pkg.imageURL,
            responseStatus: statusLabel
        )
    }
}
