import SwiftUI

struct PackageDetailView: View {
    let package: HouseLandPackage
    @Environment(AppViewModel.self) private var viewModel
    @State private var showPackageSharing = false
    @State private var showSpecComparison = false
    @State private var showResponseConfirmation = false
    @State private var responseNotes = ""
    @State private var pendingAction: PackageResponseStatus?
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
                    ShareLink(item: "Check out this AVIA package: \(package.title) — \(package.price)") {
                        Image(systemName: "square.and.arrow.up")
                            .font(.neueSubheadline)
                    }
                }
            }
        }
        .alert("Confirm Response", isPresented: $showResponseConfirmation) {
            TextField("Notes (optional)", text: $responseNotes)
            Button("Cancel", role: .cancel) { }
            Button("Decline", role: .destructive) {
                if let action = pendingAction {
                    viewModel.respondToPackage(packageId: package.id, status: action, notes: responseNotes.isEmpty ? nil : responseNotes)
                }
            }
        } message: {
            Text("Decline this house & land package?")
        }
        .sheet(isPresented: $showEOIForm) {
            if let assign = assignment {
                EOIFormView(package: package, assignment: assign)
            }
        }
        .sheet(isPresented: $showContractSigning) {
            if let contract = contractRecord, let assign = assignment {
                ContractSigningView(contract: contract, assignment: assign, package: package)
            }
        }
        .task {
            if let assign = assignment, assign.contractStatus == "awaiting_signature" {
                contractRecord = await SupabaseService.shared.fetchContractSignature(forAssignment: assign.id)
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
        GeometryReader { geo in
            Color(AVIATheme.surfaceElevated)
                .overlay {
                    AsyncImage(url: URL(string: package.imageURL)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else if phase.error != nil {
                            Image(systemName: "house.and.flag.fill")
                                .font(.neueCorpMedium(56))
                                .foregroundStyle(AVIATheme.teal.opacity(0.2))
                        } else {
                            ProgressView()
                        }
                    }
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(package.title)
                            .font(.neueCorpMedium(26))
                            .foregroundStyle(.white)
                        HStack(spacing: 12) {
                            Text(package.price)
                                .font(.neueCorpMedium(18))
                                .foregroundStyle(.white.opacity(0.95))
                            Text(package.location)
                                .font(.neueCaption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial)
                }
                .clipped()
        }
        .frame(height: 380)
    }

    // MARK: - Content

    private var contentSection: some View {
        VStack(spacing: 28) {
            titleBlock
            priceBreakdown
            landDetailsSection
            houseDesignSection
            facadeSection
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
                Text("NEW LISTING")
                    .font(.neueCorpMedium(9))
                    .kerning(0.8)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AVIATheme.timelessBrown)
                    .clipShape(Capsule())
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
                            .foregroundStyle(AVIATheme.teal)
                        Spacer()
                        Text("TURNKEY")
                            .font(.neueCorpMedium(9))
                            .kerning(0.8)
                            .foregroundStyle(AVIATheme.teal)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AVIATheme.teal.opacity(0.08))
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

            if let design = package.matchedDesign {
                BentoCard(cornerRadius: 16) {
                    VStack(spacing: 0) {
                        Color(AVIATheme.surfaceElevated)
                            .frame(height: 180)
                            .overlay {
                                AsyncImage(url: URL(string: design.imageURL)) { phase in
                                    if let image = phase.image {
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    }
                                }
                                .allowsHitTesting(false)
                            }
                            .clipShape(.rect(cornerRadii: .init(topLeading: 16, topTrailing: 16)))

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(design.name)
                                    .font(.neueCorpMedium(22))
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Spacer()
                                if design.storeys == 2 {
                                    Text("DOUBLE STOREY")
                                        .font(.neueCorpMedium(8))
                                        .kerning(0.5)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(AVIATheme.teal)
                                        .clipShape(Capsule())
                                }
                            }

                            Text(String(format: "%.0f m² of living space", design.squareMeters))
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)

                            HStack(spacing: 0) {
                                houseStatPill(value: "\(design.bedrooms)", label: "Bed", icon: "bed.double.fill")
                                houseStatDivider
                                houseStatPill(value: "\(design.bathrooms)", label: "Bath", icon: "shower.fill")
                                houseStatDivider
                                houseStatPill(value: "\(design.garages)", label: "Car", icon: "car.fill")
                                houseStatDivider
                                houseStatPill(value: "\(design.livingAreas)", label: "Living", icon: "sofa.fill")
                            }
                            .padding(.vertical, 12)
                            .background(AVIATheme.surfaceElevated)
                            .clipShape(.rect(cornerRadius: 12))

                            HStack(spacing: 10) {
                                dimensionTag(icon: "arrow.left.and.right", value: String(format: "%.1fm wide", design.houseWidth))
                                dimensionTag(icon: "arrow.up.and.down", value: String(format: "%.1fm long", design.houseLength))
                                dimensionTag(icon: "ruler", value: String(format: "%.1fm min lot", design.lotWidth))
                            }

                            if !design.roomHighlights.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Room Highlights")
                                        .font(.neueCaptionMedium)
                                        .foregroundStyle(AVIATheme.textPrimary)
                                        .padding(.top, 4)

                                    ForEach(design.roomHighlights.prefix(5), id: \.self) { highlight in
                                        Text(highlight)
                                            .font(.neueCaption2)
                                            .foregroundStyle(AVIATheme.textSecondary)
                                    }
                                }
                            }
                        }
                        .padding(14)
                    }
                }

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
                    .foregroundStyle(AVIATheme.teal)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AVIATheme.teal.opacity(0.06))
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

    // MARK: - Facade

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

            if let facade = package.matchedFacade {

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
                            Text(facade.style.uppercased())
                                .font(.neueCorpMedium(11))
                                .kerning(0.8)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(.black.opacity(0.55))
                                .clipShape(Capsule())
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
                            Text(facade.pricing.isIncluded ? "INCLUDED" : facade.pricing.displayText.uppercased())
                                .font(.neueCorpMedium(9))
                                .kerning(0.8)
                                .foregroundStyle(AVIATheme.timelessBrown)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(AVIATheme.timelessBrown.opacity(0.08))
                                .clipShape(Capsule())
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
                .foregroundStyle(AVIATheme.teal)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AVIATheme.teal.opacity(0.06))
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
                            HStack(spacing: 6) {
                                Text(tier.displayName.uppercased())
                                    .font(.neueCorpMedium(11))
                                    .kerning(0.8)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.black.opacity(0.55))
                            .clipShape(Capsule())
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
                            Text("INCLUDED")
                                .font(.neueCorpMedium(9))
                                .kerning(0.8)
                                .foregroundStyle(AVIATheme.success)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(AVIATheme.success.opacity(0.08))
                                .clipShape(Capsule())
                        }

                        specHighlights(for: tier)
                    }
                    .padding(14)
                }
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
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(AVIATheme.tealGradient)
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
                        .foregroundStyle(AVIATheme.teal)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AVIATheme.teal.opacity(0.06))
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
                        .foregroundStyle(AVIATheme.teal)
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

    private var ctaSection: some View {
        VStack(spacing: 10) {
            buildTimelineRow

            if isClientWithAssignedPackage {
                clientResponseSection
            } else if canSharePackages {
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
                        .foregroundStyle(.white)
                        .background(AVIATheme.tealGradient)
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
                        .foregroundStyle(AVIATheme.teal)
                        .background(AVIATheme.teal.opacity(0.1))
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
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(AVIATheme.tealGradient)
                .clipShape(.rect(cornerRadius: 14))
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: showPackageSharing)

            ShareLink(item: "Check out this AVIA package: \(package.title) — \(package.price)") {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.neueSubheadlineMedium)
                    Text("Share Package Link")
                        .font(.neueSubheadlineMedium)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundStyle(AVIATheme.teal)
                .background(AVIATheme.teal.opacity(0.1))
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
                        .foregroundStyle(AVIATheme.teal)
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
                if assign.contractStatus == "awaiting_signature" {
                    BentoCard(cornerRadius: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "signature")
                                .font(.system(size: 24))
                                .foregroundStyle(AVIATheme.warning)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Contract Ready to Sign")
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text("Your contract is ready for signature")
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
                            Image(systemName: "signature")
                                .font(.neueSubheadlineMedium)
                            Text("Sign Contract")
                                .font(.neueSubheadlineMedium)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(.white)
                        .background(AVIATheme.tealGradient)
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
                        .foregroundStyle(.white)
                        .background(AVIATheme.tealGradient)
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
                    .foregroundStyle(.white)
                    .background(AVIATheme.tealGradient)
                    .clipShape(.rect(cornerRadius: 14))
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: showEOIForm)
            }

            if currentResponse?.status != .declined && assignment?.eoiStatus == "none" {
                Button {
                    pendingAction = .declined
                    showResponseConfirmation = true
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
            }
        }
    }

    // MARK: - Helpers

    private func statusBadge(_ status: PackageStatus) -> some View {
        Text(status.rawValue.uppercased())
            .font(.neueCorpMedium(9))
            .kerning(0.5)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor(status))
            .clipShape(Capsule())
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
