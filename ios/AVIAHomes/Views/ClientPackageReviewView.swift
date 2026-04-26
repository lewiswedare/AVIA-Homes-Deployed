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
                        sharedPackageCard(package: pkg)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .hapticRefresh { await viewModel.refreshAllData() }
        .background(AVIATheme.background)
        .navigationTitle("Shared Packages")
        .navigationBarTitleDisplayMode(.large)
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

            BentoCard(cornerRadius: 13) {
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

            BentoCard(cornerRadius: 13) {
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
        let design = package.matchedDesign
        let facade = package.selectedFacadeId.flatMap { viewModel.findFacade(byId: $0) }
        let tier = package.specTier

        return BentoCard(cornerRadius: 13) {
            VStack(spacing: 0) {
                NavigationLink {
                    PackageDetailView(package: package)
                } label: {
                    VStack(spacing: 0) {
                        Color(AVIATheme.surfaceElevated)
                            .frame(height: 160)
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

                        VStack(alignment: .leading, spacing: 10) {
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
                                Spacer()
                                Text(package.price)
                                    .font(.neueCorpMedium(18))
                                    .foregroundStyle(AVIATheme.timelessBrown)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 14)
                        .padding(.bottom, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.pressable(.subtle))

                VStack(alignment: .leading, spacing: 10) {
                    Divider()

                    VStack(spacing: 8) {
                        if let design {
                            NavigationLink {
                                HomeDesignDetailView(design: design)
                            } label: {
                                detailRow(icon: "house.fill", title: design.name, subtitle: "Home Design · \(design.bedrooms) Bed · \(design.bathrooms) Bath")
                            }
                            .buttonStyle(.pressable(.subtle))
                        }

                        NavigationLink {
                            SpecRangeDetailView(tier: tier)
                        } label: {
                            detailRow(icon: "square.stack.3d.up.fill", title: "\(tier.displayName) Spec Range", subtitle: tier.tagline)
                        }
                        .buttonStyle(.pressable(.subtle))

                        if let facade {
                            NavigationLink {
                                FacadeDetailView(facade: facade)
                            } label: {
                                detailRow(icon: "building.2.fill", title: facade.name, subtitle: "Facade · \(facade.style)")
                            }
                            .buttonStyle(.pressable(.subtle))
                        }
                    }

                    if response?.status == .pending || response == nil {
                        NavigationLink {
                            PackageDetailView(package: package)
                        } label: {
                            HStack {
                                Spacer()
                                Text("Tap to review & respond")
                                    .font(.neueCaption2Medium)
                                    .foregroundStyle(AVIATheme.timelessBrown)
                                Image(systemName: "arrow.up.right.circle.fill")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.timelessBrown)
                            }
                        }
                        .buttonStyle(.pressable(.subtle))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
    }

    private func detailRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AVIATheme.timelessBrown)
                .frame(width: 32, height: 32)
                .background(AVIATheme.timelessBrown.opacity(0.1))
                .clipShape(.rect(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AVIATheme.surfaceElevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func responseStatusBadge(_ status: PackageResponseStatus?) -> some View {
        let displayStatus = status ?? .pending
        let color = statusColor(displayStatus)
        return HStack(spacing: 4) {
            Image(systemName: displayStatus.icon)
                .font(.system(size: 9, weight: .bold))
            Text(displayStatus.rawValue)
                .font(.neueCorpMedium(9))
                .kerning(0.3)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(color, lineWidth: 1))
    }

    private func statusColor(_ status: PackageResponseStatus) -> Color {
        switch status {
        case .pending: AVIATheme.warning
        case .accepted: AVIATheme.success
        case .declined: AVIATheme.destructive
        }
    }
}
