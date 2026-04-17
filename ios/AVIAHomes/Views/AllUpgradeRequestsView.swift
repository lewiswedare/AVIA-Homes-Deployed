import SwiftUI

struct AllUpgradeRequestsView: View {
    @Environment(SpecificationViewModel.self) private var specVM
    @State private var selectedRequest: UpgradeRequest?

    private var totalCost: Double {
        specVM.upgradeRequests.compactMap(\.upgradeCost).reduce(0, +)
    }

    private var acceptedCost: Double {
        specVM.upgradeRequests
            .filter { $0.status == .approved }
            .compactMap(\.upgradeCost)
            .reduce(0, +)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if totalCost > 0 {
                    upgradeCostSummary
                }

                ForEach(specVM.upgradeRequests) { request in
                    Button {
                        if request.status == .quoted {
                            selectedRequest = request
                        }
                    } label: {
                        requestCard(request)
                    }
                    .buttonStyle(.plain)
                    .disabled(request.status != .quoted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .navigationTitle("Upgrade Requests")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedRequest) { request in
            UpgradeResponseSheet(request: request) {
                specVM.clientAcceptUpgradeCost(requestId: request.id)
                selectedRequest = nil
            } onDecline: {
                specVM.clientDeclineUpgradeCost(requestId: request.id)
                selectedRequest = nil
            }
        }
    }

    private func requestCard(_ request: UpgradeRequest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(request.itemName)
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text("\(request.categoryName) · \(request.fromTier.displayName) → \(request.toTier.displayName)")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                                Text(request.dateRequested.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                            }
                            Spacer()
                            StatusBadge(title: request.status.rawValue, color: upgradeStatusColor(request.status))
                        }

                        if let cost = request.upgradeCost, cost > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "tag.fill")
                                    .foregroundStyle(AVIATheme.timelessBrown)
                                    .font(.neueCaption2)
                                Text(AVIATheme.formatCost(cost))
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.timelessBrown)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AVIATheme.timelessBrown.opacity(0.08))
                            .clipShape(Capsule())
                        }

            if let notes = request.adminNotes, !notes.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                    Text(notes)
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AVIATheme.surfaceElevated)
                .clipShape(.rect(cornerRadius: 10))
            }

            if request.status == .quoted {
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .font(.neueCaption2)
                    Text("Tap to approve or decline")
                        .font(.neueCaption2Medium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.neueCaption2)
                }
                .foregroundStyle(AVIATheme.timelessBrown)
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            if request.status == .quoted {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AVIATheme.timelessBrown.opacity(0.3), lineWidth: 1)
            }
        }
    }

    private var upgradeCostSummary: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(AVIATheme.timelessBrown)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Upgrade Cost Summary")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("\(specVM.upgradeRequests.count) upgrade\(specVM.upgradeRequests.count == 1 ? "" : "s") requested")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                Spacer()
                Text(AVIATheme.formatCost(totalCost))
                    .font(.neueCorpMedium(22))
                    .foregroundStyle(AVIATheme.textPrimary)
            }

            if acceptedCost > 0 && acceptedCost != totalCost {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.success)
                    Text("Approved: \(AVIATheme.formatCost(acceptedCost))")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.success)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(AVIATheme.timelessBrown.opacity(0.15), lineWidth: 1)
        }
    }

    private func upgradeStatusColor(_ status: UpgradeStatus) -> Color {
        switch status {
        case .pending: AVIATheme.warning
        case .quoted: AVIATheme.timelessBrown
        case .approved: AVIATheme.success
        case .declined: AVIATheme.destructive
        }
    }
}

struct UpgradeResponseSheet: View {
    @Environment(\.dismiss) private var dismiss
    let request: UpgradeRequest
    let onApprove: () -> Void
    let onDecline: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(AVIATheme.timelessBrown)
                        Text("Upgrade Quote")
                            .font(.neueCorpMedium(22))
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text(request.itemName)
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("\(request.categoryName) · \(request.fromTier.displayName) → \(request.toTier.displayName)")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                    if let cost = request.upgradeCost, cost > 0 {
                        VStack(spacing: 6) {
                            Text("Upgrade Cost")
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)
                            Text(AVIATheme.formatCost(cost))
                                .font(.neueCorpMedium(36))
                                .foregroundStyle(AVIATheme.timelessBrown)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .background(AVIATheme.timelessBrown.opacity(0.08))
                        .clipShape(.rect(cornerRadius: 16))
                    }

                    if let notes = request.adminNotes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notes from Admin")
                                .font(.neueCaption2Medium)
                                .foregroundStyle(AVIATheme.textTertiary)
                            Text(notes)
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(AVIATheme.surfaceElevated)
                        .clipShape(.rect(cornerRadius: 12))
                    }

                    VStack(spacing: 10) {
                        Button(action: onApprove) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Approve Upgrade")
                            }
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(AVIATheme.success)
                            .clipShape(.rect(cornerRadius: 14))
                        }

                        Button(action: onDecline) {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark.circle")
                                Text("Decline")
                            }
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.destructive)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(AVIATheme.destructive.opacity(0.1))
                            .clipShape(.rect(cornerRadius: 14))
                        }
                    }

                    Text("Your response will be sent to admin for final confirmation.")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
            }
            .background(AVIATheme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
    }
}
