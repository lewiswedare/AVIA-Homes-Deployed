import SwiftUI

/// Admin combined review for the unified Selections flow — every selection
/// (item + chosen tier + colour + cost + status) on a single line, filterable
/// by room or status, with quote / approve actions.
struct AdminUnifiedSelectionsView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var viewModel = BuildSpecViewModel()
    @State private var roomFilter: SelectionRoom?
    @State private var statusFilter: AdminStatusFilter = .all
    @State private var quoteSheet: QuoteContext?
    let buildId: String
    let clientName: String
    let clientId: String

    private var catalog: CatalogDataManager { CatalogDataManager.shared }

    enum AdminStatusFilter: String, CaseIterable, Identifiable {
        case all, needsQuote, needsApproval, approved
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: "All"
            case .needsQuote: "Needs quote"
            case .needsApproval: "Needs approval"
            case .approved: "Approved"
            }
        }
    }

    private struct QuoteContext: Identifiable {
        let id: String
        let selection: BuildSpecSelection
        var cost: String
        var note: String
    }

    private var filteredSelections: [BuildSpecSelection] {
        var items = viewModel.selections.filter { $0.selectionType != .removed }
        if let room = roomFilter {
            items = items.filter { $0.snapshotCategoryName == room.snapshotCategoryName }
        }
        switch statusFilter {
        case .all: break
        case .needsQuote:
            items = items.filter { $0.selectionType == .upgradeRequested }
        case .needsApproval:
            items = items.filter { $0.selectionType == .upgradeAccepted }
        case .approved:
            items = items.filter { $0.selectionType == .upgradeApproved || ($0.selectionType == .included && $0.adminConfirmed) }
        }
        return items.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var groupedByRoom: [(room: SelectionRoom, items: [BuildSpecSelection])] {
        let grouped = Dictionary(grouping: filteredSelections) {
            SelectionRoom.from(snapshotCategoryName: $0.snapshotCategoryName)
        }
        return SelectionRoom.displayOrder.compactMap { room in
            guard let items = grouped[room], !items.isEmpty else { return nil }
            return (room: room, items: items)
        }
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
            viewModel.clientId = clientId
            viewModel.clientName = clientName
            viewModel.adminRecipientIds = appViewModel.allRegisteredUsers.filter { $0.role.isAnyStaffRole }.map(\.id)
            await viewModel.load(buildId: buildId)
        }
        .sheet(item: $quoteSheet) { ctx in
            quoteEditorSheet(ctx)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 14) {
                summaryHeader
                filterBar
                LazyVStack(spacing: 12) {
                    ForEach(groupedByRoom, id: \.room.id) { entry in
                        roomGroup(room: entry.room, items: entry.items)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
    }

    private var summaryHeader: some View {
        BentoCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("UNIFIED SELECTIONS")
                            .font(.neueCorpMedium(9))
                            .kerning(1.4)
                            .foregroundStyle(AVIATheme.timelessBrown)
                        Text(clientName.isEmpty ? "Build" : clientName)
                            .font(.neueCorpMedium(18))
                            .foregroundStyle(AVIATheme.textPrimary)
                    }
                    Spacer()
                    Button {
                        AVIAHaptic.lightTap.trigger()
                        Task { await viewModel.generatePDF() }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .font(.neueCaption2Medium)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .background(AVIATheme.primaryGradient)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.pressable(.subtle))
                }
                Divider().background(AVIATheme.surfaceBorder)
                HStack(spacing: 0) {
                    stat(label: "ITEMS", value: "\(viewModel.selections.filter { $0.selectionType != .removed }.count)")
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(width: 1, height: 30)
                    stat(label: "TO QUOTE", value: "\(viewModel.selections.filter { $0.selectionType == .upgradeRequested }.count)")
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(width: 1, height: 30)
                    stat(label: "UPGRADES", value: viewModel.totalUpgradeCost > 0 ? AVIATheme.formatCost(viewModel.totalUpgradeCost) : "—")
                }
            }
            .padding(16)
        }
    }

    private func stat(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.neueCorpMedium(9))
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)
            Text(value)
                .font(.neueCorpMedium(14))
                .foregroundStyle(AVIATheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    chip(label: "All Rooms", isSelected: roomFilter == nil) { roomFilter = nil }
                    ForEach(SelectionRoom.displayOrder) { room in
                        chip(label: room.displayName, isSelected: roomFilter == room) { roomFilter = room }
                    }
                }
                .padding(.horizontal, 4)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(AdminStatusFilter.allCases) { f in
                        chip(label: f.label, isSelected: statusFilter == f) { statusFilter = f }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func chip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { AVIAHaptic.selection.trigger(); action() }) {
            Text(label)
                .font(.neueCaption2Medium)
                .foregroundStyle(isSelected ? AVIATheme.aviaWhite : AVIATheme.textPrimary)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(isSelected ? AnyShapeStyle(AVIATheme.primaryGradient) : AnyShapeStyle(AVIATheme.cardBackground), in: Capsule())
        }
        .buttonStyle(.pressable(.subtle))
    }

    private func roomGroup(room: SelectionRoom, items: [BuildSpecSelection]) -> some View {
        BentoCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: room.icon)
                        .font(.neueCorp(11))
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text(room.displayName.uppercased())
                        .font(.neueCorpMedium(10))
                        .kerning(1.2)
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Spacer()
                    Text("\(items.count)")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                ForEach(items) { item in
                    adminRow(item)
                    if item.id != items.last?.id {
                        Divider().background(AVIATheme.surfaceBorder)
                    }
                }
            }
            .padding(14)
        }
    }

    private func adminRow(_ item: BuildSpecSelection) -> some View {
        let colour = viewModel.colourSelections.first { $0.buildSpecSelectionId == item.id }
        let resolved: (name: String, hex: String)? = {
            guard let c = colour,
                  let cat = catalog.allColourCategories.first(where: { $0.id == c.colourCategoryId }),
                  let opt = cat.options.first(where: { $0.id == c.colourOptionId }) else { return nil }
            return (opt.name, opt.hexColor)
        }()

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.snapshotName)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    HStack(spacing: 6) {
                        Text(tierLabel(for: item))
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                        if let resolved {
                            Circle()
                                .fill(Color(hex: resolved.hex))
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(AVIATheme.surfaceBorder, lineWidth: 0.5))
                            Text(resolved.name)
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 4) {
                    if let cost = item.upgradeCost, cost > 0 {
                        Text("+\(AVIATheme.formatCost(cost))")
                            .font(.neueCorpMedium(11))
                            .foregroundStyle(AVIATheme.timelessBrown)
                    }
                    statusPill(for: item)
                }
            }

            if item.selectionType == .upgradeRequested {
                Button {
                    quoteSheet = QuoteContext(
                        id: item.id,
                        selection: item,
                        cost: item.upgradeCost.map { String(Int($0)) } ?? "",
                        note: item.upgradeCostNote ?? ""
                    )
                } label: {
                    Label("Add Quote", systemImage: "dollarsign.circle.fill")
                        .font(.neueCaption2Medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.pressable(.standard))
            } else if item.selectionType == .upgradeAccepted {
                HStack(spacing: 8) {
                    Button {
                        AVIAHaptic.success.trigger()
                        viewModel.adminApproveItem(selectionId: item.id)
                    } label: {
                        Text("Approve")
                            .font(.neueCaption2Medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .background(AVIATheme.primaryGradient)
                            .clipShape(.rect(cornerRadius: 8))
                    }
                    .buttonStyle(.pressable(.standard))
                    Button {
                        AVIAHaptic.warning.trigger()
                        viewModel.adminRevertUpgrade(selectionId: item.id)
                    } label: {
                        Text("Send Back")
                            .font(.neueCaption2Medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundStyle(AVIATheme.textPrimary)
                            .background(AVIATheme.surfaceElevated)
                            .clipShape(.rect(cornerRadius: 8))
                    }
                    .buttonStyle(.pressable(.subtle))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func statusPill(for item: BuildSpecSelection) -> some View {
        let info: (String, Color) = {
            switch item.selectionType {
            case .upgradeRequested: ("NEEDS QUOTE", AVIATheme.warning)
            case .upgradeCosted: ("WITH CLIENT", AVIATheme.timelessBrown)
            case .upgradeAccepted: ("APPROVE", AVIATheme.timelessBrown)
            case .upgradeApproved: ("UPGRADED", AVIATheme.heritageBlue)
            case .upgradeDeclined: ("DECLINED", AVIATheme.textTertiary)
            case .upgradeDraft: ("CLIENT DRAFT", AVIATheme.warning)
            case .substituted: ("SUB", AVIATheme.timelessBrown)
            case .included: ("INCLUDED", AVIATheme.textSecondary)
            case .removed: ("REMOVED", AVIATheme.textTertiary)
            }
        }()
        return Text(info.0)
            .font(.neueCorpMedium(8))
            .kerning(0.8)
            .foregroundStyle(info.1)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(info.1.opacity(0.12), in: Capsule())
    }

    private func tierLabel(for item: BuildSpecSelection) -> String {
        switch item.selectionType {
        case .upgradeDraft: "Draft upgrade"
        case .upgradeRequested: "Upgrade requested"
        case .upgradeCosted: "Quoted"
        case .upgradeAccepted, .upgradeApproved: "Upgraded"
        case .upgradeDeclined, .included: "Included (\(item.specTier.capitalized))"
        case .substituted: "Substituted"
        case .removed: "Removed"
        }
    }

    private func quoteEditorSheet(_ ctx: QuoteContext) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ctx.selection.snapshotName)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text(ctx.selection.snapshotCategoryName)
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("UPGRADE COST (AUD)")
                        .font(.neueCorpMedium(9))
                        .kerning(1.0)
                        .foregroundStyle(AVIATheme.textTertiary)
                    TextField("0", text: Binding(
                        get: { quoteSheet?.cost ?? "" },
                        set: { quoteSheet?.cost = $0 }
                    ))
                    .keyboardType(.numberPad)
                    .padding(12)
                    .background(AVIATheme.surfaceElevated)
                    .clipShape(.rect(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("NOTE (OPTIONAL)")
                        .font(.neueCorpMedium(9))
                        .kerning(1.0)
                        .foregroundStyle(AVIATheme.textTertiary)
                    TextField("Notes for the client", text: Binding(
                        get: { quoteSheet?.note ?? "" },
                        set: { quoteSheet?.note = $0 }
                    ), axis: .vertical)
                    .lineLimit(3...6)
                    .padding(12)
                    .background(AVIATheme.surfaceElevated)
                    .clipShape(.rect(cornerRadius: 8))
                }

                Spacer()

                Button {
                    let cost = Double(ctx.cost) ?? 0
                    AVIAHaptic.success.trigger()
                    viewModel.adminSetUpgradeCost(
                        selectionId: ctx.selection.id,
                        cost: cost > 0 ? cost : nil,
                        note: ctx.note.isEmpty ? nil : ctx.note
                    )
                    quoteSheet = nil
                } label: {
                    Text("Send Quote to Client")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(.rect(cornerRadius: 12))
                }
                .buttonStyle(.pressable(.prominent))
            }
            .padding(20)
            .navigationTitle("Quote Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { quoteSheet = nil }
                        .tint(AVIATheme.timelessBrown)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 44))
                .foregroundStyle(AVIATheme.textTertiary)
            Text("No Selections Yet")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)
            Text("This client hasn't started their selections yet.")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
