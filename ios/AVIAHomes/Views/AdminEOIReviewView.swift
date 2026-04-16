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
        case declined = "Declined"
        case changesRequested = "Changes Requested"

        var queryValue: String? {
            switch self {
            case .all: nil
            case .submitted: "submitted"
            case .approved: "approved"
            case .declined: "declined"
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
                            .background(selectedFilter == filter ? AVIATheme.timelessBrown : AVIATheme.cardBackground)
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
        let otherEOIsForPackage = eoiList.filter { $0.package_id == eoi.package_id && $0.id != eoi.id }
        return BentoCard(cornerRadius: 14) {
            VStack(spacing: 0) {
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

                if !otherEOIsForPackage.isEmpty {
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(AVIATheme.timelessBrown)
                        Text("\(otherEOIsForPackage.count + 1) EOIs for this package")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                        Spacer()
                        let pendingCount = otherEOIsForPackage.filter { $0.status == "submitted" || $0.status == "resubmitted" }.count + (eoi.status == "submitted" || eoi.status == "resubmitted" ? 1 : 0)
                        if pendingCount > 0 {
                            Text("\(pendingCount) pending")
                                .font(.neueCorpMedium(9))
                                .foregroundStyle(AVIATheme.warning)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AVIATheme.warning.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AVIATheme.cardBackgroundAlt)
                }
            }
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
        case "declined": ("Declined", AVIATheme.destructive)
        case "changes_requested": ("Changes Requested", AVIATheme.warning)
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
    @State private var isEditing = false
    @State private var editedEOI: EOISubmissionRow
    @State private var showPipeline = false

    init(eoi: EOISubmissionRow, onUpdate: @escaping () async -> Void) {
        self.eoi = eoi
        self.onUpdate = onUpdate
        self._editedEOI = State(initialValue: eoi)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusHeader

                    if let pkg = viewModel.allPackages.first(where: { $0.id == eoi.package_id }) {
                        NavigationLink(value: pkg) {
                            HStack(spacing: 10) {
                                Image(systemName: "house.fill")
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.timelessBrown)
                                Text("View Package")
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.timelessBrown)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                            }
                            .padding(16)
                            .background(AVIATheme.cardBackground)
                            .clipShape(.rect(cornerRadius: 14))
                        }
                    }

                    eoiDetailCard("Property Details", icon: "house.fill") {
                        editableRow("Lot Number", value: $editedEOI.lot_number)
                        editableRow("Estate", value: $editedEOI.estate_name)
                        editableRow("Street & Suburb", value: optionalBinding(\.street_suburb))
                        editableRow("Occupancy", value: $editedEOI.occupancy_type)
                        editableRow("Spec Tier", value: optionalBinding(\.specification_tier))
                        editableRow("Facade", value: optionalBinding(\.facade_selection))
                    }

                    eoiDetailCard("Buyer One", icon: "person.fill") {
                        editableRow("Name", value: $editedEOI.buyer1_name)
                        editableRow("Email", value: $editedEOI.buyer1_email)
                        editableRow("Address", value: $editedEOI.buyer1_address)
                        editableRow("Phone", value: $editedEOI.buyer1_phone)
                    }

                    if isEditing || (eoi.buyer2_name != nil && !eoi.buyer2_name!.isEmpty) {
                        eoiDetailCard("Buyer Two", icon: "person.fill") {
                            editableRow("Name", value: optionalBinding(\.buyer2_name))
                            editableRow("Email", value: optionalBinding(\.buyer2_email))
                            editableRow("Address", value: optionalBinding(\.buyer2_address))
                            editableRow("Phone", value: optionalBinding(\.buyer2_phone))
                        }
                    }

                    eoiDetailCard("Solicitor", icon: "building.columns.fill") {
                        editableRow("Company", value: $editedEOI.solicitor_company)
                        editableRow("Name", value: $editedEOI.solicitor_name)
                        editableRow("Email", value: $editedEOI.solicitor_email)
                        editableRow("Address", value: $editedEOI.solicitor_address)
                        editableRow("Phone", value: $editedEOI.solicitor_phone)
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
                ToolbarItem(placement: .topBarTrailing) {
                    if isEditing {
                        Button("Save") { Task { await saveEdits() } }
                            .font(.neueSubheadlineMedium)
                            .disabled(isProcessing)
                    } else {
                        Button("Edit") { isEditing = true }
                            .font(.neueSubheadline)
                    }
                }
            }
            .fileImporter(
                isPresented: $showDocumentPicker,
                allowedContentTypes: [UTType.pdf],
                allowsMultipleSelection: false
            ) { result in
                Task { await handleFileImport(result) }
            }
            .navigationDestination(for: HouseLandPackage.self) { pkg in
                PackageDetailView(package: pkg)
            }
            .sheet(isPresented: $showPipeline) {
                AdminPipelineView(eoi: eoi)
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
        case "declined": ("Declined", AVIATheme.destructive)
        case "changes_requested": ("Changes Requested", AVIATheme.warning)
        default: (eoi.status.capitalized, AVIATheme.textTertiary)
        }
    }

    private var statusIcon: String {
        switch eoi.status {
        case "submitted", "resubmitted": "clock.fill"
        case "approved": "checkmark.seal.fill"
        case "declined": "xmark.circle.fill"
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

                PremiumButton("Accept & Decline Others", icon: "person.crop.circle.badge.checkmark", style: .primary) {
                    Task { await acceptAndDeclineOthers() }
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

                HStack(spacing: 12) {
                    PremiumButton("Request Changes", icon: "exclamationmark.bubble.fill", style: .outlined) {
                        Task { await requestChanges() }
                    }
                    .disabled(isProcessing || adminNotes.isEmpty)

                    PremiumButton("Decline EOI", icon: "xmark.circle.fill", style: .destructive) {
                        Task { await declineEOI() }
                    }
                    .disabled(isProcessing)
                }
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

                PremiumButton("View Pipeline", icon: "arrow.triangle.branch", style: .primary) {
                    showPipeline = true
                }

                PremiumButton("Upload Contract PDF", icon: "doc.richtext.fill", style: .outlined) {
                    showDocumentPicker = true
                }
                .disabled(isProcessing)
            }
        } else if eoi.status == "declined" {
            BentoCard(cornerRadius: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AVIATheme.destructive)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("EOI Declined")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        if let notes = eoi.admin_notes, !notes.isEmpty {
                            Text(notes)
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)
                        }
                    }
                    Spacer()
                }
                .padding(16)
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

    private func declineEOI() async {
        isProcessing = true
        defer { isProcessing = false }

        let success = await SupabaseService.shared.declineEOI(
            eoiId: eoi.id,
            assignmentId: eoi.package_assignment_id,
            reviewedBy: viewModel.currentUser.id,
            adminNotes: adminNotes.isEmpty ? nil : adminNotes
        )
        guard success else { return }

        await viewModel.notificationService.createNotification(
            recipientId: eoi.client_id,
            senderId: viewModel.currentUser.id,
            senderName: viewModel.currentUser.fullName,
            type: .eoiChangesRequested,
            title: "EOI Declined",
            message: "Your expression of interest for Lot \(eoi.lot_number) has been declined",
            referenceId: eoi.package_id,
            referenceType: "package"
        )

        await onUpdate()
        dismiss()
    }

    private func acceptAndDeclineOthers() async {
        isProcessing = true
        defer { isProcessing = false }

        let success = await SupabaseService.shared.acceptEOIAndDeclineOthers(
            acceptedEOIId: eoi.id,
            packageId: eoi.package_id,
            assignmentId: eoi.package_assignment_id,
            reviewedBy: viewModel.currentUser.id
        )
        guard success else { return }

        // Create contract record for accepted EOI
        _ = await SupabaseService.shared.createContractRecord(
            eoiId: eoi.id,
            assignmentId: eoi.package_assignment_id,
            clientId: eoi.client_id
        )

        // Notify the accepted client
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

        // Notify declined clients
        let allEOIs = await SupabaseService.shared.fetchEOIsForPackage(packageId: eoi.package_id)
        for otherEOI in allEOIs where otherEOI.id != eoi.id && otherEOI.status == "declined" {
            await viewModel.notificationService.createNotification(
                recipientId: otherEOI.client_id,
                senderId: viewModel.currentUser.id,
                senderName: viewModel.currentUser.fullName,
                type: .eoiChangesRequested,
                title: "EOI Declined",
                message: "Your expression of interest for Lot \(otherEOI.lot_number) has been declined — another EOI was accepted",
                referenceId: otherEOI.package_id,
                referenceType: "package"
            )
        }

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
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text(title)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.timelessBrown)
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

    private func editableRow(_ label: String, value: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textTertiary)
                .frame(width: 100, alignment: .leading)
            if isEditing {
                TextField(label, text: value)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                    .textFieldStyle(.roundedBorder)
            } else {
                Spacer()
                Text(value.wrappedValue)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
            }
        }
    }

    private func optionalBinding(_ keyPath: WritableKeyPath<EOISubmissionRow, String?>) -> Binding<String> {
        Binding(
            get: { editedEOI[keyPath: keyPath] ?? "" },
            set: { editedEOI[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private func saveEdits() async {
        isProcessing = true
        defer { isProcessing = false }
        let success = await SupabaseService.shared.submitEOI(editedEOI)
        if success {
            isEditing = false
            await onUpdate()
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
