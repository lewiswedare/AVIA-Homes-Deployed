import SwiftUI

/// Unified Selections hub — replaces the separate Spec Range and Colour
/// Selections tabs for new builds. Browses by room and surfaces upgrade
/// totals + per-room progress at a glance.
struct SelectionsHomeView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var viewModel = BuildSpecViewModel()
    @State private var showReview = false
    let buildId: String

    private var catalog: CatalogDataManager { CatalogDataManager.shared }

    private var buildSpecTier: SpecTier {
        SpecTier(rawValue: viewModel.specTier.lowercased()) ?? .messina
    }

    /// Rooms are the admin-managed `spec_categories`. Every room the admin
    /// has set up in the catalogue appears here whenever it has *any*
    /// content — either selections already materialised onto this build, or
    /// variant assignments in the catalogue for the build's range/facade.
    /// Items inside each room come from `variant_room_assignments`; legacy
    /// slot-less rows fall back to matching by snapshot category so nothing
    /// silently disappears.
    private var roomsWithItems: [(room: SelectionRoom, items: [BuildSpecSelection])] {
        let active = viewModel.selections.filter { $0.selectionType != .removed }
        let rangeId = viewModel.specTier.lowercased()
        let facadeId = viewModel.selectedFacadeId
        var bucket: [String: [BuildSpecSelection]] = [:]
        var legacyBucket: [String: [BuildSpecSelection]] = [:]

        for sel in active {
            let roomIds = catalog.roomIds(forSpecItem: sel.specItemId, rangeId: rangeId, facadeId: facadeId)
            if roomIds.isEmpty {
                // No room assignments yet — fall back to snapshot category.
                legacyBucket[sel.snapshotCategoryName, default: []].append(sel)
            } else {
                for rid in roomIds {
                    bucket[rid, default: []].append(sel)
                }
            }
        }

        var result: [(room: SelectionRoom, items: [BuildSpecSelection])] = []
        for room in SelectionRoom.displayOrder {
            var items: [BuildSpecSelection] = []
            if let rid = room.categoryId, let assigned = bucket[rid] {
                items.append(contentsOf: assigned)
            }
            if let legacy = legacyBucket[room.snapshotCategoryName] {
                items.append(contentsOf: legacy)
            }
            // Surface the room whenever the admin catalogue has content for
            // it in this build's range/facade — even if the build snapshot
            // doesn't yet contain any selections. This keeps the client room
            // list in lock-step with the admin Rooms editor.
            let hasCatalogueContent: Bool = {
                guard let rid = room.categoryId else { return false }
                return !catalog.variantIds(forRoom: rid, rangeId: rangeId, facadeId: facadeId).isEmpty
            }()
            guard !items.isEmpty || hasCatalogueContent else { continue }
            // De-dupe (an item could legitimately match by both paths) and sort.
            var seen = Set<String>()
            let deduped = items.filter { seen.insert($0.id).inserted }
                .sorted { $0.sortOrder < $1.sortOrder }
            result.append((room: room, items: deduped))
        }
        return result
    }

    private var totalUpgradeCost: Double {
        viewModel.totalUpgradeCost
    }

    private var totalSelectionsCount: Int {
        viewModel.selections.filter { sel in
            sel.selectionType != .removed && isSelectionCountable(sel)
        }.count
    }

    private var completedSelectionsCount: Int {
        viewModel.selections.filter { sel in
            guard sel.selectionType != .removed, isSelectionCountable(sel) else { return false }
            return isSelectionComplete(sel)
        }.count
    }

    /// Items that have neither products nor a colour mapping are admin
    /// placeholders the client can't act on yet — exclude them from the
    /// progress total so the count reflects only items that need a tap.
    private func isSelectionCountable(_ sel: BuildSpecSelection) -> Bool {
        let rangeId = sel.specTier.lowercased()
        let products = catalog.products(for: sel.specItemId, rangeId: rangeId)
        if !products.isEmpty { return true }
        return colourCategoriesRequired(for: sel)
    }

    /// A selection is complete only when the client has explicitly chosen
    /// a product (and a colour, if the product offers any). Nothing is
    /// considered complete by default — every option requires a deliberate
    /// client tap.
    private func isSelectionComplete(_ sel: BuildSpecSelection) -> Bool {
        let rangeId = sel.specTier.lowercased()
        let products = catalog.products(for: sel.specItemId, rangeId: rangeId)

        // Upgrades that are still mid-flow (draft / awaiting quote / quoted)
        // are NOT complete — the client hasn't locked anything in.
        let upgradeDecided = sel.selectionType == .included
            || sel.selectionType == .upgradeApproved
            || sel.selectionType == .upgradeAccepted
            || sel.selectionType == .upgradeDeclined
        guard upgradeDecided else { return false }

        if !products.isEmpty {
            // Product-driven item: needs an explicit product choice and, if
            // that product has colours, an explicit colour choice too.
            guard let pid = sel.productId else { return false }
            let colours = catalog.productColours(for: pid)
            if !colours.isEmpty && sel.colourId == nil { return false }
            return true
        }

        // Legacy item without products — only complete once the client has
        // saved at least one colour selection for it. (Items with neither
        // products nor colours are filtered out by isSelectionCountable.)
        return viewModel.colourSelections.contains { $0.buildSpecSelectionId == sel.id }
    }

    private func colourCategoriesRequired(for selection: BuildSpecSelection) -> Bool {
        let mapping = catalog.activeSpecToColourMapping
        let tier = buildSpecTier
        guard let catIds = mapping[selection.specItemId] else { return false }
        return catIds.contains { catId in
            guard let cat = catalog.allColourCategories.first(where: { $0.id == catId }) else { return false }
            return cat.isAvailable(for: tier)
        }
    }

    private func progress(for items: [BuildSpecSelection]) -> Double {
        let countable = items.filter { isSelectionCountable($0) }
        guard !countable.isEmpty else { return 0 }
        let done = countable.reduce(0) { acc, sel in
            acc + (isSelectionComplete(sel) ? 1 : 0)
        }
        return Double(done) / Double(countable.count)
    }

    private func roomUpgradeCost(_ items: [BuildSpecSelection]) -> Double {
        let specCost = items
            .filter { $0.upgradeCost != nil && ($0.selectionType == .upgradeCosted || $0.selectionType == .upgradeAccepted || $0.selectionType == .upgradeApproved) }
            .compactMap(\.upgradeCost).reduce(0, +)
        let itemIds = Set(items.map(\.id))
        let colourCost = viewModel.colourSelections
            .filter { itemIds.contains($0.buildSpecSelectionId ?? "") && $0.isUpgrade && ($0.cost ?? 0) > 0 }
            .compactMap(\.cost).reduce(0, +)
        return specCost + colourCost
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView().tint(AVIATheme.timelessBrown)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.selections.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .background(AVIATheme.background)
        .task {
            viewModel.notificationService = appViewModel.notificationService
            viewModel.clientId = appViewModel.currentUser.id
            viewModel.clientName = appViewModel.currentUser.fullName
            viewModel.adminRecipientIds = appViewModel.allRegisteredUsers.filter { $0.role.isAnyStaffRole }.map(\.id)
            if let build = appViewModel.allClientBuilds.first(where: { $0.id == buildId }) {
                let lot = build.lotNumber.isEmpty ? "" : "Lot \(build.lotNumber)"
                let estate = build.estate
                let combined = [lot, estate].filter { !$0.isEmpty }.joined(separator: ", ")
                viewModel.buildAddress = combined.isEmpty ? build.homeDesign : combined
                viewModel.selectedFacadeId = build.selectedFacadeId
            }
            await viewModel.load(buildId: buildId)
        }
        .sheet(isPresented: $showReview) {
            SelectionsReviewView(viewModel: viewModel)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryHero
                if viewModel.upgradeBreakdown.total > 0 {
                    upgradeBreakdownCard
                }
                roomsGrid
                Color.clear.frame(height: 80)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .adaptiveContentWidth()
        }
        .safeAreaInset(edge: .bottom) {
            if !roomsWithItems.isEmpty {
                summaryPill
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    .adaptiveContentWidth()
            }
        }
    }

    private var summaryHero: some View {
        BentoCard(cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.neueCorp(13))
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text("YOUR SELECTIONS")
                        .font(.neueCaption2Medium)
                        .kerning(1.4)
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Spacer()
                    Text(buildSpecTier.displayName.uppercased())
                        .font(.neueCorpMedium(9))
                        .kerning(1.2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(Capsule())
                }

                Text("Pick your finishes,\ncolours, and upgrades.")
                    .font(.neueCorpMedium(26))
                    .foregroundStyle(AVIATheme.textPrimary)
                    .lineSpacing(2)

                Text("Browse room by room. Each item lets you confirm what's included, request an upgrade, and choose your colours — all in one place.")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider().background(AVIATheme.surfaceBorder)

                HStack(spacing: 0) {
                    summaryStat(
                        label: "COMPLETE",
                        value: "\(completedSelectionsCount) / \(totalSelectionsCount)"
                    )
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(width: 1, height: 36)
                    summaryStat(
                        label: "ROOMS",
                        value: "\(roomsWithItems.count)"
                    )
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(width: 1, height: 36)
                    summaryStat(
                        label: "UPGRADES",
                        value: totalUpgradeCost > 0 ? AVIATheme.formatCost(totalUpgradeCost) : "—"
                    )
                }
            }
            .padding(18)
        }
    }

    private func summaryStat(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.neueCorpMedium(9))
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)
            Text(value)
                .font(.neueCorpMedium(15))
                .foregroundStyle(AVIATheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var upgradeBreakdownCard: some View {
        let breakdown = viewModel.upgradeBreakdown
        return BentoCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.pie.fill")
                        .font(.neueCorp(12))
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text("UPGRADE SUMMARY")
                        .font(.neueCorpMedium(9))
                        .kerning(1.4)
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Spacer()
                    Text(AVIATheme.formatCost(breakdown.total))
                        .font(.neueCorpMedium(16))
                        .foregroundStyle(AVIATheme.textPrimary)
                }

                VStack(spacing: 8) {
                    breakdownRow(label: "Spec range upgrades", icon: "arrow.up.circle.fill", colour: AVIATheme.heritageBlue, amount: breakdown.specRange)
                    breakdownRow(label: "Product upgrades", icon: "shippingbox.fill", colour: AVIATheme.timelessBrown, amount: breakdown.product)
                    breakdownRow(label: "Colour extras", icon: "paintpalette.fill", colour: AVIATheme.warning, amount: breakdown.colour)
                }

                Button {
                    AVIAHaptic.lightTap.trigger()
                    showReview = true
                } label: {
                    HStack(spacing: 6) {
                        Text("View full breakdown")
                            .font(.neueCaptionMedium)
                        Image(systemName: "arrow.right")
                            .font(.neueCorp(10))
                    }
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AVIATheme.timelessBrown.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(.pressable(.subtle))
            }
            .padding(16)
        }
    }

    private func breakdownRow(label: String, icon: String, colour: Color, amount: Double) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(colour)
                .frame(width: 22)
            Text(label)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
            Spacer()
            Text(amount > 0 ? AVIATheme.formatCost(amount) : "—")
                .font(.neueCorpMedium(12))
                .foregroundStyle(amount > 0 ? AVIATheme.textPrimary : AVIATheme.textTertiary)
        }
    }

    private var roomsGrid: some View {
        LazyVStack(spacing: 12) {
            ForEach(roomsWithItems, id: \.room.id) { entry in
                NavigationLink {
                    SelectionsRoomDetailView(
                        viewModel: viewModel,
                        room: entry.room,
                        buildId: buildId
                    )
                } label: {
                    roomCard(entry.room, items: entry.items)
                }
                .buttonStyle(.pressable(.subtle))
            }
        }
    }

    private func roomCard(_ room: SelectionRoom, items: [BuildSpecSelection]) -> some View {
        let prog = progress(for: items)
        let upgrade = roomUpgradeCost(items)
        let pendingCount = items.filter { sel in
            sel.selectionType == .upgradeDraft ||
            sel.selectionType == .upgradeRequested ||
            sel.selectionType == .upgradeCosted
        }.count

        return Color(.secondarySystemBackground)
            .frame(height: 168)
            .overlay {
                roomBannerImage(room)
                    .allowsHitTesting(false)
            }
            .overlay {
                LinearGradient(
                    colors: [Color.black.opacity(0.0), Color.black.opacity(0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .clipShape(.rect(cornerRadius: 14))
            .overlay(alignment: .topTrailing) {
                progressRing(progress: prog)
                    .frame(width: 38, height: 38)
                    .padding(12)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: room.icon)
                            .font(.neueCorp(11))
                            .foregroundStyle(AVIATheme.aviaWhite)
                        Text(room.displayName.uppercased())
                            .font(.neueCorpMedium(11))
                            .kerning(1.2)
                            .foregroundStyle(AVIATheme.aviaWhite)
                    }
                    Text(room.subtitle)
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.aviaWhite.opacity(0.85))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                            .font(.neueCorpMedium(10))
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial, in: Capsule())

                        if upgrade > 0 {
                            Text(AVIATheme.formatCost(upgrade))
                                .font(.neueCorpMedium(10))
                                .foregroundStyle(AVIATheme.aviaWhite)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AVIATheme.timelessBrown, in: Capsule())
                        }

                        if pendingCount > 0 {
                            Text("\(pendingCount) PENDING")
                                .font(.neueCorpMedium(8))
                                .kerning(0.8)
                                .foregroundStyle(AVIATheme.aviaWhite)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AVIATheme.warning, in: Capsule())
                        }
                    }
                }
                .padding(14)
            }
    }

    @ViewBuilder
    private func roomBannerImage(_ room: SelectionRoom) -> some View {
        if let urlString = room.heroImageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else if phase.error != nil {
                    Image(room.heroImageName).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color(.secondarySystemBackground)
                }
            }
        } else {
            Image(room.heroImageName).resizable().aspectRatio(contentMode: .fill)
        }
    }

    private func progressRing(progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(AVIATheme.aviaWhite.opacity(0.3), lineWidth: 3)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(AVIATheme.aviaWhite, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))")
                .font(.neueCorpMedium(10))
                .foregroundStyle(AVIATheme.aviaWhite)
        }
    }

    private var summaryPill: some View {
        Button {
            AVIAHaptic.mediumTap.trigger()
            showReview = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(AVIATheme.aviaWhite.opacity(0.3), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: totalSelectionsCount == 0 ? 0.001 : Double(completedSelectionsCount) / Double(totalSelectionsCount))
                        .stroke(AVIATheme.aviaWhite, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(completedSelectionsCount) of \(totalSelectionsCount) complete")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.aviaWhite)
                    Text(totalUpgradeCost > 0 ? "Upgrades \(AVIATheme.formatCost(totalUpgradeCost))" : "Tap to review")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.aviaWhite.opacity(0.75))
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("Review")
                        .font(.neueCaptionMedium)
                    Image(systemName: "arrow.right")
                        .font(.neueCorp(11))
                }
                .foregroundStyle(AVIATheme.aviaWhite)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.18), in: Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AVIATheme.primaryGradient)
            .clipShape(Capsule())
            .shadow(color: AVIATheme.timelessBrown.opacity(0.25), radius: 12, y: 6)
        }
        .buttonStyle(.pressable(.standard))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 44))
                .foregroundStyle(AVIATheme.textTertiary)
            Text("Selections Coming Soon")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)
            Text("Your selections will appear here once your build has been set up by the AVIA team.")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
