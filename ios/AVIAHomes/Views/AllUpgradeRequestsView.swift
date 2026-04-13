import SwiftUI

struct AllUpgradeRequestsView: View {
    @Environment(SpecificationViewModel.self) private var specVM

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(specVM.upgradeRequests) { request in
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

    private func upgradeStatusColor(_ status: UpgradeStatus) -> Color {
        switch status {
        case .pending: AVIATheme.warning
        case .quoted: Color(hex: "5B7DB1")
        case .approved: AVIATheme.success
        case .declined: AVIATheme.destructive
        }
    }
}
