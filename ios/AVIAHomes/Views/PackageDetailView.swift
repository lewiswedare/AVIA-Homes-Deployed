import SwiftUI

struct PackageDetailView: View {
    let package: HouseLandPackage
    @Environment(AppViewModel.self) private var viewModel
    @State private var showPackageSharing = false
    @State private var showSpecComparison = false
    @State private var showDeclineConfirmation = false
    @State private var showEOIForm = false
    @State private var showContractSigning = false
    @State private var contractRecord: ContractSignatureRow?

    private var canSharePackages: Bool {
        viewModel.currentRole.canAllocatePackages || viewModel.currentRole == .staff
    }

    private var isClientWithAssignedPackage: Bool {
        viewModel.currentRole == .client &&
        viewModel.clientSharedPackages.contains(where: { $0.id == package.id })
    }

    private var currentResponse: ClientPackageResponse? {
        viewModel.clientResponseForPackage(package.id, clientId: viewModel.currentUser.id)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                contentSection
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(AVIATheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(package.title)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    if canSharePackages {
                        Button {
                            showPackageSharing = true
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .font(.neueSubheadline)
                        }
                        .sensoryFeedback(.impact(weight: .light), trigger: showPackageSharing)
                    }
                    ShareLink(
                        item: URL(string: "https://apps.apple.com/app/avia-homes/id0000000000")!,
                        subject: Text("AVIA Homes — \(package.title)"),
                        message: Text("Check out this AVIA package: \(package.title) — \(package.price). Download the AVIA Homes app to view the full package details: https://apps.apple.com/app/avia-homes/id0000000000")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.neueSubheadline)
                    }
                }
            }
        }
        .sheet(isPresented: $showEOIForm) {
            if let assign = assignment {
                EOIFormView(package: package, assignment: assign)
            }
        }
        .sheet(isPresented: $showContractSigning) {
            if let assign = assignment {
                ContractUploadView(assignment: assign, package: package)
            }
        }
        .task(id: assignment?.contractStatus ?? "") {
            if let assign = assignment,
               assign.contractStatus == "awaiting_contract"
                || assign.contractStatus == "awaiting_signature"
                || assign.contractStatus == "awaiting_confirmation"
                || assign.contractStatus == "signed" {
                contractRecord = await SupabaseService.shared.fetchContractSignature(forAssignment: assign.id)
            }
        }
        .onChange(of: showContractSigning) { _, isShowing in
            if !isShowing {
                Task {
                    await viewModel.loadAssignmentsFromSupabase()
                    if let assign = assignment {
                        contractRecord = await SupabaseService.shared.fetchContractSignature(forAssignment: assign.id)
                    }
                }
            }
        }
        .sheet(isPresented: $showPackageSharing) {
            if viewModel.currentRole == .partner {
                PartnerPackageSharingView(package: package)
            } else {
                StaffPackageSharingView(package: package)
            }
        }
        .navigationDestination(isPresented: $showSpecComparison) {
            SpecRangeComparisonOverviewView()
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        Color(AVIATheme.surfaceElevated)
            .frame(height: 420)
            .overlay {
                AsyncImage(url: URL(string: package.imageURL)) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else if phase.error != nil {
                        Image(systemName: "house.and.flag.fill")
                            .font(.neueCorpMedium(56))
                            .foregroundStyle(AVIATheme.timelessBrown.opacity(0.2))
                    } else {
                        ProgressView()
                    }
                }
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0.0),
                        .init(color: AVIATheme.background.opacity(0.3), location: 0.4),
                        .init(color: AVIATheme.background.opacity(0.7), location: 0.7),
                        .init(color: AVIATheme.background.opacity(0.92), location: 0.9),
                        .init(color: AVIATheme.background, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 240)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(package.title)
                        .font(.neueCorpMedium(28))
                        .foregroundStyle(AVIATheme.textPrimary)
                    HStack(spacing: 12) {
                        Text(package.price)
                            .font(.neueCorpMedium(18))
                            .foregroundStyle(AVIATheme.timelessBrown)
                        Text("·")
                            .foregroundStyle(AVIATheme.textTertiary)
                        Text(package.location)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .clipped()
    }

    // MARK: - Content

    private var contentSection: some View {
        VStack(spacing: 28) {
            titleBlock
            priceBreakdown
            landDetailsSection
            houseDesignSection
            facadeSectionIfAvailable
            specificationSection
            inclusionsSection
            estateSection
            ctaSection
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 48)
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Spacer()
                statusBadge(package.status)
            }

            if package.isNew {
                AVIAChip("NEW LISTING")
            }
        }
    }

    // MARK: - Price Breakdown

    private var priceBreakdown: some View {
        VStack(spacing: 12) {
            HStack {
                Text("PACKAGE PRICE")
                    .font(.neueCaption2Medium)
                    .kerning(1.0)
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(AVIATheme.timelessBrown)
                            .frame(width: 3)
                    }
                Spacer()
            }

            BentoCard(cornerRadius: 16) {
                VStack(spacing: 0) {
                    HStack {
                        Text(package.price)
                            .font(.neueCorpMedium(32))
                            .foregroundStyle(AVIATheme.timelessBrown)
                        Spacer()
                        Text("TURNKEY")
                            .font(.neueCorpMedium(9))
                            .kerning(0.8)
                            .foregroundStyle(AVIATheme.timelessBrown)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AVIATheme.timelessBrown.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .padding(16)

                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                    HStack(spacing: 0) {
                        VStack(spacing: 4) {
                            Text(package.landPrice)
                                .font(.neueCorpMedium(18))
                                .foregroundStyle(AVIATheme.textPrimary)
                            Text("Land")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                        .frame(maxWidth: .infinity)

                        Rectangle().fill(AVIATheme.surfaceBorder).frame(width: 1, height: 40)

                        VStack(spacing: 4) {
                            Text(package.housePrice)
                                .font(.neueCorpMedium(18))
                                .foregroundStyle(AVIATheme.textPrimary)
                            Text("House")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                        .frame(maxWidth: .infinity)

                        Rectangle().fill(AVIATheme.surfaceBorder).frame(width: 1, height: 40)

                        VStack(spacing: 4) {
                            Text(package.specTier.displayName)
                                .font(.neueCorpMedium(14))
                                .foregroundStyle(AVIATheme.textPrimary)
                            Text("Spec Range")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 16)
                }
            }
        }
    }

    // MARK: - Land Details

    private var landDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LAND DETAILS")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.timelessBrown)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(AVIATheme.timelessBrown)
                        .frame(width: 3)
                }

            BentoCard(cornerRadius: 16) {
                VStack(spacing: 0) {
                    detailRow(icon: "number", label: "Lot", value: package.lotNumber)
                    detailDivider
                    detailRow(icon: "square.dashed", label: "Lot Size", value: package.lotSize)
                    detailDivider
                    detailRow(icon: "arrow.left.and.right", label: "Frontage", value: package.lotFrontage)
                    detailDivider
                    detailRow(icon: "arrow.up.and.down", label: "Depth", value: package.lotDepth)
                    detailDivider
                    detailRow(icon: "map.fill", label: "Estate", value: package.estate)
                    detailDivider
                    detailRow(icon: "building.columns.fill", label: "Council", value: package.council)
                    detailDivider
                    detailRow(icon: "doc.text.fill", label: "Zoning", value: package.zoning)
                    detailDivider
                    detailRow(icon: "calendar", label: "Title Status", value: package.titleDate)
                }
            }
        }
    }

    // MARK: - House Design

    private var houseDesignSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOME DESIGN")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.timelessBrown)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(AVIATheme.timelessBrown)
                        .frame(width: 3)
                }

            if let design = viewModel.findDesign(byName: package.homeDesign) {
                homeDesignCard(for: design)

                NavigationLink(value: design) {
                    HStack(spacing: 8) {
                        Image(systemName: "house.fill")
                            .font(.neueCaptionMedium)
                        Text("View Full \(design.name) Design Details")
                            .font(.neueCaptionMedium)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.neueCaption2)
                    }
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AVIATheme.timelessBrown.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 12))
                }
            } else {
                BentoCard(cornerRadius: 16) {
                    VStack(spacing: 0) {
                        detailRow(icon: "house.fill", label: "Design", value: package.homeDesign)
                        detailDivider
                        detailRow(icon: "bed.double.fill", label: "Bedrooms", value: "\(package.bedrooms)")
                        detailDivider
                        detailRow(icon: "shower.fill", label: "Bathrooms", value: "\(package.bathrooms)")
                        detailDivider
                        detailRow(icon: "car.fill", label: "Garage", value: "\(package.garages)-car")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func homeDesignCard(for design: HomeDesign) -> some View {
        NavigationLink(value: design) {
            BentoCard(cornerRadius: 20) {
                VStack(spacing: 0) {
                    Color(AVIATheme.surfaceElevated)
                        .frame(height: 240)
                        .overlay {
                            AsyncImage(url: URL(string: design.imageURL)) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else if phase.error != nil {
                                    Image(systemName: "house.fill")
                                        .font(.system(size: 48))
                                        .foregroundStyle(AVIATheme.timelessBrown.opacity(0.2))
                                } else {
                                    ProgressView()
                                }
                            }
                            .allowsHitTesting(false)
                        }
                        .overlay(alignment: .topLeading) {
                            AVIAChip(design.storeys == 2 ? "DOUBLE STOREY" : "SINGLE STOREY", onLight: false)
                                .padding(12)
                        }
                        .overlay(alignment: .bottomLeading) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(design.name)
                                    .font(.neueCorpMedium(26))
                                    .foregroundStyle(AVIATheme.aviaWhite)
                                Text(String(format: "%.0f m² of living space", design.squareMeters))
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.aviaWhite.opacity(0.9))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color.clear, AVIATheme.aviaBlack.opacity(0.55)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                        .clipShape(.rect(cornerRadii: .init(topLeading: 20, topTrailing: 20)))

                    VStack(spacing: 16) {
                        HStack(spacing: 0) {
                            houseStatPill(value: "\(design.bedrooms)", label: "Bed", icon: "bed.double.fill")
                            houseStatDivider
                            houseStatPill(value: "\(design.bathrooms)", label: "Bath", icon: "shower.fill")
                            houseStatDivider
                            houseStatPill(value: "\(design.garages)", label: "Car", icon: "car.fill")
                            houseStatDivider
                            houseStatPill(value: "\(design.livingAreas)", label: "Living", icon: "sofa.fill")
                        }
                        .padding(.vertical, 14)
                        .background(AVIATheme.surfaceElevated)
                        .clipShape(.rect(cornerRadius: 14))

                        VStack(alignment: .leading, spacing: 10) {
                            Text("HOUSE DIMENSIONS")
                                .font(.neueCaption2Medium)
                                .kerning(1.0)
                                .foregroundStyle(AVIATheme.timelessBrown)

                            HStack(spacing: 10) {
                                dimensionStat(
                                    icon: "square.dashed",
                                    value: String(format: "%.0f", design.squareMeters),
                                    unit: "m²",
                                    label: "Total Living"
                                )
                                dimensionStat(
                                    icon: "arrow.left.and.right",
                                    value: String(format: "%.1f", design.houseWidth),
                                    unit: "m",
                                    label: "Width"
                                )
                                dimensionStat(
                                    icon: "arrow.up.and.down",
                                    value: String(format: "%.1f", design.houseLength),
                                    unit: "m",
                                    label: "Length"
                                )
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "ruler")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(AVIATheme.textTertiary)
                                Text("Minimum lot width:")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                                Text(String(format: "%.1fm", design.lotWidth))
                                    .font(.neueCaption2Medium)
                                    .foregroundStyle(AVIATheme.textSecondary)
                                Spacer()
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AVIATheme.surfaceElevated)
                        .clipShape(.rect(cornerRadius: 14))

                        if !design.floorplanImageURL.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("FLOOR PLAN")
                                        .font(.neueCaption2Medium)
                                        .kerning(1.0)
                                        .foregroundStyle(AVIATheme.timelessBrown)
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 9, weight: .semibold))
                                        Text("View details")
                                            .font(.neueCaption2)
                                    }
                                    .foregroundStyle(AVIATheme.timelessBrown.opacity(0.7))
                                }

                                AVIATheme.timelessBrown
                                    .frame(height: 340)
                                    .overlay {
                                        AsyncImage(url: URL(string: design.floorplanImageURL)) { phase in
                                            if let image = phase.image {
                                                image.resizable().aspectRatio(contentMode: .fit)
                                            } else if phase.error != nil {
                                                Image(systemName: "rectangle.split.2x2")
                                                    .font(.system(size: 36))
                                                    .foregroundStyle(AVIATheme.aviaWhite.opacity(0.3))
                                            } else {
                                                ProgressView()
                                                    .tint(AVIATheme.aviaWhite.opacity(0.5))
                                            }
                                        }
                                        .allowsHitTesting(false)
                                    }
                                    .clipShape(.rect(cornerRadius: 14))
                            }
                        }

                        if !design.description.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ABOUT")
                                    .font(.neueCaption2Medium)
                                    .kerning(1.0)
                                    .foregroundStyle(AVIATheme.timelessBrown)
                                Text(design.description)
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textSecondary)
                                    .lineSpacing(4)
                                    .lineLimit(4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if !design.roomHighlights.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("ROOM HIGHLIGHTS")
                                    .font(.neueCaption2Medium)
                                    .kerning(1.0)
                                    .foregroundStyle(AVIATheme.timelessBrown)

                                VStack(spacing: 0) {
                                    ForEach(Array(design.roomHighlights.prefix(5).enumerated()), id: \.offset) { index, highlight in
                                        HStack(spacing: 10) {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(AVIATheme.timelessBrown)
                                                .frame(width: 16)
                                            Text(highlight)
                                                .font(.neueCaption)
                                                .foregroundStyle(AVIATheme.textPrimary)
                                            Spacer()
                                        }
                                        .padding(.vertical, 9)

                                        if index < min(design.roomHighlights.count, 5) - 1 {
                                            Rectangle()
                                                .fill(AVIATheme.surfaceBorder)
                                                .frame(height: 1)
                                                .padding(.leading, 26)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .buttonStyle(.pressable(.subtle))
    }

    // MARK: - Facade

    private var resolvedFacade: Facade? {
        guard let id = package.selectedFacadeId, !id.isEmpty else { return nil }
        return viewModel.findFacade(byId: id)
    }

    @ViewBuilder
    private var facadeSectionIfAvailable: some View {
        if resolvedFacade != nil {
            facadeSection
        }
    }

    private var facadeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INCLUDED FACADE")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.timelessBrown)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(AVIATheme.timelessBrown)
                        .frame(width: 3)
                }

            if let facade = resolvedFacade {

            NavigationLink(value: facade) {
            BentoCard(cornerRadius: 16) {
                VStack(spacing: 0) {
                    Color(AVIATheme.surfaceElevated)
                        .frame(height: 160)
                        .overlay {
                            AsyncImage(url: URL(string: facade.heroImageURL)) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                }
                            }
                            .allowsHitTesting(false)
                        }
                        .overlay(alignment: .topLeading) {
                            AVIAPill(facade.style, icon: nil, style: .onImage)
                                .padding(12)
                        }
                        .clipShape(.rect(cornerRadii: .init(topLeading: 16, topTrailing: 16)))

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(facade.name)
                                    .font(.neueCorpMedium(20))
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text(facade.style)
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                            Spacer()
                            AVIAPill(facade.pricing.isIncluded ? "Included" : facade.pricing.displayText, style: .onLight)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(facade.features.prefix(4), id: \.self) { feature in
                                Text(feature)
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textPrimary)
                            }
                        }
                    }
                    .padding(14)
                }
            }
            }
            .buttonStyle(.pressable(.subtle))

            NavigationLink(value: facade) {
                HStack(spacing: 8) {
                    Image(systemName: "building.2.fill")
                        .font(.neueCaptionMedium)
                    Text("View Full \(facade.name) Facade Details")
                        .font(.neueCaptionMedium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.neueCaption2)
                }
                .foregroundStyle(AVIATheme.timelessBrown)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AVIATheme.timelessBrown.opacity(0.06))
                .clipShape(.rect(cornerRadius: 12))
            }
            }
        }
    }

    // MARK: - Specification Range

    private var specificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SPECIFICATION RANGE")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.timelessBrown)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(AVIATheme.timelessBrown)
                        .frame(width: 3)
                }

            let tier = package.specTier

            NavigationLink(value: tier) {
            BentoCard(cornerRadius: 16) {
                VStack(spacing: 0) {
                    Color(AVIATheme.surfaceElevated)
                        .frame(height: 140)
                        .overlay {
                            if let uiImage = UIImage(named: tier.imageName) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .allowsHitTesting(false)
                            } else {
                                VStack(spacing: 8) {
                                    Text(tier.displayName)
                                        .font(.neueCaptionMedium)
                                        .foregroundStyle(AVIATheme.textTertiary)
                                }
                            }
                        }
                        .overlay(alignment: .topLeading) {
                            AVIAPill(tier.displayName, icon: nil, style: .onImage)
                                .padding(12)
                        }
                        .clipShape(.rect(cornerRadii: .init(topLeading: 16, topTrailing: 16)))

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tier.displayName)
                                    .font(.neueCorpMedium(20))
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text(tier.tagline)
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                            Spacer()
                            AVIAPill("Included", style: .onLight)
                        }

                        specHighlights(for: tier)
                    }
                    .padding(14)
                }
            }
            }
            .buttonStyle(.pressable(.subtle))

            NavigationLink(value: tier) {
                HStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.neueCaptionMedium)
                    Text("View Full \(tier.displayName) Spec Range Details")
                        .font(.neueCaptionMedium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.neueCaption2)
                }
                .foregroundStyle(AVIATheme.timelessBrown)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AVIATheme.timelessBrown.opacity(0.06))
                .clipShape(.rect(cornerRadius: 12))
            }

            Button {
                showSpecComparison = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Compare All Spec Ranges")
                        .font(.neueSubheadlineMedium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.neueCaptionMedium)
                }
                .foregroundStyle(AVIATheme.aviaWhite)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(AVIATheme.primaryGradient)
                .clipShape(.rect(cornerRadius: 14))
            }
        }
    }

    private func specHighlights(for tier: SpecTier) -> some View {
        let highlights: [String] = switch tier {
        case .volos:
            ["Laminate kitchen benchtops", "Vinyl plank flooring", "600mm oven & ceramic cooktop", "2,440mm ceiling height", "Chrome tapware & fixtures"]
        case .messina:
            ["20mm stone benchtops", "900mm oven & gas cooktop", "Hybrid vinyl plank flooring", "Two-tone soft-close cabinetry", "Semi-frameless shower screens"]
        case .portobello:
            ["Premium stone benchtops", "900mm pyrolytic oven & induction", "Premium hybrid flooring", "Matte black tapware & fixtures", "Frameless glass shower screens"]
        }

        return VStack(alignment: .leading, spacing: 5) {
            ForEach(highlights, id: \.self) { item in
                Text(item)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textPrimary)
            }
        }
    }



    // MARK: - Inclusions

    private var inclusionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PACKAGE INCLUSIONS")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.timelessBrown)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(AVIATheme.timelessBrown)
                        .frame(width: 3)
                }

            BentoCard(cornerRadius: 16) {
                VStack(spacing: 0) {
                    ForEach(Array(package.inclusions.enumerated()), id: \.offset) { index, inclusion in
                        HStack(spacing: 12) {
                            Text(inclusion)
                                .font(.neueSubheadline)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)

                        if index < package.inclusions.count - 1 {
                            Rectangle()
                                .fill(AVIATheme.surfaceBorder)
                                .frame(height: 1)
                                .padding(.leading, 16)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Estate Info

    private var estateSection: some View {
        Group {
            if let estate = package.matchedEstate {
                VStack(alignment: .leading, spacing: 12) {
                    Text("ESTATE")
                        .font(.neueCaption2Medium)
                        .kerning(1.0)
                        .foregroundStyle(AVIATheme.timelessBrown)
                        .padding(.leading, 12)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(AVIATheme.timelessBrown)
                                .frame(width: 3)
                        }

                    BentoCard(cornerRadius: 16) {
                        VStack(spacing: 0) {
                            Color(AVIATheme.surfaceElevated)
                                .frame(height: 120)
                                .overlay {
                                    AsyncImage(url: URL(string: estate.imageURL)) { phase in
                                        if let image = phase.image {
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        }
                                    }
                                    .allowsHitTesting(false)
                                }
                                .clipShape(.rect(cornerRadii: .init(topLeading: 16, topTrailing: 16)))

                            VStack(alignment: .leading, spacing: 6) {
                                Text(estate.name)
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)

                                Text(estate.description)
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textSecondary)
                                    .lineSpacing(3)
                                    .lineLimit(3)

                                if !estate.features.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(estate.features.prefix(4), id: \.self) { feature in
                                                Text(feature)
                                                    .font(.neueCaption2)
                                                    .foregroundStyle(AVIATheme.textSecondary)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 5)
                                                    .background(AVIATheme.surfaceElevated)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                    .contentMargins(.horizontal, 0)
                                }
                            }
                            .padding(14)
                        }
                    }

                    NavigationLink(value: estate) {
                        HStack(spacing: 8) {
                            Image(systemName: "map.fill")
                                .font(.neueCaptionMedium)
                            Text("View Full \(estate.name) Estate Details")
                                .font(.neueCaptionMedium)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.neueCaption2)
                        }
                        .foregroundStyle(AVIATheme.timelessBrown)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AVIATheme.timelessBrown.opacity(0.06))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                }
            }
        }
    }

    // MARK: - Build Timeline

    private var buildTimelineRow: some View {
        BentoCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "clock.fill")
                        .font(.neueCorp(12))
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text("Estimated Build Time")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textSecondary)
                    Spacer()
                    Text(package.buildTimeEstimate)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                }
            }
            .padding(16)
        }
    }

    // MARK: - CTA

    private var assignment: PackageAssignment? {
        viewModel.assignmentForPackage(package.id)
    }

    @ViewBuilder
    private var adminContractBanner: some View {
        if viewModel.currentRole.isAnyStaffRole,
           let assign = assignment,
           assign.contractStatus == "awaiting_contract"
            || assign.contractStatus == "awaiting_signature"
            || assign.contractStatus == "awaiting_confirmation" {
            let isUploadStep = contractRecord?.hasDocument != true
            let needsAdminTick = contractRecord?.isAdminConfirmed == false
            let title = isUploadStep
                ? "Upload Signed Contract"
                : (needsAdminTick ? "Admin Confirmation Needed" : "Awaiting Client Confirmation")
            let body = isUploadStep
                ? "Upload the PDF of the signed contract."
                : (needsAdminTick
                    ? "Tick ‘I confirm this is signed’ to complete your side."
                    : "Waiting for the client to tick their confirmation.")
            let buttonLabel = isUploadStep
                ? "Open Contract Upload"
                : (needsAdminTick ? "Review & Confirm Contract" : "View Contract Status")

            VStack(spacing: 10) {
                BentoCard(cornerRadius: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: isUploadStep ? "arrow.up.doc.fill" : "checkmark.seal")
                            .font(.system(size: 24))
                            .foregroundStyle(AVIATheme.warning)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title)
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Text(body)
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                }

                Button {
                    showContractSigning = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isUploadStep ? "arrow.up.doc.fill" : "checkmark.seal")
                            .font(.neueSubheadlineMedium)
                        Text(buttonLabel)
                            .font(.neueSubheadlineMedium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .background(AVIATheme.primaryGradient)
                    .clipShape(.rect(cornerRadius: 14))
                }
            }
        }
    }

    private var ctaSection: some View {
        VStack(spacing: 10) {
            buildTimelineRow

            if isClientWithAssignedPackage {
                clientResponseSection
            } else if canSharePackages {
                adminContractBanner
                staffActionsSection
            } else {
                if let phoneURL = URL(string: "tel:0756545123") {
                    Link(destination: phoneURL) {
                        HStack(spacing: 8) {
                            Image(systemName: "phone.fill")
                                .font(.neueSubheadlineMedium)
                            Text("Enquire About This Package")
                                .font(.neueSubheadlineMedium)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(.rect(cornerRadius: 14))
                    }
                }

                if let emailURL = URL(string: "mailto:sales@aviahomes.com.au?subject=Package Enquiry: \(package.title)") {
                    Link(destination: emailURL) {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                                .font(.neueSubheadlineMedium)
                            Text("Email Sales Team")
                                .font(.neueSubheadlineMedium)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(AVIATheme.timelessBrown)
                        .background(AVIATheme.timelessBrown.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 14))
                    }
                }
            }
        }
    }

    // MARK: - Staff / Partner Actions

    private var staffActionsSection: some View {
        VStack(spacing: 12) {
            if let assignment, (!assignment.assignedPartnerIds.isEmpty || !assignment.sharedWithClientIds.isEmpty) {
                assignmentSummaryCard
            }

            Button {
                showPackageSharing = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(viewModel.currentRole == .partner ? "Share with Clients" : "Assign & Share Package")
                        .font(.neueSubheadlineMedium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.neueCaptionMedium)
                }
                .foregroundStyle(AVIATheme.aviaWhite)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(AVIATheme.primaryGradient)
                .clipShape(.rect(cornerRadius: 14))
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: showPackageSharing)

            ShareLink(
                item: URL(string: "https://apps.apple.com/app/avia-homes/id0000000000")!,
                subject: Text("AVIA Homes — \(package.title)"),
                message: Text("Check out this AVIA package: \(package.title) — \(package.price). Download the AVIA Homes app to view the full package details: https://apps.apple.com/app/avia-homes/id0000000000")
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.neueSubheadlineMedium)
                    Text("Share Package Link")
                        .font(.neueSubheadlineMedium)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundStyle(AVIATheme.timelessBrown)
                .background(AVIATheme.timelessBrown.opacity(0.1))
                .clipShape(.rect(cornerRadius: 14))
            }
        }
    }

    private var assignmentSummaryCard: some View {
        BentoCard(cornerRadius: 16) {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .font(.neueCorp(14))
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text("ASSIGNMENT STATUS")
                        .font(.neueCaption2Medium)
                        .kerning(1.0)
                        .foregroundStyle(AVIATheme.textTertiary)
                    Spacer()
                    if assignment?.isExclusive == true {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8))
                            Text("Exclusive")
                                .font(.neueCorpMedium(9))
                                .kerning(0.3)
                        }
                        .foregroundStyle(AVIATheme.warning)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AVIATheme.warning.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

                Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                HStack(spacing: 0) {
                    let partnerCount = assignment?.assignedPartnerIds.count ?? 0
                    let clientCount = assignment?.sharedWithClientIds.count ?? 0
                    let responses = assignment?.clientResponses ?? []
                    let acceptedCount = responses.filter { $0.status == .accepted }.count
                    let pendingCount = responses.filter { $0.status == .pending }.count

                    VStack(spacing: 4) {
                        Text("\(partnerCount)")
                            .font(.neueCorpMedium(20))
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("Partners")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)

                    Rectangle().fill(AVIATheme.surfaceBorder).frame(width: 1, height: 36)

                    VStack(spacing: 4) {
                        Text("\(clientCount)")
                            .font(.neueCorpMedium(20))
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("Shared")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)

                    Rectangle().fill(AVIATheme.surfaceBorder).frame(width: 1, height: 36)

                    VStack(spacing: 4) {
                        Text("\(acceptedCount)")
                            .font(.neueCorpMedium(20))
                            .foregroundStyle(AVIATheme.success)
                        Text("Accepted")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)

                    Rectangle().fill(AVIATheme.surfaceBorder).frame(width: 1, height: 36)

                    VStack(spacing: 4) {
                        Text("\(pendingCount)")
                            .font(.neueCorpMedium(20))
                            .foregroundStyle(pendingCount > 0 ? AVIATheme.warning : AVIATheme.textTertiary)
                        Text("Pending")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 14)
            }
        }
    }

    private var clientResponseSection: some View {
        VStack(spacing: 10) {
            if let assign = assignment {
                // Show EOI/contract status banners
                if assign.contractStatus == "awaiting_contract"
                    || assign.contractStatus == "awaiting_signature"
                    || assign.contractStatus == "awaiting_confirmation" {
                    let isUploadStep = contractRecord?.hasDocument != true
                    let bannerTitle = isUploadStep ? "Signed Contract Needs Uploading" : "Confirm Signed Contract"
                    let bannerBody = isUploadStep
                        ? "Upload a PDF of the signed contract after the in-person signing."
                        : "Both parties need to tick ‘I confirm this is signed’."
                    let buttonLabel = isUploadStep ? "Open Contract Upload" : "Review & Confirm Contract"
                    BentoCard(cornerRadius: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: isUploadStep ? "arrow.up.doc.fill" : "checkmark.seal")
                                .font(.system(size: 24))
                                .foregroundStyle(AVIATheme.warning)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(bannerTitle)
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text(bannerBody)
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(16)
                    }

                    Button {
                        showContractSigning = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isUploadStep ? "arrow.up.doc.fill" : "checkmark.seal")
                                .font(.neueSubheadlineMedium)
                            Text(buttonLabel)
                                .font(.neueSubheadlineMedium)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(.rect(cornerRadius: 14))
                    }
                } else if assign.contractStatus == "signed" {
                    BentoCard(cornerRadius: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(AVIATheme.success)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Contract Signed")
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text("Your contract has been signed successfully")
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(16)
                    }
                } else if assign.eoiStatus == "submitted" || assign.eoiStatus == "resubmitted" {
                    BentoCard(cornerRadius: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(AVIATheme.warning)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("EOI Submitted")
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text("Your expression of interest is under review")
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(16)
                    }
                } else if assign.eoiStatus == "approved" {
                    BentoCard(cornerRadius: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(AVIATheme.success)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("EOI Approved")
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text("Awaiting contract preparation")
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(16)
                    }
                } else if assign.eoiStatus == "changes_requested" {
                    BentoCard(cornerRadius: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.bubble.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(AVIATheme.destructive)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Changes Requested")
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text("Please review admin notes and resubmit")
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(16)
                    }

                    Button {
                        showEOIForm = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.neueSubheadlineMedium)
                            Text("Resubmit EOI")
                                .font(.neueSubheadlineMedium)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(.rect(cornerRadius: 14))
                    }
                } else if currentResponse?.status == .accepted {
                    BentoCard(cornerRadius: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(AVIATheme.success)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Package Approved")
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                if let date = currentResponse?.respondedDate {
                                    Text("Approved on \(date.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.neueCaption)
                                        .foregroundStyle(AVIATheme.textSecondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(16)
                    }
                } else if currentResponse?.status == .declined {
                    BentoCard(cornerRadius: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(AVIATheme.destructive)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Package Declined")
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text("You can change your response below")
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(16)
                    }
                }
            }

            // Show Accept/EOI button if not already accepted and no active EOI
            if currentResponse?.status != .accepted && (assignment?.eoiStatus == "none" || assignment?.eoiStatus == nil) {
                Button {
                    showEOIForm = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.neueSubheadlineMedium)
                        Text("Accept & Submit EOI")
                            .font(.neueSubheadlineMedium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .background(AVIATheme.primaryGradient)
                    .clipShape(.rect(cornerRadius: 14))
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: showEOIForm)
            }

            if currentResponse?.status != .declined && (assignment?.eoiStatus == "none" || assignment?.eoiStatus == nil) {
                Button {
                    showDeclineConfirmation = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle")
                            .font(.neueSubheadlineMedium)
                        Text("Decline Package")
                            .font(.neueSubheadlineMedium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(AVIATheme.destructive)
                    .background(AVIATheme.destructive.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 14))
                }
                .confirmationDialog(
                    "Decline this house & land package?",
                    isPresented: $showDeclineConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Decline Package", role: .destructive) {
                        print("[PackageDetailView] Declining package \(package.id)")
                        viewModel.respondToPackage(packageId: package.id, status: .declined)
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("You can change your response later.")
                }
            }
        }
    }

    // MARK: - Helpers

    private func statusBadge(_ status: PackageStatus) -> some View {
        let color = statusColor(status)
        return Text(status.rawValue.uppercased())
            .font(.neueCorpMedium(9))
            .kerning(0.5)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .overlay(Capsule().stroke(color, lineWidth: 1))
    }

    private func statusColor(_ status: PackageStatus) -> Color {
        switch status {
        case .available: AVIATheme.success
        case .underOffer: AVIATheme.warning
        case .sold: AVIATheme.destructive
        }
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.neueSubheadline)
                .foregroundStyle(AVIATheme.textSecondary)
            Spacer()
            Text(value)
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var detailDivider: some View {
        Rectangle()
            .fill(AVIATheme.surfaceBorder)
            .frame(height: 1)
            .padding(.leading, 16)
    }

    private func houseStatPill(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.neueCorpMedium(18))
                .foregroundStyle(AVIATheme.textPrimary)
            Text(label)
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var houseStatDivider: some View {
        Rectangle()
            .fill(AVIATheme.surfaceBorder)
            .frame(width: 1, height: 40)
    }

    private func dimensionStat(icon: String, value: String, unit: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AVIATheme.timelessBrown)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.neueCorpMedium(20))
                    .foregroundStyle(AVIATheme.textPrimary)
                Text(unit)
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.textSecondary)
            }
            Text(label)
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AVIATheme.background.opacity(0.5))
        .clipShape(.rect(cornerRadius: 10))
    }

    private func dimensionTag(icon: String, value: String) -> some View {
        Text(value)
            .font(.neueCaption2)
            .foregroundStyle(AVIATheme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(AVIATheme.timelessBrown.opacity(0.06))
            .clipShape(Capsule())
    }
}
