import SwiftUI

struct PartnerPackagesTab: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var selectedPackageForSharing: HouseLandPackage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    sharingStats
                    PackagesContentView()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(AVIATheme.background)
            .navigationTitle("My Packages")
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(viewModel.packagesForCurrentUser()) { pkg in
                            Button {
                                selectedPackageForSharing = pkg
                            } label: {
                                Label(pkg.title, systemImage: "paperplane")
                            }
                        }
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.neueSubheadline)
                            .foregroundStyle(AVIATheme.timelessBrown)
                    }
                }
            }
            .sheet(item: $selectedPackageForSharing) { pkg in
                PartnerPackageSharingView(package: pkg)
            }
        }
    }

    private var sharingStats: some View {
        let packages = viewModel.packagesForCurrentUser()
        let sharedCount = packages.filter { pkg in
            !viewModel.partnerSharedClientsForPackage(pkg.id).isEmpty
        }.count
        let pendingResponses = packages.reduce(0) { count, pkg in
            let responses = viewModel.assignmentForPackage(pkg.id)?.clientResponses ?? []
            return count + responses.filter { $0.status == .pending }.count
        }

        return HStack(spacing: 12) {
            BentoCard(cornerRadius: 13) {
                VStack(alignment: .leading, spacing: 6) {
                    BentoIconCircle(icon: "paperplane.fill", color: AVIATheme.timelessBrown)
                    Text("\(sharedCount)")
                        .font(.neueCorpMedium(32))
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Shared")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            BentoCard(cornerRadius: 13) {
                VStack(alignment: .leading, spacing: 6) {
                    BentoIconCircle(icon: "clock.fill", color: AVIATheme.warning)
                    Text("\(pendingResponses)")
                        .font(.neueCorpMedium(32))
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Pending")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
