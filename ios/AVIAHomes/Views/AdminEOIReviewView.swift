import SwiftUI
import UniformTypeIdentifiers

struct AdminEOIReviewView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var eoiList: [EOISubmissionRow] = []
    @State private var selectedFilter: EOIFilterStatus = .all
    @State private var selectedEOI: EOISubmissionRow?
    @State private var isLoading = true

    enum EOIFilterStatus: String, CaseIterable {
        case all = "All"
        case submitted = "Submitted"
        case approved = "Approved"
        case changesRequested = "Changes Requested"

        var queryValue: String? {
            switch self {
            case .all: nil
            case .submitted: "submitted"
            case .approved: "approved"
            case .changesRequested: "changes_requested"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                filterPicker
                if isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else if eoiList.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(eoiList, id: \.id) { eoi in
                            eoiRow(eoi)
                                .onTapGesture { selectedEOI = eoi }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .navigationTitle("EOI Reviews")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedEOI) { eoi in
            AdminEOIDetailSheet(eoi: eoi, onUpdate: { await loadEOIs() })
        }
        .task { await loadEOIs() }
        .refreshable { await loadEOIs() }
        .onChange(of: selectedFilter) { _, _ in
            Task { await loadEOIs() }
        }
    }

    private var filterPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(EOIFilterStatus.allCases, id: \.self) { filter in
                    Button {
                        withAnimation(.spring(response: 0.3)) { selectedFilter = filter }
                    } label: {
                        Text(filter.rawValue)
                            .font(.neueCaptionMedium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundStyle(selectedFilter == filter ? .white : AVIATheme.textSecondary)
                            .background(selectedFilter == filter ? AVIATheme.teal : AVIATheme.cardBackground)
                            .clipShape(Capsule())
                            .overlay {
                                if selectedFilter != filter {
                                    Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                                }
                            }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func eoiRow(_ eoi: EOISubmissionRow) -> some View {
        BentoCard(cornerRadius: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(eoi.buyer1_name)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Lot \(eoi.lot_number) — \(eoi.estate_name)")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                    if let date = eoi.created_at {
                        Text(formatDate(date))
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                }
                Spacer()
                eoiStatusBadge(eoi.status)
                Image(systemName: "chevron.right")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(16)
        }
    }

    private func eoiStatusBadge(_ status: String) -> some View {
        let (label, color) = eoiStatusInfo(status)
        return StatusBadge(title: label, color: color)
    }

    private func eoiStatusInfo(_ status: String) -> (String, Color) {
        switch status {
        case "submitted", "resubmitted": ("Submitted", AVIATheme.warning)
        case "approved": ("Approved", AVIATheme.success)
        case "changes_requested": ("Changes Requested", AVIATheme.destructive)
        default: (status.capitalized, AVIATheme.textTertiary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(AVIATheme.textTertiary)
            Text("No EOIs Found")
                .font(.neueCorpMedium(20))
                .foregroundStyle(AVIATheme.textPrimary)
            Text("No expressions of interest match\nthe selected filter.")
                .font(.neueSubheadline)
                .foregroundStyle(AVIATheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func loadEOIs() async {
        isLoading = true
        defer { isLoading = false }
        eoiList = await SupabaseService.shared.fetchAllEOIs(status: selectedFilter.queryValue)
    }

    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return isoString }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

// MARK: - Admin EOI Detail Sheet

struct AdminEOIDetailSheet: View {
    let eoi: EOISubmissionRow
    let onUpdate: () async -> Void
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var adminNotes = ""
    @State private var isProcessing = false
    @State private var showDocumentPicker = false
    @State private var contractRecord: ContractSignatureRow?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusHeader

                    eoiDetailCard("Property Details", icon: "house.fill") {
                        detailRow("Lot Number", eoi.lot_number)
                        detailRow("Estate", eoi.estate_name)
                        if let street = eoi.street_suburb, !street.isEmpty {
                            detailRow("Street & Suburb", street)
                        }
                        detailRow("Occupancy", occupancyLabel(eoi.occupancy_type))
                        if let tier = eoi.specification_tier {
                            detailRow("Spec Tier", tier)
                        }
                        if let facade = eoi.facade_selection {
                            detailRow("Facade", facade)
                        }
                    }

                    eoiDetailCard("Buyer One", icon: "person.fill") {
                        detailRow("Name", eoi.buyer1_name)
                        detailRow("Email", eoi.buyer1_email)
                        detailRow("Address", eoi.buyer1_address)
                        detailRow("Phone", eoi.buyer1_phone)
                    }

                    if let b2Name = eoi.buyer2_name, !b2Name.isEmpty {
                        eoiDetailCard("Buyer Two", icon: "person.fill") {
                            detailRow("Name", b2Name)
                            detailRow("Email", eoi.buyer2_email ?? "—")
                            detailRow("Address", eoi.buyer2_address ?? "—")
                            detailRow("Phone", eoi.buyer2_phone ?? "—")
                        }
                    }

                    eoiDetailCard("Solicitor", icon: "building.columns.fill") {
                        detailRow("Company", eoi.solicitor_company)
                        detailRow("Name", eoi.solicitor_name)
                        detailRow("Email", eoi.solicitor_email)
                        detailRow("Address", eoi.solicitor_address)
                        detailRow("Phone", eoi.solicitor_phone)
                    }

                    if let notes = eoi.admin_notes, !notes.isEmpty {
                        eoiDetailCard("Admin Notes", icon: "note.text") {
                            Text(notes)
                                .font(.neueSubheadline)
                                .foregroundStyle(AVIATheme.textPrimary)
                        }
                    }

                    actionSection
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .background(AVIATheme.background)
            .navigationTitle("EOI Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .font(.neueSubheadline)
                }
            }
            .fileImporter(
                isPresented: $showDocumentPicker,
                allowedContentTypes: [UTType.pdf],
                allowsMultipleSelection: false
            ) { result in
                Task { await handleFileImport(result) }
            }
        }
    }

    private var statusHeader: some View {
        HStack(spacing: 12) {
            let (label, color) = statusInfo
            Image(systemName: statusIcon)
                .font(.system(size: 24))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Text("Submitted by \(eoi.buyer1_name)")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
            }
            Spacer()
            StatusBadge(title: label, color: color)
        }
        .padding(16)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 14))
    }

    private var statusInfo: (String, Color) {
        switch eoi.status {
        case "submitted", "resubmitted": ("Pending Review", AVIATheme.warning)
        case "approved": ("Approved", AVIATheme.success)
        case "changes_requested": ("Changes Requested", AVIATheme.destructive)
        default: (eoi.status.capitalized, AVIATheme.textTertiary)
        }
    }

    private var statusIcon: String {
        switch eoi.status {
        case "submitted", "resubmitted": "clock.fill"
        case "approved": "checkmark.seal.fill"
        case "changes_requested": "exclamationmark.bubble.fill"
        default: "doc.text.fill"
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        if eoi.status == "submitted" || eoi.status == "resubmitted" {
            VStack(spacing: 12) {
                PremiumButton("Approve EOI", icon: "checkmark.seal.fill", style: .primary) {
                    Task { await approveEOI() }
                }
                .disabled(isProcessing)

                VStack(spacing: 8) {
                    Text("Admin Notes")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TextField("Notes for client...", text: $adminNotes, axis: .vertical)
                        .font(.neueSubheadline)
                        .lineLimit(3...6)
                        .padding(12)
                        .background(AVIATheme.cardBackground)
                        .clipShape(.rect(cornerRadius: 10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                        }
                }

                PremiumButton("Request Changes", icon: "exclamationmark.bubble.fill", style: .outlined) {
                    Task { await requestChanges() }
                }
                .disabled(isProcessing || adminNotes.isEmpty)
            }
        } else if eoi.status == "approved" {
            VStack(spacing: 12) {
                BentoCard(cornerRadius: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(AVIATheme.success)
                        Text("EOI Approved")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Spacer()
                    }
                    .padding(16)
                }

                PremiumButton("Upload Contract PDF", icon: "doc.richtext.fill", style: .primary) {
                    showDocumentPicker = true
                }
                .disabled(isProcessing)
            }
        }
    }

    private func approveEOI() async {
        isProcessing = true
        defer { isProcessing = false }

        let success = await SupabaseService.shared.reviewEOI(
            eoiId: eoi.id,
            assignmentId: eoi.package_assignment_id,
            status: "approved",
            adminNotes: adminNotes.isEmpty ? nil : adminNotes,
            reviewedBy: viewModel.currentUser.id
        )
        guard success else { return }

        // Create contract record
        _ = await SupabaseService.shared.createContractRecord(
            eoiId: eoi.id,
            assignmentId: eoi.package_assignment_id,
            clientId: eoi.client_id
        )

        // Notify client
        await viewModel.notificationService.createNotification(
            recipientId: eoi.client_id,
            senderId: viewModel.currentUser.id,
            senderName: viewModel.currentUser.fullName,
            type: .eoiApproved,
            title: "EOI Approved",
            message: "Your expression of interest for Lot \(eoi.lot_number) has been approved",
            referenceId: eoi.package_id,
            referenceType: "package"
        )

        await onUpdate()
        dismiss()
    }

    private func requestChanges() async {
        isProcessing = true
        defer { isProcessing = false }

        let success = await SupabaseService.shared.reviewEOI(
            eoiId: eoi.id,
            assignmentId: eoi.package_assignment_id,
            status: "changes_requested",
            adminNotes: adminNotes,
            reviewedBy: viewModel.currentUser.id
        )
        guard success else { return }

        await viewModel.notificationService.createNotification(
            recipientId: eoi.client_id,
            senderId: viewModel.currentUser.id,
            senderName: viewModel.currentUser.fullName,
            type: .eoiChangesRequested,
            title: "EOI Changes Requested",
            message: "Changes have been requested on your EOI for Lot \(eoi.lot_number)",
            referenceId: eoi.package_id,
            referenceType: "package"
        )

        await onUpdate()
        dismiss()
    }

    private func handleFileImport(_ result: Result<[URL], Error>) async {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url) else { return }

        isProcessing = true
        defer { isProcessing = false }

        // Fetch or create contract record
        var contract = await SupabaseService.shared.fetchContractSignature(forAssignment: eoi.package_assignment_id)
        if contract == nil {
            contract = await SupabaseService.shared.createContractRecord(
                eoiId: eoi.id,
                assignmentId: eoi.package_assignment_id,
                clientId: eoi.client_id
            )
        }
        guard let contractRecord = contract else { return }

        let _ = await SupabaseService.shared.uploadContractDocument(
            contractId: contractRecord.id,
            assignmentId: eoi.package_assignment_id,
            fileData: data,
            fileName: url.lastPathComponent,
            uploadedBy: viewModel.currentUser.id
        )

        // Notify client
        await viewModel.notificationService.createNotification(
            recipientId: eoi.client_id,
            senderId: viewModel.currentUser.id,
            senderName: viewModel.currentUser.fullName,
            type: .contractUploaded,
            title: "Contract Ready",
            message: "A contract is ready for your signature for Lot \(eoi.lot_number)",
            referenceId: eoi.package_id,
            referenceType: "package"
        )

        await onUpdate()
        dismiss()
    }

    // MARK: - Helpers

    private func eoiDetailCard<Content: View>(_ title: String, icon: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        BentoCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.teal)
                    Text(title)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.teal)
                }
                content()
            }
            .padding(16)
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textTertiary)
            Spacer()
            Text(value)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.textPrimary)
        }
    }

    private func occupancyLabel(_ type: String) -> String {
        switch type {
        case "investor": "Investor"
        case "owner_occupier": "Owner Occupier"
        case "corporate": "Corporate"
        default: type.capitalized
        }
    }
}
