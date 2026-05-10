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

    private var roomsWithItems: [(room: SelectionRoom, items: [BuildSpecSelection])] {
        let grouped = Dictionary(grouping: viewModel.selections.filter { $0.selectionType != .removed }) {
            SelectionRoom.from(snapshotCategoryName: $0.snapshotCategoryName)
        }
        return SelectionRoom.displayOrder.compactMap { room in
            guard let items = grouped[room], !items.isEmpty else { return nil }
            return (room: room, items: items.sorted { $0.sortOrder < $1.sortOrder })
        }
    }

    private var totalUpgradeCost: Double {
        viewModel.totalUpgradeCost
    }

    private var totalSelectionsCount: Int {
        viewModel.selections.filter { $0.selectionType != .removed }.count
    }

    private var completedSelectionsCount: Int {
        viewModel.selections.filter { sel in
            guard sel.selectionType != .removed else { return false }
            return isSelectionComplete(sel)
        }.count
    }

    /// A selection is complete only when the client has explicitly chosen
    /// a product (and a colour, if the product offers any). Nothing is
    /// considered complete by default — every option requires a deliberate
    /// client tap.
    private func isSelectionComplete(_ sel: BuildSpecSelection) -> Bool {
        let rangeId = sel.specTier.lowercased()
        let products = catalog.products(for: sel.specItemId, rangeId: rangeId)
        let upgradeDecided = sel.selectionType == .included || sel.selectionType == .upgradeApproved || sel.selectionType == .upgradeAccepted || sel.selectionType == .upgradeDeclined
        guard upgradeDecided else { return false }

        if !products.isEmpty {
            // Product-driven item: needs an explicit product choice and, if
            // that product has colours, an explicit colour choice too.
            guard let pid = sel.productId else { return false }
            let colours = catalog.productColours(for: pid)
            if !colours.isEmpty && sel.colourId == nil { return false }
            return true
        }

        // Legacy item without products — fall back to the colour-mapping flow.
        let needsColour = colourCategoriesRequired(for: sel)
        if !needsColour { return true }
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
        guard !items.isEmpty else { return 0 }
        let done = items.reduce(0) { acc, sel in
            acc + (isSelectionComplete(sel) ? 1 : 0)
        }
        return Double(done) / Double(items.count)
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
                roomsGrid
                Color.clear.frame(height: 80)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .safeAreaInset(edge: .bottom) {
            if !roomsWithItems.isEmpty {
                summaryPill
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
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
                Image(room.heroImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
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
            .overlay {
                LinearGradient(
                    colors: [Color.black.opacity(0.0), Color.black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(.rect(cornerRadius: 14))
                .allowsHitTesting(false)
            }
    }

    private func progressRing(progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 3)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))")
                .font(.neueCorpMedium(10))
                .foregroundStyle(.white)
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
