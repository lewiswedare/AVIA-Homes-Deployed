import SwiftUI

struct AdminBuildSelectionsTab: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var specViewModel = BuildSpecViewModel()
    @State private var isLoaded = false
    @State private var activeTab: SelectionsSubTab = .specRange
    @State private var selectedItem: BuildSpecSelection?
    @State private var isExportingPDF = false
    @State private var exportedPDFURL: URL?
    @State private var showShareSheet = false
    let build: ClientBuild

    private var catalog: CatalogDataManager { CatalogDataManager.shared }

    enum SelectionsSubTab: String, CaseIterable {
        case specRange = "Spec Range"
        case colours = "Colours"
    }

    var body: some View {
        VStack(spacing: 12) {
            if !isLoaded {
                ProgressView()
                    .tint(AVIATheme.timelessBrown)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if !specViewModel.hasSelections && specViewModel.colourSelections.isEmpty {
                noSelectionsView
            } else {
                selectionsSummaryCard

                Picker("", selection: $activeTab) {
                    ForEach(SelectionsSubTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                if activeTab == .specRange {
                    specRangeContent
                } else {
                    colourContent
                }

                exportButton

                NavigationLink {
                    AdminBuildSpecReviewView(
                        buildId: build.id,
                        clientName: build.clientDisplayName,
                        clientId: build.client.id
                    )
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Open Full Spec Review")
                    }
                    .font(.neueSubheadlineMedium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .background(AVIATheme.primaryGradient)
                    .clipShape(.rect(cornerRadius: 14))
                }
            }
        }
        .task {
            specViewModel.notificationService = appViewModel.notificationService
            specViewModel.clientId = build.client.id
            specViewModel.adminRecipientIds = appViewModel.allRegisteredUsers.filter { $0.role.isAnyStaffRole }.map(\.id)
            await specViewModel.load(buildId: build.id)
            isLoaded = true
        }
        .sheet(item: $selectedItem) { item in
            AdminSelectionDetailSheet(
                selection: item,
                colourSelection: specViewModel.colourSelection(for: item.id),
                specTier: specViewModel.specTier,
                onApprove: { id in
                    specViewModel.adminApproveItem(selectionId: id)
                },
                onAddNotes: { id, notes in
                    specViewModel.adminAddNotes(selectionId: id, notes: notes)
                },
                onSetUpgradeCost: { id, cost, note in
                    specViewModel.adminSetUpgradeCost(selectionId: id, cost: cost, note: note)
                }
            )
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedPDFURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    private var selectionsSummaryCard: some View {
        BentoCard(cornerRadius: 16) {
            VStack(spacing: 12) {
                HStack {
                    Label("Selections Overview", systemImage: "checklist.checked")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Spacer()
                    Text(specViewModel.overallStatus.displayLabel)
                        .font(.neueCorpMedium(9))
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(statusColor(specViewModel.overallStatus))
                        .clipShape(Capsule())
                }

                HStack(spacing: 16) {
                    summaryMetric(
                        value: "\(specViewModel.selections.count)",
                        label: "Spec Items",
                        color: AVIATheme.timelessBrown
                    )
                    summaryMetric(
                        value: "\(specViewModel.selections.filter(\.adminConfirmed).count)",
                        label: "Approved",
                        color: AVIATheme.success
                    )
                    summaryMetric(
                        value: "\(specViewModel.colourSelections.count)",
                        label: "Colours",
                        color: AVIATheme.heritageBlue
                    )
                    summaryMetric(
                        value: specViewModel.specTier.capitalized,
                        label: "Tier",
                        color: AVIATheme.warning
                    )
                }
            }
            .padding(16)
        }
    }

    private func summaryMetric(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.neueCorpMedium(18))
                .foregroundStyle(color)
            Text(label)
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func statusColor(_ status: BuildSpecStatus) -> Color {
        switch status {
        case .draft, .clientReviewing: AVIATheme.textTertiary
        case .awaitingAdmin: AVIATheme.warning
        case .awaitingClient: AVIATheme.timelessBrown
        case .reopenedByAdmin, .amendedByAdmin: AVIATheme.heritageBlue
        case .approved: AVIATheme.success
        }
    }

    // MARK: - Spec Range Table

    private var specRangeContent: some View {
        VStack(spacing: 10) {
            if specViewModel.selections.isEmpty {
                emptySection(icon: "doc.text", title: "No spec range selections yet")
            } else {
                ForEach(specViewModel.groupedSelections, id: \.categoryId) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.category.uppercased())
                            .font(.neueCaption2Medium)
                            .kerning(1.0)
                            .foregroundStyle(AVIATheme.textTertiary)
                            .padding(.horizontal, 4)

                        BentoCard(cornerRadius: 14) {
                            VStack(spacing: 0) {
                                specTableHeader

                                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                                    Button {
                                        selectedItem = item
                                    } label: {
                                        specRow(item)
                                    }

                                    if index < group.items.count - 1 {
                                        Rectangle()
                                            .fill(AVIATheme.surfaceBorder)
                                            .frame(height: 1)
                                            .padding(.leading, 14)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var specTableHeader: some View {
        HStack(spacing: 0) {
            Text("Item")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Type")
                .frame(width: 60, alignment: .center)
            Text("Status")
                .frame(width: 50, alignment: .center)
            Image(systemName: "chevron.right")
                .font(.neueCorp(8))
                .foregroundStyle(.clear)
                .frame(width: 20)
        }
        .font(.neueCaption2Medium)
        .foregroundStyle(AVIATheme.textTertiary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AVIATheme.surfaceElevated.opacity(0.5))
    }

    private func specRow(_ item: BuildSpecSelection) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                if let url = item.snapshotImageURL, !url.isEmpty, let imgURL = URL(string: url) {
                    Color(.secondarySystemBackground)
                        .frame(width: 32, height: 32)
                        .overlay {
                            AsyncImage(url: imgURL) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Image(systemName: "photo")
                                        .font(.neueCorp(9))
                                        .foregroundStyle(AVIATheme.textTertiary)
                                }
                            }
                            .allowsHitTesting(false)
                        }
                        .clipShape(.rect(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AVIATheme.surfaceElevated)
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "cube.box")
                                .font(.neueCorp(9))
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                }

                Text(item.snapshotName)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            typePill(item.selectionType)
                .frame(width: 60, alignment: .center)

            HStack(spacing: 3) {
                Circle()
                    .fill(item.clientConfirmed ? AVIATheme.success : AVIATheme.textTertiary.opacity(0.4))
                    .frame(width: 7, height: 7)
                Circle()
                    .fill(item.adminConfirmed ? AVIATheme.success : AVIATheme.textTertiary.opacity(0.4))
                    .frame(width: 7, height: 7)
            }
            .frame(width: 50, alignment: .center)

            Image(systemName: "chevron.right")
                .font(.neueCorp(8))
                .foregroundStyle(AVIATheme.textTertiary)
                .frame(width: 20)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func typePill(_ type: SelectionType) -> some View {
        let (label, color): (String, Color) = switch type {
        case .included: ("STD", AVIATheme.textTertiary)
        case .upgradeRequested: ("UPG", AVIATheme.warning)
        case .upgradeCosted: ("UPG $", AVIATheme.timelessBrown)
        case .upgradeAccepted: ("UPG ✓", AVIATheme.success)
        case .upgradeDeclined: ("UPG ✗", AVIATheme.destructive)
        case .upgradeApproved: ("UPG ✓", AVIATheme.success)
        case .substituted: ("SUB", AVIATheme.heritageBlue)
        case .removed: ("REM", AVIATheme.destructive)
        }
        Text(label)
            .font(.neueCorpMedium(7))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Colour Table

    private var colourContent: some View {
        VStack(spacing: 10) {
            if specViewModel.colourSelections.isEmpty {
                emptySection(icon: "paintpalette", title: "No colour selections yet")
            } else {
                colourStatusBanner

                BentoCard(cornerRadius: 14) {
                    VStack(spacing: 0) {
                        colourTableHeader

                        ForEach(Array(specViewModel.colourSelections.enumerated()), id: \.element.id) { index, cs in
                            let resolved = resolveColour(cs)
                            Button {
                                if let specSel = specViewModel.selections.first(where: { $0.id == cs.buildSpecSelectionId }) {
                                    selectedItem = specSel
                                }
                            } label: {
                                colourRow(cs, resolved: resolved)
                            }

                            if index < specViewModel.colourSelections.count - 1 {
                                Rectangle()
                                    .fill(AVIATheme.surfaceBorder)
                                    .frame(height: 1)
                                    .padding(.leading, 14)
                            }
                        }
                    }
                }
            }
        }
    }

    private var colourStatusBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "paintpalette.fill")
                .foregroundStyle(colourBannerColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(specViewModel.colourSelections.count) colour selections")
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Text("Status: \(specViewModel.colourSelectionOverallStatus.rawValue.capitalized)")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(colourBannerColor.opacity(0.06))
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(colourBannerColor.opacity(0.2), lineWidth: 1)
        }
    }

    private var colourBannerColor: Color {
        switch specViewModel.colourSelectionOverallStatus {
        case .draft: AVIATheme.textTertiary
        case .submitted: AVIATheme.warning
        case .approved: AVIATheme.success
        case .reopened: AVIATheme.heritageBlue
        }
    }

    private var colourTableHeader: some View {
        HStack(spacing: 0) {
            Text("Colour")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Category")
                .frame(width: 70, alignment: .center)
            Text("Status")
                .frame(width: 50, alignment: .center)
            Image(systemName: "chevron.right")
                .font(.neueCorp(8))
                .foregroundStyle(.clear)
                .frame(width: 20)
        }
        .font(.neueCaption2Medium)
        .foregroundStyle(AVIATheme.textTertiary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AVIATheme.surfaceElevated.opacity(0.5))
    }

    private func colourRow(_ cs: BuildColourSelection, resolved: (catName: String, optName: String, hex: String, imageURL: String?)?) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                if let r = resolved {
                    if let imgURL = r.imageURL, !imgURL.isEmpty {
                        Color(.secondarySystemBackground)
                            .frame(width: 28, height: 28)
                            .overlay {
                                AsyncImage(url: URL(string: imgURL)) { phase in
                                    if let image = phase.image {
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    }
                                }
                                .allowsHitTesting(false)
                            }
                            .clipShape(.rect(cornerRadius: 5))
                    } else {
                        Circle()
                            .fill(Color(hex: r.hex))
                            .frame(width: 24, height: 24)
                            .overlay { Circle().stroke(AVIATheme.surfaceBorder, lineWidth: 1) }
                    }
                    Text(r.optName)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                        .lineLimit(1)
                } else {
                    Circle()
                        .fill(AVIATheme.surfaceElevated)
                        .frame(width: 24, height: 24)
                    Text(cs.colourOptionId)
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(resolved?.catName ?? cs.colourCategoryId)
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textSecondary)
                .lineLimit(1)
                .frame(width: 70, alignment: .center)

            colourStatusIcon(cs.selectionStatus)
                .frame(width: 50, alignment: .center)

            Image(systemName: "chevron.right")
                .font(.neueCorp(8))
                .foregroundStyle(AVIATheme.textTertiary)
                .frame(width: 20)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func colourStatusIcon(_ status: ColourSelectionStatus) -> some View {
        let (icon, color): (String, Color) = switch status {
        case .draft: ("circle", AVIATheme.textTertiary)
        case .submitted: ("clock.fill", AVIATheme.warning)
        case .approved: ("checkmark.circle.fill", AVIATheme.success)
        case .reopened: ("arrow.counterclockwise", AVIATheme.heritageBlue)
        }
        Image(systemName: icon)
            .font(.neueCorp(12))
            .foregroundStyle(color)
    }

    private func resolveColour(_ cs: BuildColourSelection) -> (catName: String, optName: String, hex: String, imageURL: String?)? {
        guard let cat = catalog.allColourCategories.first(where: { $0.id == cs.colourCategoryId }) else { return nil }
        guard let opt = cat.options.first(where: { $0.id == cs.colourOptionId }) else { return nil }
        return (catName: cat.name, optName: opt.name, hex: opt.hexColor, imageURL: opt.imageURL)
    }

    // MARK: - Export

    private var exportButton: some View {
        Button {
            exportPDF()
        } label: {
            HStack(spacing: 8) {
                if isExportingPDF {
                    ProgressView().tint(AVIATheme.timelessBrown)
                } else {
                    Image(systemName: "doc.richtext")
                    Text("Export All Selections to PDF")
                }
            }
            .font(.neueSubheadlineMedium)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .foregroundStyle(AVIATheme.timelessBrown)
            .background(AVIATheme.timelessBrown.opacity(0.1))
            .clipShape(.rect(cornerRadius: 14))
        }
        .disabled(isExportingPDF || (!specViewModel.hasSelections && specViewModel.colourSelections.isEmpty))
    }

    private func exportPDF() {
        isExportingPDF = true
        let grouped = specViewModel.groupedSelections
        let colourSelections = specViewModel.colourSelections
        let tier = specViewModel.specTier
        let name = build.clientDisplayName

        Task.detached {
            let url = AdminPDFExporter.generateCombinedPDF(
                clientName: name,
                specTier: tier,
                groupedSelections: grouped,
                colourSelections: colourSelections,
                catalog: await CatalogDataManager.shared
            )
            await MainActor.run {
                isExportingPDF = false
                exportedPDFURL = url
                showShareSheet = true
            }
        }
    }

    // MARK: - Helpers

    private var noSelectionsView: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(AVIATheme.textTertiary)
            Text("No Selections Yet")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)
            Text("Spec range and colour selections haven't been created for this build yet.")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func emptySection(icon: String, title: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(AVIATheme.textTertiary)
            Text(title)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}
