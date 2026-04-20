import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// Contract upload + dual-confirmation flow.
///
/// Signing happens IN PERSON off-app. This screen lets either the client or
/// an admin upload the signed PDF, and requires BOTH parties to tick
/// "I confirm this is signed" before the contract moves to status `signed`.
struct ContractUploadView: View {
    let assignment: PackageAssignment
    let package: HouseLandPackage

    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var contract: ContractSignatureRow?
    @State private var isLoading = true
    @State private var isWorking = false
    @State private var showFileImporter = false
    @State private var errorMessage: String?

    private var isAdmin: Bool { viewModel.currentRole.isAnyStaffRole }
    private var isClient: Bool { viewModel.currentRole == .client }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    if isLoading {
                        ProgressView().padding(40)
                    } else {
                        documentCard
                        confirmationCard
                        if let msg = errorMessage {
                            Text(msg)
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.destructive)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .background(AVIATheme.background)
            .navigationTitle("Contract")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .font(.neueSubheadline)
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                Task { await handleFileImport(result) }
            }
            .task { await loadContract() }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        BentoCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Signed in person")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.timelessBrown)
                Text("Contract for \(package.title)")
                    .font(.neueHeadline)
                    .foregroundStyle(AVIATheme.textPrimary)
                Text("Upload a PDF of the signed contract, then both the client and admin need to confirm it’s signed.")
                    .font(.neueSubheadline)
                    .foregroundStyle(AVIATheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }

    // MARK: - Document Card

    private var documentCard: some View {
        BentoCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text("Signed Contract PDF")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Spacer()
                }

                if let contract = contract, let urlString = contract.contract_document_url, let url = URL(string: urlString) {
                    PDFThumbnailView(url: url)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    HStack(spacing: 8) {
                        if let uploadedAt = contract.contract_uploaded_at {
                            Label("Uploaded \(formatDate(uploadedAt))", systemImage: "checkmark.circle.fill")
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.success)
                        }
                        Spacer()
                        Link(destination: url) {
                            Label("Open", systemImage: "arrow.up.right.square")
                                .font(.neueCaption)
                        }
                    }
                    PremiumButton("Replace PDF", icon: "arrow.triangle.2.circlepath", style: .secondary) {
                        showFileImporter = true
                    }
                    .disabled(isWorking || contract.isFullyConfirmed)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "tray.and.arrow.up.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(AVIATheme.textTertiary)
                        Text("No PDF uploaded yet")
                            .font(.neueSubheadline)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)

                    PremiumButton("Upload Signed Contract PDF", icon: "arrow.up.doc.fill", style: .primary) {
                        showFileImporter = true
                    }
                    .disabled(isWorking)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Confirmation Card

    private var confirmationCard: some View {
        BentoCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text("Confirmations")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Spacer()
                    if let c = contract, c.isFullyConfirmed {
                        Text("COMPLETE")
                            .font(.neueCaption.bold())
                            .foregroundStyle(AVIATheme.success)
                    }
                }

                confirmationRow(
                    label: "Client confirms the contract is signed",
                    confirmedAt: contract?.client_confirmed_at,
                    canTick: isClient && contract?.hasDocument == true && contract?.isClientConfirmed == false,
                    action: { await tapConfirm(as: .client) }
                )

                Divider()

                confirmationRow(
                    label: "Admin confirms the contract is signed",
                    confirmedAt: contract?.admin_confirmed_at,
                    canTick: isAdmin && contract?.hasDocument == true && contract?.isAdminConfirmed == false,
                    action: { await tapConfirm(as: .admin) }
                )

                if let c = contract, !c.hasDocument {
                    Text("Upload the signed PDF before confirming.")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
            }
            .padding(16)
        }
    }

    private func confirmationRow(
        label: String,
        confirmedAt: String?,
        canTick: Bool,
        action: @escaping () async -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: confirmedAt != nil ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(confirmedAt != nil ? AVIATheme.success : AVIATheme.textTertiary)
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.neueSubheadline)
                    .foregroundStyle(AVIATheme.textPrimary)
                if let at = confirmedAt {
                    Text("Confirmed \(formatDate(at))")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textTertiary)
                } else if canTick {
                    Button {
                        Task { await action() }
                    } label: {
                        Text("I confirm this is signed")
                            .font(.neueCaption.bold())
                            .foregroundStyle(AVIATheme.timelessBrown)
                    }
                    .disabled(isWorking)
                } else {
                    Text("Awaiting confirmation")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
            }
            Spacer()
        }
    }

    // MARK: - Data

    private func loadContract() async {
        isLoading = true
        defer { isLoading = false }
        var fetched = await SupabaseService.shared.fetchContractSignature(forAssignment: assignment.id)
        // Auto-create the contract row if none exists yet and we have an
        // associated EOI — admins typically trigger this via the admin
        // review flow, but it's safe for a client to trigger too since
        // cs_insert RLS allows client_id = auth.uid().
        if fetched == nil {
            let clientId = firstSharedClientId() ?? viewModel.currentUser.id
            if let eoi = await SupabaseService.shared.fetchEOI(forAssignment: assignment.id) {
                fetched = await SupabaseService.shared.createContractRecord(
                    eoiId: eoi.id,
                    assignmentId: assignment.id,
                    clientId: clientId
                )
            }
        }
        contract = fetched
    }

    private func firstSharedClientId() -> String? {
        assignment.sharedWithClientIds.first
    }

    private func handleFileImport(_ result: Result<[URL], Error>) async {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Couldn’t access the selected file."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url) else {
            errorMessage = "Couldn’t read the PDF."
            return
        }
        guard let contract = contract else {
            errorMessage = "Contract not ready yet."
            return
        }
        isWorking = true
        defer { isWorking = false }

        let uploadedURL = await SupabaseService.shared.uploadContractDocument(
            contractId: contract.id,
            assignmentId: assignment.id,
            clientId: contract.client_id,
            fileData: data,
            fileName: url.lastPathComponent,
            uploadedBy: viewModel.currentUser.id
        )
        if uploadedURL == nil {
            errorMessage = "Upload failed. Please try again."
            AVIAHaptic.error.trigger()
            return
        }
        errorMessage = nil
        AVIAHaptic.success.trigger()
        await loadContract()
    }

    private func tapConfirm(as role: SupabaseService.ContractConfirmationRole) async {
        guard let contract = contract else { return }
        isWorking = true
        defer { isWorking = false }
        let ok = await SupabaseService.shared.confirmContract(
            contractId: contract.id,
            assignmentId: assignment.id,
            role: role,
            confirmedBy: viewModel.currentUser.id
        )
        if !ok {
            errorMessage = "Couldn’t record confirmation. Please try again."
            AVIAHaptic.error.trigger()
            return
        }
        errorMessage = nil
        AVIAHaptic.success.trigger()
        await loadContract()
    }

    private func formatDate(_ iso: String) -> String {
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso8601.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) ?? .now
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}

// MARK: - PDF Thumbnail

private struct PDFThumbnailView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePage
        view.displayDirection = .vertical
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        Task.detached {
            if let doc = PDFDocument(url: url) {
                await MainActor.run { view.document = doc }
            }
        }
    }
}
