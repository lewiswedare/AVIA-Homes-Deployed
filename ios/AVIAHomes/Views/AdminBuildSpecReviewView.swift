import SwiftUI

struct AdminBuildSpecReviewView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var viewModel = BuildSpecViewModel()
    @State private var showApproveAllAlert = false
    @State private var showReopenAlert = false
    @State private var upgradeCostInputs: [String: (cost: String, note: String)] = [:]
    let buildId: String
    let clientName: String
    var clientId: String = ""

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
        .overlay(alignment: .bottom) { toastOverlay }
    }

    private var specContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                adminStatusBanner
                clientInfoCard

                if viewModel.upgradeRequestedItems.count > 0 {
                    upgradeRequestsSummary
                }

                ForEach(viewModel.groupedSelections, id: \.categoryId) { group in
                    BuildSpecCategorySection(
                        categoryName: group.category,
                        items: group.items,
                        isEditable: false,
                        isAdmin: true,
                        onAdminApprove: { id in
                            viewModel.adminApproveItem(selectionId: id)
                        },
                        onAdminNotes: { id, notes in
                            viewModel.adminAddNotes(selectionId: id, notes: notes)
                        }
                    )
                }

                adminActionButtons

                if !viewModel.documents.isEmpty {
                    documentSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }

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
        case .reopenedByAdmin: Color(hex: "8B5CF6")
        case .approved: AVIATheme.success
        case .amendedByAdmin: Color(hex: "8B5CF6")
        }
    }

    private var adminStatusTitle: String {
        switch viewModel.overallStatus {
        case .draft, .clientReviewing: "Client Has Not Submitted"
        case .awaitingAdmin: "Awaiting Your Review"
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

    private var upgradeRequestsSummary: some View {
        BentoCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(AVIATheme.warning)
                    Text("Upgrade Requests (\(viewModel.upgradeRequestedItems.count))")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                }

                ForEach(viewModel.upgradeRequestedItems) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(AVIATheme.warning)
                                .frame(width: 6, height: 6)
                            Text(item.snapshotName)
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)
                            if let notes = item.clientNotes, !notes.isEmpty {
                                Text("— \(notes)")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                                    .lineLimit(1)
                            }
                        }

                        HStack(spacing: 8) {
                            TextField("Cost ($)", text: Binding(
                                get: { upgradeCostInputs[item.id]?.cost ?? "" },
                                set: { upgradeCostInputs[item.id] = (cost: $0, note: upgradeCostInputs[item.id]?.note ?? "") }
                            ))
                            .keyboardType(.decimalPad)
                            .font(.neueCaption)
                            .padding(8)
                            .background(AVIATheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .frame(width: 100)

                            TextField("Cost note...", text: Binding(
                                get: { upgradeCostInputs[item.id]?.note ?? "" },
                                set: { upgradeCostInputs[item.id] = (cost: upgradeCostInputs[item.id]?.cost ?? "", note: $0) }
                            ))
                            .font(.neueCaption)
                            .padding(8)
                            .background(AVIATheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            Button("Set") {
                                let costStr = upgradeCostInputs[item.id]?.cost ?? ""
                                let noteStr = upgradeCostInputs[item.id]?.note ?? ""
                                let cost = Double(costStr)
                                viewModel.adminSetUpgradeCost(selectionId: item.id, cost: cost, note: noteStr.isEmpty ? nil : noteStr)
                            }
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.teal)
                        }

                        if let existingCost = item.upgradeCost {
                            Text("Current: $\(existingCost, specifier: "%.2f")\(item.upgradeCostNote.map { " — \($0)" } ?? "")")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.success)
                        }
                    }
                }
            }
            .padding(14)
        }
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
