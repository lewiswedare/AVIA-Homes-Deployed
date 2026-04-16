import SwiftUI
import UniformTypeIdentifiers

struct AdminPipelineView: View {
    let eoi: EOISubmissionRow
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var contract: ContractRow?
    @State private var invoice: InvoiceRow?
    @State private var isLoading = true
    @State private var showContractSheet = false
    @State private var showInvoiceSheet = false
    @State private var isProcessing = false

    private var packagePrice: Double? {
        guard let pkg = viewModel.allPackages.first(where: { $0.id == eoi.package_id }) else { return nil }
        let cleaned = pkg.price.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    pipelineHeader
                    step1EOIAccepted
                    step2Contract
                    step3Invoice
                    step4CreateBuild
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .background(AVIATheme.background)
            .navigationTitle("Pipeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .font(.neueSubheadline)
                }
            }
            .task { await loadPipelineData() }
            .sheet(isPresented: $showContractSheet) {
                RaiseContractSheet(eoi: eoi, onCreated: { newContract in
                    contract = newContract
                })
            }
            .sheet(isPresented: $showInvoiceSheet) {
                RaiseInvoiceSheet(
                    eoi: eoi,
                    contractId: contract?.id,
                    suggestedAmount: packagePrice.map { $0 * 0.05 },
                    packagePrice: packagePrice,
                    onCreated: { newInvoice in
                        invoice = newInvoice
                    }
                )
            }
        }
    }

    // MARK: - Header

    private var pipelineHeader: some View {
        BentoCard(cornerRadius: 14) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 24))
                    .foregroundStyle(AVIATheme.timelessBrown)
                VStack(alignment: .leading, spacing: 3) {
                    Text("EOI → Build Pipeline")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("\(eoi.buyer1_name) — Lot \(eoi.lot_number), \(eoi.estate_name)")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                Spacer()
            }
            .padding(16)
        }
    }

    // MARK: - Step 1: EOI Accepted

    private var step1EOIAccepted: some View {
        pipelineStep(
            number: 1,
            title: "EOI Accepted",
            icon: "checkmark.seal.fill",
            isComplete: true,
            isActive: false,
            isEnabled: true
        ) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AVIATheme.success)
                Text("Approved")
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.success)
            }
        }
    }

    // MARK: - Step 2: Contract

    private var contractIsComplete: Bool {
        contract?.statusEnum == .signed
    }

    private var step2Contract: some View {
        pipelineStep(
            number: 2,
            title: "Contract",
            icon: "doc.richtext.fill",
            isComplete: contractIsComplete,
            isActive: !contractIsComplete,
            isEnabled: true
        ) {
            if isLoading {
                ProgressView()
            } else if let contract {
                contractStatusRow(contract)
            } else {
                PremiumButton("Raise Contract", icon: "plus.circle.fill", style: .primary) {
                    showContractSheet = true
                }
                .disabled(isProcessing)
            }
        }
    }

    private func contractStatusRow(_ contract: ContractRow) -> some View {
        VStack(spacing: 8) {
            HStack {
                StatusBadge(title: contract.displayStatus, color: statusColor(for: contract.statusEnum))
                Spacer()
                if let url = contract.contract_url, !url.isEmpty {
                    Link(destination: URL(string: url)!) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text.fill")
                                .font(.neueCaption2)
                            Text("View PDF")
                                .font(.neueCaptionMedium)
                        }
                        .foregroundStyle(AVIATheme.timelessBrown)
                    }
                }
            }

            if contract.statusEnum == .sent {
                Text("Waiting for client to sign")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if contract.statusEnum == .draft {
                PremiumButton("Upload & Send Contract", icon: "paperplane.fill", style: .primary) {
                    showContractSheet = true
                }
                .disabled(isProcessing)
            }

            if contract.statusEnum == .signed {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AVIATheme.success)
                    Text("Signed")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.success)
                    if let signedAt = contract.signed_at {
                        Text("on \(formatDate(signedAt))")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Step 3: Invoice

    private var invoiceIsComplete: Bool {
        invoice?.statusEnum == .paid
    }

    private var step3Invoice: some View {
        let enabled = contractIsComplete

        return pipelineStep(
            number: 3,
            title: "Deposit Invoice",
            icon: "dollarsign.circle.fill",
            isComplete: invoiceIsComplete,
            isActive: enabled && !invoiceIsComplete,
            isEnabled: enabled
        ) {
            if !enabled {
                Text("Contract must be signed first")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textTertiary)
            } else if isLoading {
                ProgressView()
            } else if let invoice {
                invoiceStatusRow(invoice)
            } else {
                PremiumButton("Raise Invoice", icon: "plus.circle.fill", style: .primary) {
                    showInvoiceSheet = true
                }
                .disabled(isProcessing)
            }
        }
    }

    private func invoiceStatusRow(_ invoice: InvoiceRow) -> some View {
        VStack(spacing: 8) {
            HStack {
                StatusBadge(title: invoice.displayStatus, color: invoiceStatusColor(for: invoice.statusEnum))
                Spacer()
                Text(invoice.formattedAmount)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
            }

            if let desc = invoice.description, !desc.isEmpty {
                Text(desc)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                if invoice.due_date != nil {
                    Text("Due: \(invoice.formattedDueDate)")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                Spacer()
            }

            if invoice.statusEnum == .sent || invoice.statusEnum == .overdue {
                PremiumButton("Mark as Paid", icon: "checkmark.circle.fill", style: .primary) {
                    Task { await markPaid(invoice) }
                }
                .disabled(isProcessing)
            }

            if invoice.statusEnum == .paid {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AVIATheme.success)
                    Text("Paid")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.success)
                    if let paidAt = invoice.paid_at {
                        Text("on \(formatDate(paidAt))")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Step 4: Create Build

    private var step4CreateBuild: some View {
        let enabled = invoiceIsComplete

        return pipelineStep(
            number: 4,
            title: "Create Build",
            icon: "hammer.fill",
            isComplete: false,
            isActive: enabled,
            isEnabled: enabled
        ) {
            if !enabled {
                Text("Invoice must be paid first")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textTertiary)
            } else {
                VStack(spacing: 8) {
                    Text("Ready to create build")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.success)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    PremiumButton("Create Build", icon: "hammer.fill", style: .primary) {
                        // Build creation handled by another developer
                    }
                    .disabled(true)
                    Text("Build creation coming soon")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
            }
        }
    }

    // MARK: - Pipeline Step Template

    private func pipelineStep<Content: View>(
        number: Int,
        title: String,
        icon: String,
        isComplete: Bool,
        isActive: Bool,
        isEnabled: Bool,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Step indicator
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(isComplete ? AVIATheme.success : (isActive ? AVIATheme.timelessBrown : AVIATheme.cardBackground))
                        .frame(width: 36, height: 36)
                    if isComplete {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Text("\(number)")
                            .font(.neueCorpMedium(14))
                            .foregroundStyle(isActive ? .white : AVIATheme.textTertiary)
                    }
                }

                if number < 4 {
                    Rectangle()
                        .fill(isComplete ? AVIATheme.success.opacity(0.3) : AVIATheme.surfaceBorder)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }

            // Step content
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.neueCaption)
                        .foregroundStyle(isEnabled ? AVIATheme.timelessBrown : AVIATheme.textTertiary)
                    Text(title)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(isEnabled ? AVIATheme.textPrimary : AVIATheme.textTertiary)
                }

                content()
                    .opacity(isEnabled ? 1 : 0.5)
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .background(isActive ? AVIATheme.cardBackground : Color.clear)
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AVIATheme.timelessBrown.opacity(0.3), lineWidth: 1)
            }
        }
    }

    // MARK: - Actions

    private func markPaid(_ invoice: InvoiceRow) async {
        isProcessing = true
        defer { isProcessing = false }

        let success = await SupabaseService.shared.markInvoicePaid(invoiceId: invoice.id)
        if success {
            self.invoice?.status = "paid"
            self.invoice?.paid_at = ISO8601DateFormatter().string(from: .now)

            await viewModel.notificationService.createNotification(
                recipientId: eoi.client_id,
                senderId: viewModel.currentUser.id,
                senderName: viewModel.currentUser.fullName,
                type: .invoicePaid,
                title: "Invoice Paid",
                message: "Your deposit invoice for Lot \(eoi.lot_number) has been marked as paid",
                referenceId: eoi.package_id,
                referenceType: "package"
            )
        }
    }

    // MARK: - Data Loading

    private func loadPipelineData() async {
        isLoading = true
        defer { isLoading = false }

        contract = await SupabaseService.shared.fetchContract(forEOI: eoi.id)
        if let contractId = contract?.id {
            invoice = await SupabaseService.shared.fetchInvoice(forContract: contractId)
        }
    }

    // MARK: - Helpers

    private func statusColor(for status: ContractStatus) -> Color {
        switch status {
        case .draft: AVIATheme.textTertiary
        case .sent: AVIATheme.warning
        case .signed: AVIATheme.success
        case .cancelled: AVIATheme.destructive
        }
    }

    private func invoiceStatusColor(for status: InvoiceStatus) -> Color {
        switch status {
        case .draft: AVIATheme.textTertiary
        case .sent: AVIATheme.warning
        case .paid: AVIATheme.success
        case .overdue: AVIATheme.destructive
        case .cancelled: AVIATheme.textTertiary
        }
    }

    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return isoString }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

