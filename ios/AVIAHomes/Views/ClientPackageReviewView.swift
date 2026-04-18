import SwiftUI

struct ClientPackageReviewView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var selectedPackage: HouseLandPackage?
    @State private var showResponseSheet = false
    @State private var responsePackageId: String?

    private var sharedPackages: [HouseLandPackage] {
        viewModel.clientSharedPackages
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if sharedPackages.isEmpty {
                    emptyState
                } else {
                    statusSummary
                    ForEach(sharedPackages) { pkg in
                        NavigationLink(value: pkg) {
                            sharedPackageCard(package: pkg)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .refreshable { await viewModel.refreshAllData() }
        .background(AVIATheme.background)
        .navigationTitle("Shared Packages")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: HouseLandPackage.self) { pkg in
            PackageDetailView(package: pkg)
        }
        .navigationDestination(for: HomeDesign.self) { design in
            HomeDesignDetailView(design: design)
        }
        .navigationDestination(for: LandEstate.self) { estate in
            EstateDetailView(estate: estate)
        }
        .navigationDestination(for: SpecTier.self) { tier in
            SpecRangeDetailView(tier: tier)
        }
        .navigationDestination(for: Facade.self) { facade in
            FacadeDetailView(facade: facade)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 44))
                .foregroundStyle(AVIATheme.textTertiary)
            Text("No Packages Shared Yet")
                .font(.neueCorpMedium(20))
                .foregroundStyle(AVIATheme.textPrimary)
            Text("When your AVIA team shares house & land packages with you, they'll appear here for your review.")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private var statusSummary: some View {
        HStack(spacing: 12) {
            let pendingCount = sharedPackages.filter { pkg in
                viewModel.clientResponseForPackage(pkg.id, clientId: viewModel.currentUser.id)?.status == .pending ||
                viewModel.clientResponseForPackage(pkg.id, clientId: viewModel.currentUser.id) == nil
            }.count

            let acceptedCount = sharedPackages.filter { pkg in
                viewModel.clientResponseForPackage(pkg.id, clientId: viewModel.currentUser.id)?.status == .accepted
            }.count

            BentoCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    BentoIconCircle(icon: "clock.fill", color: AVIATheme.warning)
                    Text("\(pendingCount)")
                        .font(.neueCorpMedium(28))
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Awaiting Review")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            BentoCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    BentoIconCircle(icon: "checkmark.circle.fill", color: AVIATheme.success)
                    Text("\(acceptedCount)")
                        .font(.neueCorpMedium(28))
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Accepted")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func sharedPackageCard(package: HouseLandPackage) -> some View {
        let response = viewModel.clientResponseForPackage(package.id, clientId: viewModel.currentUser.id)
        return BentoCard(cornerRadius: 16) {
            VStack(spacing: 0) {
                Color(AVIATheme.surfaceElevated)
                    .frame(height: 140)
                    .overlay {
                        AsyncImage(url: URL(string: package.imageURL)) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .overlay(alignment: .topTrailing) {
                        responseStatusBadge(response?.status)
                            .padding(10)
                    }
                    .clipShape(.rect(cornerRadii: .init(topLeading: 16, topTrailing: 16)))

                VStack(alignment: .leading, spacing: 8) {
                    Text(package.title)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.neueCorp(10))
                            .foregroundStyle(AVIATheme.timelessBrown)
                        Text(package.location)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .lineLimit(1)
                    }

                    HStack {
                        Text(package.price)
                            .font(.neueCorpMedium(18))
                            .foregroundStyle(AVIATheme.timelessBrown)
                        Spacer()
                        if response?.status == .pending || response == nil {
                            Text("Tap to review")
                                .font(.neueCaption2Medium)
                                .foregroundStyle(AVIATheme.timelessBrown)
                        }
                    }
                }
                .padding(14)
            }
        }
    }

    private func responseStatusBadge(_ status: PackageResponseStatus?) -> some View {
        let displayStatus = status ?? .pending
        return HStack(spacing: 4) {
            Image(systemName: displayStatus.icon)
                .font(.system(size: 9, weight: .bold))
            Text(displayStatus.rawValue)
                .font(.neueCorpMedium(9))
                .kerning(0.3)
        }
        .foregroundStyle(AVIATheme.aviaWhite)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(statusColor(displayStatus))
        .clipShape(Capsule())
    }

    private func statusColor(_ status: PackageResponseStatus) -> Color {
        switch status {
        case .pending: AVIATheme.warning
        case .accepted: AVIATheme.success
        case .declined: AVIATheme.destructive
        }
    }
}
