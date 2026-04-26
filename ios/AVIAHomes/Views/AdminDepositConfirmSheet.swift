import SwiftUI
import Supabase
import UniformTypeIdentifiers

struct AdminDepositConfirmSheet: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    let assignment: PackageAssignment

    @State private var depositAmount: String = ""
    @State private var dueDate: Date = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
    @State private var isUploading = false
    @State private var isSaving = false
    @State private var showDocPicker = false
    @State private var uploadedFileName: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    BentoCard(cornerRadius: 13) {
                        VStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("DEPOSIT AMOUNT")
                                    .font(.neueCaption2Medium)
                                    .foregroundStyle(AVIATheme.textTertiary)
                                    .kerning(0.5)
                                HStack {
                                    Text("$")
                                        .font(.neueCorpMedium(18))
                                        .foregroundStyle(AVIATheme.textSecondary)
                                    TextField("0.00", text: $depositAmount)
                                        .font(.neueCorpMedium(18))
                                        .keyboardType(.decimalPad)
                                }
                            }

                            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("DUE DATE")
                                    .font(.neueCaption2Medium)
                                    .foregroundStyle(AVIATheme.textTertiary)
                                    .kerning(0.5)
                                DatePicker("", selection: $dueDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(AVIATheme.timelessBrown)
                            }

                            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("INVOICE PDF")
                                    .font(.neueCaption2Medium)
                                    .foregroundStyle(AVIATheme.textTertiary)
                                    .kerning(0.5)
                                if let name = uploadedFileName {
                                    HStack {
                                        Image(systemName: "doc.fill")
                                            .foregroundStyle(AVIATheme.success)
                                        Text(name)
                                            .font(.neueCaption)
                                            .foregroundStyle(AVIATheme.textPrimary)
                                    }
                                }
                                PremiumButton(uploadedFileName == nil ? "Upload Invoice PDF" : "Replace Invoice", icon: "doc.badge.plus", style: .secondary) {
                                    showDocPicker = true
                                }
                                .disabled(isUploading)
                            }
                        }
                        .padding(16)
                    }

                    PremiumButton("Confirm Package", icon: "checkmark.seal.fill", style: .primary) {
                        Task { await confirmDeposit() }
                    }
                    .disabled(depositAmount.isEmpty || isSaving)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(AVIATheme.background)
            .navigationTitle("Deposit Confirmation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.neueSubheadline)
                }
            }
            .fileImporter(isPresented: $showDocPicker, allowedContentTypes: [UTType.pdf]) { result in
                handleFileImport(result)
            }
        }
    }

    private func handleFileImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        isUploading = true
        uploadedFileName = url.lastPathComponent

        Task {
            defer { isUploading = false }
            guard let data = try? Data(contentsOf: url) else { return }
            let clientIds = assignment.sharedWithClientIds
            guard let buildId = viewModel.clientBuildsForCurrentUser.first(where: { build in
                clientIds.contains(where: { build.hasClient(id: $0) })
            })?.id else { return }

            _ = await SupabaseService.shared.uploadDocument(
                buildId: buildId,
                clientIds: clientIds,
                name: "Deposit Invoice",
                category: .financial,
                fileData: data,
                fileName: url.lastPathComponent
            )
        }
    }

    private func confirmDeposit() async {
        isSaving = true
        defer { isSaving = false }

        let iso = ISO8601DateFormatter()
        let amount = Double(depositAmount) ?? 0
        let dueDateStr = iso.string(from: dueDate)

        let fields: [String: AnyJSON] = [
            "deposit_amount": .double(amount),
            "deposit_due_date": .string(dueDateStr),
            "deposit_status": .string("invoiced"),
            "admin_confirmed_by": .string(viewModel.currentUser.id),
            "admin_confirmed_at": .string(iso.string(from: .now))
        ]

        _ = await SupabaseService.shared.updatePackageAssignmentFields(assignmentId: assignment.id, fields: fields)

        for clientId in assignment.sharedWithClientIds {
            await viewModel.notificationService.createNotification(
                recipientId: clientId,
                senderId: viewModel.currentUser.id,
                senderName: viewModel.currentUser.fullName,
                type: .depositInvoice,
                title: "Deposit Invoice Ready",
                message: "Your deposit invoice is ready to view",
                referenceId: assignment.id,
                referenceType: "package_assignment"
            )
        }

        await viewModel.refreshBuildsAndAssignments()
        dismiss()
    }
}

struct AdminMarkDepositReceivedButton: View {
    @Environment(AppViewModel.self) private var viewModel
    let assignment: PackageAssignment
    @State private var showConfirm = false

    var body: some View {
        if assignment.depositStatus == "invoiced" {
            PremiumButton("Mark Deposit Received", icon: "checkmark.seal.fill", style: .primary) {
                showConfirm = true
            }
            .alert("Confirm Deposit Received", isPresented: $showConfirm) {
                Button("Confirm") {
                    Task { await markReceived() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Mark this deposit as received? This will update the package status.")
            }
        }
    }

    private func markReceived() async {
        let fields: [String: AnyJSON] = [
            "deposit_status": .string("received")
        ]
        _ = await SupabaseService.shared.updatePackageAssignmentFields(assignmentId: assignment.id, fields: fields)

        for clientId in assignment.sharedWithClientIds {
            await viewModel.notificationService.createNotification(
                recipientId: clientId,
                senderId: viewModel.currentUser.id,
                senderName: viewModel.currentUser.fullName,
                type: .depositReceived,
                title: "Deposit Received",
                message: "Your deposit has been received",
                referenceId: assignment.id,
                referenceType: "package_assignment"
            )
        }

        await viewModel.refreshBuildsAndAssignments()
    }
}
