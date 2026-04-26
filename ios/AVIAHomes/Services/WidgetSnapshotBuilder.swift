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

        // Latest news, used in noBuild and large widget.
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

        // Only clients see build-specific widgets. Staff/admin see news only.
        guard app.currentRole == .client,
              let build = app.clientBuildsForCurrentUser.first else {
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
                news: news,
                updatedAt: .now
            )
            WidgetSnapshotStore.write(snapshot)
            return
        }

        // Pull selections directly from Supabase so the widget reflects the
        // latest spec/colour confirmation status without having to keep
        // them in AppViewModel state for the client role.
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

        // Decide which kind of widget to show.
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
            news: news,
            updatedAt: .now
        )

        WidgetSnapshotStore.write(snapshot)
    }
}
