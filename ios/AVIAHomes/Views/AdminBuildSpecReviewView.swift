import SwiftUI

struct AdminBuildSpecReviewView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var viewModel = BuildSpecViewModel()
    @State private var showApproveAllAlert = false
    @State private var showReopenAlert = false
    @State private var selectedItem: BuildSpecSelection?
    @State private var isExportingPDF = false
    @State private var exportedPDFURL: URL?
    @State private var showShareSheet = false
    @State private var activeTab: SelectionsTab = .specRange
    let buildId: String
    let clientName: String
    var clientId: String = ""

    private var catalog: CatalogDataManager { CatalogDataManager.shared }

    enum SelectionsTab: String, CaseIterable {
        case specRange = "Spec Range"
        case colours = "Colours"
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .tint(AVIATheme.teal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.hasSelections {
                emptyState
            } else {
                specContent
            }
        }
        .background(AVIATheme.background)
        .navigationTitle("Spec Review")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    exportCombinedPDF()
                } label: {
                    if isExportingPDF {
                        ProgressView().tint(AVIATheme.teal)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(AVIATheme.teal)
                    }
                }
                .disabled(isExportingPDF || !viewModel.hasSelections)
            }
        }
        .task {
            viewModel.notificationService = appViewModel.notificationService
            viewModel.clientId = clientId
            viewModel.adminRecipientIds = appViewModel.allRegisteredUsers.filter { $0.role.isAnyStaffRole }.map(\.id)
            await viewModel.load(buildId: buildId)
        }
        .alert("Approve All Specifications", isPresented: $showApproveAllAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Approve All") {
                Task { await viewModel.adminApproveAll() }
            }
        } message: {
            Text("This will approve all specification items for \(clientName)'s build. A PDF summary will be generated.")
        }
        .alert("Reopen for Client", isPresented: $showReopenAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reopen", role: .destructive) {
                Task { await viewModel.adminReopenForClient() }
            }
        } message: {
            Text("This will unlock the specifications so \(clientName) can make changes and resubmit.")
        }
        .sheet(item: $selectedItem) { item in
            AdminSelectionDetailSheet(
                selection: item,
                colourSelection: viewModel.colourSelection(for: item.id),
                specTier: viewModel.specTier,
                onApprove: { id in
                    viewModel.adminApproveItem(selectionId: id)
                },
                onAddNotes: { id, notes in
                    viewModel.adminAddNotes(selectionId: id, notes: notes)
                },
                onSetUpgradeCost: { id, cost, note in
                    viewModel.adminSetUpgradeCost(selectionId: id, cost: cost, note: note)
                }
            )
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedPDFURL {
                ShareSheet(activityItems: [url])
            }
        }
        .overlay(alignment: .bottom) { toastOverlay }
    }

    private var specContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                adminStatusBanner
                clientInfoCard

                Picker("", selection: $activeTab) {
                    ForEach(SelectionsTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                if activeTab == .specRange {
                    specRangeTable
                } else {
                    colourSelectionsTable
                }

                adminActionButtons

                exportPDFButton

                if !viewModel.documents.isEmpty {
                    documentSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Spec Range Table

    private var specRangeTable: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.groupedSelections, id: \.categoryId) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.category.uppercased())
                        .font(.neueCaption2Medium)
                        .kerning(1.0)
                        .foregroundStyle(AVIATheme.textTertiary)
                        .padding(.horizontal, 4)

                    BentoCard(cornerRadius: 14) {
                        VStack(spacing: 0) {
                            tableHeader

                            ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                                Button {
                                    selectedItem = item
                                } label: {
                                    specTableRow(item)
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

    private var tableHeader: some View {
        HStack(spacing: 0) {
            Text("Item")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Type")
                .frame(width: 70, alignment: .center)
            Text("Status")
                .frame(width: 60, alignment: .center)
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

    private func specTableRow(_ item: BuildSpecSelection) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                if let url = item.snapshotImageURL, !url.isEmpty, let imgURL = URL(string: url) {
                    Color(.secondarySystemBackground)
                        .frame(width: 36, height: 36)
                        .overlay {
                            AsyncImage(url: imgURL) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Image(systemName: "photo")
                                        .font(.neueCorp(10))
                                        .foregroundStyle(AVIATheme.textTertiary)
                                }
                            }
                            .allowsHitTesting(false)
                        }
                        .clipShape(.rect(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AVIATheme.surfaceElevated)
                        .frame(width: 36, height: 36)
                        .overlay {
                            Image(systemName: "cube.box")
                                .font(.neueCorp(10))
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.snapshotName)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                        .lineLimit(1)
                    if item.clientNotes != nil || item.adminNotes != nil {
                        Image(systemName: "text.bubble.fill")
                            .font(.neueCorp(8))
                            .foregroundStyle(AVIATheme.teal.opacity(0.6))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            selectionTypePill(item.selectionType)
                .frame(width: 70, alignment: .center)

            statusDot(item)
                .frame(width: 60, alignment: .center)

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
    private func selectionTypePill(_ type: SelectionType) -> some View {
        let (label, color): (String, Color) = switch type {
        case .included: ("STD", AVIATheme.textTertiary)
        case .upgradeRequested: ("UPG REQ", AVIATheme.warning)
        case .upgradeCosted: ("COSTED", AVIATheme.accent)
        case .upgradeAccepted: ("ACCEPTED", Color.green)
        case .upgradeDeclined: ("DECLINED", Color.gray)
        case .upgradeApproved: ("UPG ✓", AVIATheme.success)
        case .substituted: ("SUB", Color(hex: "8B5CF6"))
        case .removed: ("REM", AVIATheme.destructive)
        }
        Text(label)
            .font(.neueCorpMedium(7))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func statusDot(_ item: BuildSpecSelection) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(item.clientConfirmed ? AVIATheme.success : AVIATheme.textTertiary.opacity(0.4))
                .frame(width: 7, height: 7)
            Circle()
                .fill(item.adminConfirmed ? AVIATheme.success : AVIATheme.textTertiary.opacity(0.4))
                .frame(width: 7, height: 7)
        }
    }

    // MARK: - Colour Selections Table

    private var colourSelectionsTable: some View {
        VStack(spacing: 12) {
            if viewModel.colourSelections.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 32))
                        .foregroundStyle(AVIATheme.textTertiary)
                    Text("No colour selections submitted yet")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                colourStatusBanner

                BentoCard(cornerRadius: 14) {
                    VStack(spacing: 0) {
                        colourTableHeader

                        ForEach(Array(viewModel.colourSelections.enumerated()), id: \.element.id) { index, cs in
                            let resolved = resolveColourSelection(cs)
                            Button {
                                if let specSel = viewModel.selections.first(where: { $0.id == cs.buildSpecSelectionId }) {
                                    selectedItem = specSel
                                }
                            } label: {
                                colourTableRow(cs, resolved: resolved)
                            }

                            if index < viewModel.colourSelections.count - 1 {
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
                .foregroundStyle(colourStatusColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.colourSelections.count) colour selections")
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Text("Status: \(viewModel.colourSelectionOverallStatus.rawValue.capitalized)")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textSecondary)
            }
            Spacer()
            Text(viewModel.colourSelectionOverallStatus.rawValue.capitalized)
                .font(.neueCorpMedium(9))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(colourStatusColor)
                .clipShape(Capsule())
        }
        .padding(14)
        .background(colourStatusColor.opacity(0.06))
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(colourStatusColor.opacity(0.2), lineWidth: 1)
        }
    }

    private var colourStatusColor: Color {
        switch viewModel.colourSelectionOverallStatus {
        case .draft: AVIATheme.textTertiary
        case .submitted: AVIATheme.warning
        case .approved: AVIATheme.success
        case .reopened: Color(hex: "8B5CF6")
        }
    }

    private var colourTableHeader: some View {
        HStack(spacing: 0) {
            Text("Colour")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Category")
                .frame(width: 80, alignment: .center)
            Text("Status")
                .frame(width: 56, alignment: .center)
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

    private func colourTableRow(_ cs: BuildColourSelection, resolved: (catName: String, optName: String, hex: String, imageURL: String?)?) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                if let r = resolved {
                    if let imgURL = r.imageURL, !imgURL.isEmpty {
                        Color(.secondarySystemBackground)
                            .frame(width: 32, height: 32)
                            .overlay {
                                AsyncImage(url: URL(string: imgURL)) { phase in
                                    if let image = phase.image {
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    }
                                }
                                .allowsHitTesting(false)
                            }
                            .clipShape(.rect(cornerRadius: 6))
                    } else {
                        Circle()
                            .fill(Color(hex: r.hex))
                            .frame(width: 28, height: 28)
                            .overlay { Circle().stroke(AVIATheme.surfaceBorder, lineWidth: 1) }
                    }

                    Text(r.optName)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                        .lineLimit(1)
                } else {
                    Circle()
                        .fill(AVIATheme.surfaceElevated)
                        .frame(width: 28, height: 28)
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
                .frame(width: 80, alignment: .center)

            colourStatusPill(cs.selectionStatus)
                .frame(width: 56, alignment: .center)

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
    private func colourStatusPill(_ status: ColourSelectionStatus) -> some View {
        let (icon, color): (String, Color) = switch status {
        case .draft: ("circle", AVIATheme.textTertiary)
        case .submitted: ("clock.fill", AVIATheme.warning)
        case .approved: ("checkmark.circle.fill", AVIATheme.success)
        case .reopened: ("arrow.counterclockwise", Color(hex: "8B5CF6"))
        }
        Image(systemName: icon)
            .font(.neueCorp(12))
            .foregroundStyle(color)
    }

    private func resolveColourSelection(_ cs: BuildColourSelection) -> (catName: String, optName: String, hex: String, imageURL: String?)? {
        guard let cat = catalog.allColourCategories.first(where: { $0.id == cs.colourCategoryId }) else { return nil }
        guard let opt = cat.options.first(where: { $0.id == cs.colourOptionId }) else { return nil }
        return (catName: cat.name, optName: opt.name, hex: opt.hexColor, imageURL: opt.imageURL)
    }

    // MARK: - PDF Export

    private var exportPDFButton: some View {
        Button {
            exportCombinedPDF()
        } label: {
            HStack(spacing: 8) {
                if isExportingPDF {
                    ProgressView().tint(AVIATheme.teal)
                } else {
                    Image(systemName: "doc.richtext")
                    Text("Export All Selections to PDF")
                }
            }
            .font(.neueSubheadlineMedium)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .foregroundStyle(AVIATheme.teal)
            .background(AVIATheme.teal.opacity(0.1))
            .clipShape(.rect(cornerRadius: 14))
        }
        .disabled(isExportingPDF)
    }

    private func exportCombinedPDF() {
        isExportingPDF = true
        let selections = viewModel.selections
        let colourSelections = viewModel.colourSelections
        let tier = viewModel.specTier
        let grouped = viewModel.groupedSelections
        let name = clientName

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

    // MARK: - Existing Components

    private var adminStatusBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.overallStatus.icon)
                .font(.neueSubheadlineMedium)
                .foregroundStyle(adminStatusColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(adminStatusTitle)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Text(adminStatusSubtitle)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textSecondary)
            }

            Spacer()

            Text(viewModel.overallStatus.displayLabel)
                .font(.neueCorpMedium(9))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(adminStatusColor)
                .clipShape(Capsule())
        }
        .padding(14)
        .background(adminStatusColor.opacity(0.06))
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(adminStatusColor.opacity(0.2), lineWidth: 1)
        }
    }

    private var adminStatusColor: Color {
        switch viewModel.overallStatus {
        case .draft, .clientReviewing: AVIATheme.textTertiary
        case .awaitingAdmin: AVIATheme.warning
        case .awaitingClient: AVIATheme.accent
        case .reopenedByAdmin: Color(hex: "8B5CF6")
        case .approved: AVIATheme.success
        case .amendedByAdmin: Color(hex: "8B5CF6")
        }
    }

    private var adminStatusTitle: String {
        switch viewModel.overallStatus {
        case .draft, .clientReviewing: "Client Has Not Submitted"
        case .awaitingAdmin: "Awaiting Your Review"
        case .awaitingClient: "Awaiting Client Response"
        case .reopenedByAdmin: "Reopened for Client"
        case .approved: "Fully Approved"
        case .amendedByAdmin: "You Made Amendments"
        }
    }

    private var adminStatusSubtitle: String {
        switch viewModel.overallStatus {
        case .draft, .clientReviewing:
            "\(clientName) is still reviewing their specifications."
        case .awaitingAdmin:
            "\(clientName) has confirmed. Review and approve or make changes."
        case .awaitingClient:
            "Upgrade cost has been sent. Waiting for \(clientName) to accept or decline."
        case .reopenedByAdmin:
            "Waiting for \(clientName) to review changes and resubmit."
        case .approved:
            "Both client and admin have confirmed. PDF generated."
        case .amendedByAdmin:
            "Changes have been made. Decide whether to finalise or reopen."
        }
    }

    private var clientInfoCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.fill")
                .font(.neueCorp(12))
                .foregroundStyle(AVIATheme.teal)
                .frame(width: 32, height: 32)
                .background(AVIATheme.teal.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(clientName)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Text("Spec Range: \(viewModel.specTier.capitalized)")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(viewModel.selections.count) items")
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                let approvedCount = viewModel.selections.filter { $0.adminConfirmed }.count
                Text("\(approvedCount) approved")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.success)
            }
        }
        .padding(14)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 14))
    }

    private var adminActionButtons: some View {
        VStack(spacing: 10) {
            if viewModel.overallStatus == .awaitingAdmin || viewModel.overallStatus == .amendedByAdmin {
                Button {
                    showApproveAllAlert = true
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "checkmark.seal.fill")
                            Text("Approve All & Generate PDF")
                        }
                    }
                    .font(.neueSubheadlineMedium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(.white)
                    .background(AVIATheme.success)
                    .clipShape(.rect(cornerRadius: 14))
                }
                .disabled(viewModel.isSaving)
            }

            if viewModel.overallStatus != .draft && viewModel.overallStatus != .clientReviewing {
                Button {
                    showReopenAlert = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reopen for Client Changes")
                    }
                    .font(.neueSubheadlineMedium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundStyle(AVIATheme.destructive)
                    .background(AVIATheme.destructive.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 14))
                }
                .disabled(viewModel.isSaving)
            }
        }
    }

    @ViewBuilder
    private var documentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GENERATED DOCUMENTS")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)

            ForEach(viewModel.documents) { doc in
                HStack(spacing: 10) {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(AVIATheme.teal)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spec Summary v\(doc.version)")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        if let date = doc.generatedAt {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                    }

                    Spacer()

                    if let urlStr = doc.publicURL, let url = URL(string: urlStr) {
                        Link(destination: url) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(AVIATheme.teal)
                        }
                    }
                }
                .padding(12)
                .background(AVIATheme.cardBackground)
                .clipShape(.rect(cornerRadius: 12))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(AVIATheme.textTertiary)
            Text("No Specifications")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)
            Text("Build specifications haven't been created for this build yet.")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let msg = viewModel.successMessage {
            Text(msg)
                .font(.neueCaptionMedium)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(AVIATheme.success, in: Capsule())
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation { viewModel.successMessage = nil }
                    }
                }
        }
        if let msg = viewModel.errorMessage {
            Text(msg)
                .font(.neueCaptionMedium)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(AVIATheme.destructive, in: Capsule())
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { viewModel.errorMessage = nil }
                    }
                }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