// MARK: - Raise Contract Sheet

struct RaiseContractSheet: View {
    let eoi: EOISubmissionRow
    let onCreated: (ContractRow) -> Void
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var notes = ""
    @State private var isProcessing = false
    @State private var showDocumentPicker = false
    @State private var selectedFileData: Data?
    @State private var selectedFileName: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    BentoCard(cornerRadius: 14) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.richtext.fill")
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.timelessBrown)
                                Text("Upload Contract PDF")
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.timelessBrown)
                            }

                            if let name = selectedFileName {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.fill")
                                        .foregroundStyle(AVIATheme.timelessBrown)
                                    Text(name)
                                        .font(.neueCaptionMedium)
                                        .foregroundStyle(AVIATheme.textPrimary)
                                    Spacer()
                                    Button {
                                        selectedFileData = nil
                                        selectedFileName = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(AVIATheme.textTertiary)
                                    }
                                }
                                .padding(12)
                                .background(AVIATheme.cardBackgroundAlt)
                                .clipShape(.rect(cornerRadius: 10))
                            } else {
                                Button {
                                    showDocumentPicker = true
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: "arrow.up.doc.fill")
                                            .font(.system(size: 28))
                                            .foregroundStyle(AVIATheme.timelessBrown)
                                        Text("Select PDF")
                                            .font(.neueCaptionMedium)
                                            .foregroundStyle(AVIATheme.timelessBrown)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 100)
                                    .background(AVIATheme.cardBackgroundAlt)
                                    .clipShape(.rect(cornerRadius: 10))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                                            .foregroundStyle(AVIATheme.surfaceBorder)
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }

                    BentoCard(cornerRadius: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textSecondary)
                            TextField("Optional notes...", text: $notes, axis: .vertical)
                                .font(.neueSubheadline)
                                .lineLimit(3...6)
                                .padding(12)
                                .background(AVIATheme.cardBackgroundAlt)
                                .clipShape(.rect(cornerRadius: 10))
                        }
                        .padding(16)
                    }

                    PremiumButton("Raise Contract", icon: "paperplane.fill", style: .primary) {
                        Task { await raiseContract() }
                    }
                    .disabled(isProcessing || selectedFileData == nil)
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .background(AVIATheme.background)
            .navigationTitle("Raise Contract")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.neueSubheadline)
                }
            }
            .fileImporter(
                isPresented: $showDocumentPicker,
                allowedContentTypes: [UTType.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url) else { return }
        selectedFileData = data
        selectedFileName = url.lastPathComponent
    }

    private func raiseContract() async {
        guard let fileData = selectedFileData else { return }
        isProcessing = true
        defer { isProcessing = false }

        guard let contract = await SupabaseService.shared.createContract(
            eoiId: eoi.id,
            packageAssignmentId: eoi.package_assignment_id,
            clientId: eoi.client_id,
            adminId: viewModel.currentUser.id,
            contractUrl: nil,
            notes: notes.isEmpty ? nil : notes
        ) else { return }

        let fileName = selectedFileName ?? "contract.pdf"
        let _ = await SupabaseService.shared.uploadContractPDF(
            contractId: contract.id,
            fileData: fileData,
            fileName: fileName
        )

        var updatedContract = contract
        updatedContract.status = "sent"
        updatedContract.sent_at = ISO8601DateFormatter().string(from: .now)

        await viewModel.notificationService.createNotification(
            recipientId: eoi.client_id,
            senderId: viewModel.currentUser.id,
            senderName: viewModel.currentUser.fullName,
            type: .contractRaised,
            title: "Contract Ready",
            message: "A contract is ready for your review for Lot \(eoi.lot_number)",
            referenceId: eoi.package_id,
            referenceType: "package"
        )

        onCreated(updatedContract)
        dismiss()
    }
}

