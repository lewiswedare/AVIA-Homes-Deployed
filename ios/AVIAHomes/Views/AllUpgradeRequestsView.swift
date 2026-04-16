import SwiftUI

struct AllUpgradeRequestsView: View {
    @Environment(SpecificationViewModel.self) private var specVM

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
                                    .foregroundStyle(AVIATheme.teal)
                                    .font(.neueCaption2)
                                Text(AVIATheme.formatCost(cost))
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.teal)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AVIATheme.teal.opacity(0.08))
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
                    }
                    .padding(14)
                    .background(AVIATheme.cardBackground)
                    .clipShape(.rect(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .navigationTitle("Upgrade Requests")
        .navigationBarTitleDisplayMode(.large)
    }

    private var upgradeCostSummary: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(AVIATheme.teal)
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
                .stroke(AVIATheme.teal.opacity(0.15), lineWidth: 1)
        }
    }

    private func upgradeStatusColor(_ status: UpgradeStatus) -> Color {
        switch status {
        case .pending: AVIATheme.warning
        case .quoted: Color(hex: "5B7DB1")
        case .approved: AVIATheme.success
        case .declined: AVIATheme.destructive
        }
    }
}
