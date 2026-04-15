import SwiftUI

struct ClientContractListView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var contracts: [ContractRow] = []
    @State private var isLoading = true
    @State private var selectedContract: ContractRow?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else if contracts.isEmpty {
                    emptyState
                } else {
                    ForEach(contracts) { contract in
                        contractCard(contract)
                            .onTapGesture { selectedContract = contract }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .navigationTitle("My Contracts")
        .navigationBarTitleDisplayMode(.large)
        .task { await loadContracts() }
        .refreshable { await loadContracts() }
        .sheet(item: $selectedContract) { contract in
            ClientContractDetailSheet(contract: contract, onUpdate: { await loadContracts() })
        }
    }

    private func contractCard(_ contract: ContractRow) -> some View {
        BentoCard(cornerRadius: 14) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.richtext.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AVIATheme.teal)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Contract")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        if let date = contract.created_at {
                            Text(formatDate(date))
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                    }
                    Spacer()
                    StatusBadge(title: contract.displayStatus, color: statusColor(for: contract.statusEnum))
                    Image(systemName: "chevron.right")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                .padding(16)

                if contract.statusEnum == .sent {
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                    HStack(spacing: 6) {
                        Image(systemName: "signature")
                            .font(.system(size: 10))
                            .foregroundStyle(AVIATheme.teal)
                        Text("Ready for your signature")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.teal)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AVIATheme.teal.opacity(0.05))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(AVIATheme.textTertiary)
            Text("No Contracts")
                .font(.neueCorpMedium(20))
                .foregroundStyle(AVIATheme.textPrimary)
            Text("You don't have any contracts yet.")
                .font(.neueSubheadline)
                .foregroundStyle(AVIATheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func loadContracts() async {
        isLoading = true
        defer { isLoading = false }
        contracts = await SupabaseService.shared.fetchContractsForClient(clientId: viewModel.currentUser.id)
    }

    private func statusColor(for status: ContractStatus) -> Color {
        switch status {
        case .draft: AVIATheme.textTertiary
        case .sent: AVIATheme.warning
        case .signed: AVIATheme.success
        case .cancelled: AVIATheme.destructive
        }
    }

    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return isoString }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Client Contract Detail Sheet

struct ClientContractDetailSheet: View {
    let contract: ContractRow
    let onUpdate: () async -> Void
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isSigning = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Status header
                    BentoCard(cornerRadius: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: contract.statusEnum.icon)
                                .font(.system(size: 24))
                                .foregroundStyle(headerColor)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Contract")
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text("Status: \(contract.displayStatus)")
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                            Spacer()
                            StatusBadge(title: contract.displayStatus, color: headerColor)
                        }
                        .padding(16)
                    }

                    // PDF viewer link
                    if let url = contract.contract_url, let pdfURL = URL(string: url) {
                        BentoCard(cornerRadius: 14) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.text.fill")
                                        .font(.neueCaption)
                                        .foregroundStyle(AVIATheme.teal)
                                    Text("Contract Document")
                                        .font(.neueSubheadlineMedium)
                                        .foregroundStyle(AVIATheme.teal)
                                }

                                Link(destination: pdfURL) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.neueCaption)
                                        Text("View Contract PDF")
                                            .font(.neueCaptionMedium)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .foregroundStyle(AVIATheme.teal)
                                    .background(AVIATheme.teal.opacity(0.1))
                                    .clipShape(.rect(cornerRadius: 10))
                                }
                            }
                            .padding(16)
                        }
                    }

                    // Notes
                    if let notes = contract.notes, !notes.isEmpty {
                        BentoCard(cornerRadius: 14) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "note.text")
                                        .font(.neueCaption)
                                        .foregroundStyle(AVIATheme.teal)
                                    Text("Notes")
                                        .font(.neueSubheadlineMedium)
                                        .foregroundStyle(AVIATheme.teal)
                                }
                                Text(notes)
                                    .font(.neueSubheadline)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                            .padding(16)
                        }
                    }

                    // Sign button
                    if contract.statusEnum == .sent {
                        PremiumButton("Sign Contract", icon: "signature", style: .primary) {
                            Task { await signContract() }
                        }
                        .disabled(isSigning)
                    }

                    // Signed info
                    if contract.statusEnum == .signed {
                        BentoCard(cornerRadius: 14) {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(AVIATheme.success)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Contract Signed")
                                        .font(.neueSubheadlineMedium)
                                        .foregroundStyle(AVIATheme.textPrimary)
                                    if let signedAt = contract.signed_at {
                                        Text(formatDate(signedAt))
                                            .font(.neueCaption)
                                            .foregroundStyle(AVIATheme.textTertiary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(16)
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .background(AVIATheme.background)
            .navigationTitle("Contract Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .font(.neueSubheadline)
                }
            }
        }
    }

    private var headerColor: Color {
        switch contract.statusEnum {
        case .draft: AVIATheme.textTertiary
        case .sent: AVIATheme.warning
        case .signed: AVIATheme.success
        case .cancelled: AVIATheme.destructive
        }
    }

    private func signContract() async {
        isSigning = true
        defer { isSigning = false }

        let success = await SupabaseService.shared.markContractSigned(contractId: contract.id)
        guard success else { return }

        // Notify admins
        for user in viewModel.allRegisteredUsers where user.role.canManagePipeline {
            guard user.id != viewModel.currentUser.id else { continue }
            await viewModel.notificationService.createNotification(
                recipientId: user.id,
                senderId: viewModel.currentUser.id,
                senderName: viewModel.currentUser.fullName,
                type: .contractSigned,
                title: "Contract Signed",
                message: "\(viewModel.currentUser.fullName) has signed a contract",
                referenceId: contract.id,
                referenceType: "contract"
            )
        }

        await onUpdate()
        dismiss()
    }

    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return isoString }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

extension ContractRow: @retroactive Hashable {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    nonisolated static func == (lhs: ContractRow, rhs: ContractRow) -> Bool {
        lhs.id == rhs.id
    }
}