// MARK: - Raise Invoice Sheet

struct RaiseInvoiceSheet: View {
    let eoi: EOISubmissionRow
    let contractId: String?
    let suggestedAmount: Double?
    let packagePrice: Double?
    let onCreated: (InvoiceRow) -> Void
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var amount = ""
    @State private var description = ""
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 14, to: .now)!
    @State private var notes = ""
    @State private var isProcessing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    BentoCard(cornerRadius: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.timelessBrown)
                                Text("Invoice Details")
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.timelessBrown)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Amount ($)")
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.textSecondary)
                                TextField("0.00", text: $amount)
                                    .font(.neueSubheadline)
                                    .keyboardType(.decimalPad)
                                    .padding(12)
                                    .background(AVIATheme.cardBackgroundAlt)
                                    .clipShape(.rect(cornerRadius: 10))
                                if let suggested = suggestedAmount {
                                    Button {
                                        amount = String(format: "%.2f", suggested)
                                    } label: {
                                        Text("Suggest 5% deposit: $\(String(format: "%.2f", suggested))")
                                            .font(.neueCaption)
                                            .foregroundStyle(AVIATheme.timelessBrown)
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Description")
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.textSecondary)
                                TextField("e.g. 5% Deposit for Package", text: $description)
                                    .font(.neueSubheadline)
                                    .padding(12)
                                    .background(AVIATheme.cardBackgroundAlt)
                                    .clipShape(.rect(cornerRadius: 10))
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Due Date")
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.textSecondary)
                                DatePicker("", selection: $dueDate, displayedComponents: .date)
                                    .labelsHidden()
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Notes")
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.textSecondary)
                                TextField("Optional notes...", text: $notes, axis: .vertical)
                                    .font(.neueSubheadline)
                                    .lineLimit(2...4)
                                    .padding(12)
                                    .background(AVIATheme.cardBackgroundAlt)
                                    .clipShape(.rect(cornerRadius: 10))
                            }
                        }
                        .padding(16)
                    }

                    PremiumButton("Raise Invoice", icon: "paperplane.fill", style: .primary) {
                        Task { await raiseInvoice() }
                    }
                    .disabled(isProcessing || amount.isEmpty)
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .background(AVIATheme.background)
            .navigationTitle("Raise Invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.neueSubheadline)
                }
            }
            .onAppear {
                if let suggested = suggestedAmount {
                    amount = String(format: "%.2f", suggested)
                }
                if let pkg = viewModel.allPackages.first(where: { $0.id == eoi.package_id }) {
                    description = "5% Deposit for \(pkg.title)"
                }
            }
        }
    }

    private func raiseInvoice() async {
        guard let parsedAmount = Double(amount) else { return }
        isProcessing = true
        defer { isProcessing = false }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let invoiceNum = "INV-\(String(eoi.id.prefix(8)).uppercased())"

        guard let invoice = await SupabaseService.shared.createInvoice(
            contractId: contractId,
            clientId: eoi.client_id,
            adminId: viewModel.currentUser.id,
            invoiceNumber: invoiceNum,
            description: description.isEmpty ? nil : description,
            amount: parsedAmount,
            packagePrice: packagePrice,
            dueDate: dateFormatter.string(from: dueDate),
            notes: notes.isEmpty ? nil : notes
        ) else { return }

        await viewModel.notificationService.createNotification(
            recipientId: eoi.client_id,
            senderId: viewModel.currentUser.id,
            senderName: viewModel.currentUser.fullName,
            type: .invoiceRaised,
            title: "Invoice Ready",
            message: "A deposit invoice of \(invoice.formattedAmount) has been raised for Lot \(eoi.lot_number)",
            referenceId: eoi.package_id,
            referenceType: "package"
        )

        onCreated(invoice)
        dismiss()
    }
}
