import SwiftUI
import QuickLook

struct EstateDetailView: View {
    let estate: LandEstate

    @Environment(AppViewModel.self) private var viewModel
    @State private var showSiteMapViewer: Bool = false
    @State private var showBrochurePreview: Bool = false

    private var estatePackages: [HouseLandPackage] {
        let allEstatePackages = viewModel.allPackages.filter { $0.estate == estate.name }
        switch viewModel.currentRole {
        case .client:
            let sharedPackageIds = viewModel.clientSharedPackages.map(\.id)
            return allEstatePackages.filter { sharedPackageIds.contains($0.id) }
        case .partner, .salesPartner:
            let assignedPackageIds = viewModel.packagesForCurrentUser().map(\.id)
            return allEstatePackages.filter { assignedPackageIds.contains($0.id) }
        default:
            return allEstatePackages
        }
    }

    private var availablePackageCount: Int {
        estatePackages.filter { $0.status == .available }.count
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
                Text(estate.name)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: "Check out \(estate.name) estate — \(estate.location)") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.neueSubheadline)
                }
            }
        }
        .fullScreenCover(isPresented: $showSiteMapViewer) {
            if let siteMapAsset = estate.siteMapAssetName {
                SiteMapViewer(estateName: estate.name, assetName: siteMapAsset)
            } else if let siteMapURL = estate.siteMapURL {
                SiteMapViewer(estateName: estate.name, imageURL: siteMapURL)
            }
        }
        .sheet(isPresented: $showBrochurePreview) {
            if let brochureURL = estate.brochureURL, let url = URL(string: brochureURL) {
                BrochureWebPreviewSheet(url: url, estateName: estate.name)
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        GeometryReader { geo in
            Color(AVIATheme.surfaceElevated)
                .overlay {
                    AsyncImage(url: URL(string: estate.imageURL)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else if phase.error != nil {
                            Image(systemName: "map.fill")
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
                            .init(color: AVIATheme.background.opacity(0), location: 0.0),
                            .init(color: AVIATheme.background.opacity(0.6), location: 0.4),
                            .init(color: AVIATheme.background, location: 0.75),
                            .init(color: AVIATheme.background, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geo.size.height * 0.55)
                }
                .overlay(alignment: .bottomLeading) {
                    if let assetName = estate.logoAssetName, let uiImage = UIImage(named: assetName) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 48)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(.rect(cornerRadius: 10))
                            .padding(.leading, 20)
                            .padding(.bottom, 20)
                    } else if let logoURL = estate.logoURL, let url = URL(string: logoURL) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 48)
                                    .padding(10)
                                    .background(.ultraThinMaterial)
                                    .clipShape(.rect(cornerRadius: 10))
                            }
                        }
                        .padding(.leading, 20)
                        .padding(.bottom, 20)
                    }
                }
                .clipped()
        }
        .frame(height: 380)
    }

    // MARK: - Content

    private var contentSection: some View {
        VStack(spacing: 28) {
            titleBlock
            statsGrid
            if estate.logoURL != nil || estate.logoAssetName != nil || estate.brochureURL != nil {
                estateMediaSection
            }
            if estate.siteMapURL != nil || estate.siteMapAssetName != nil {
                siteMapSection
            }
            aboutSection
            featuresSection
            availabilitySection
            if !estatePackages.isEmpty {
                packagesSection
            }
            ctaSection
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 48)
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(estate.name)
                .font(.neueCorpMedium(28))
                .foregroundStyle(AVIATheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(AVIATheme.timelessBrown)
                Text(estate.location)
                    .foregroundStyle(AVIATheme.textSecondary)
            }
            .font(.neueCaption)

            if estate.status == .upcoming {
                Text("COMING SOON")
                    .font(.neueCorpMedium(9))
                    .kerning(0.8)
                    .foregroundStyle(AVIATheme.warning)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .overlay(Capsule().stroke(AVIATheme.warning, lineWidth: 1))
            }
        }
    }

    private var estateStatusBadge: some View {
        Text(estate.status.rawValue.uppercased())
            .font(.neueCorpMedium(9))
            .kerning(0.5)
            .foregroundStyle(estateStatusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .overlay(Capsule().stroke(estateStatusColor, lineWidth: 1))
    }

    private var estateStatusColor: Color {
        switch estate.status {
        case .current: AVIATheme.success
        case .upcoming: AVIATheme.warning
        case .completed: AVIATheme.textTertiary
        }
    }

    // MARK: - Estate Media (Logo & Brochure) — Display Only

    private var estateMediaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ESTATE MEDIA")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)

            BentoCard(cornerRadius: 16) {
                VStack(spacing: 0) {
                    if let assetName = estate.logoAssetName, let uiImage = UIImage(named: assetName) {
                        HStack(spacing: 14) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 56, height: 56)
                                .clipShape(.rect(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Estate Logo")
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text("\(estate.name) branding")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                            }

                            Spacer()
                        }
                        .padding(16)
                    } else if let logoURL = estate.logoURL, let url = URL(string: logoURL) {
                        HStack(spacing: 14) {
                            Color(AVIATheme.surfaceElevated)
                                .frame(width: 56, height: 56)
                                .overlay {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image.resizable().aspectRatio(contentMode: .fit)
                                        }
                                    }
                                    .allowsHitTesting(false)
                                }
                                .clipShape(.rect(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Estate Logo")
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text("\(estate.name) branding")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                            }

                            Spacer()
                        }
                        .padding(16)
                    }

                    if (estate.logoURL != nil || estate.logoAssetName != nil) && estate.brochureURL != nil {
                        Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 86)
                    }

                    if estate.brochureURL != nil {
                        Button {
                            showBrochurePreview = true
                        } label: {
                            HStack(spacing: 14) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(AVIATheme.timelessBrown.opacity(0.1))
                                    .frame(width: 56, height: 56)
                                    .overlay {
                                        Image(systemName: "doc.richtext.fill")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundStyle(AVIATheme.timelessBrown)
                                    }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("PDF Brochure")
                                        .font(.neueSubheadlineMedium)
                                        .foregroundStyle(AVIATheme.textPrimary)
                                    Text("View the \(estate.name) estate brochure")
                                        .font(.neueCaption2)
                                        .foregroundStyle(AVIATheme.textTertiary)
                                }

                                Spacer()

                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AVIATheme.timelessBrown)
                            }
                            .padding(16)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Site Map — Display Only

    private var siteMapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SITE MAP")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)

            if estate.siteMapAssetName != nil || estate.siteMapURL != nil {
                Button {
                    showSiteMapViewer = true
                } label: {
                    BentoCard(cornerRadius: 16) {
                        VStack(spacing: 0) {
                            Color(AVIATheme.surfaceElevated)
                                .frame(height: 220)
                                .overlay {
                                    if let assetName = estate.siteMapAssetName, let uiImage = UIImage(named: assetName) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } else if let siteMapURL = estate.siteMapURL, let url = URL(string: siteMapURL) {
                                        AsyncImage(url: url) { phase in
                                            if let image = phase.image {
                                                image.resizable().aspectRatio(contentMode: .fill)
                                            } else if phase.error != nil {
                                                Image(systemName: "map.fill")
                                                    .font(.system(size: 32))
                                                    .foregroundStyle(AVIATheme.textTertiary.opacity(0.3))
                                            } else {
                                                ProgressView()
                                            }
                                        }
                                    }
                                }
                                .allowsHitTesting(false)
                                .clipShape(.rect(cornerRadius: 16, style: .continuous))

                            HStack(spacing: 10) {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AVIATheme.timelessBrown)
                                    .frame(width: 28, height: 28)
                                    .background(AVIATheme.timelessBrown.opacity(0.08))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(estate.name) Site Map")
                                        .font(.neueCaptionMedium)
                                        .foregroundStyle(AVIATheme.textPrimary)
                                    Text("Tap to view full screen \u{00B7} Pinch to zoom")
                                        .font(.neueCaption2)
                                        .foregroundStyle(AVIATheme.textTertiary)
                                }

                                Spacer()

                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AVIATheme.timelessBrown)
                            }
                            .padding(14)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 10) {
            statCard(value: "\(estate.totalLots)", label: "Total Lots", icon: "square.grid.3x3.fill")
            statCard(value: "\(estate.availableLots)", label: "Available", icon: "checkmark.circle.fill")
            statCard(value: estate.priceFrom, label: "Land From", icon: "tag.fill")
        }
    }

    private func statCard(value: String, label: String, icon: String) -> some View {
        BentoCard(cornerRadius: 14) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.neueCorp(14))
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .frame(width: 30, height: 30)
                    .background(AVIATheme.timelessBrown.opacity(0.1))
                    .clipShape(Circle())

                Text(value)
                    .font(.neueCorpMedium(16))
                    .foregroundStyle(AVIATheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(label)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ABOUT THE ESTATE")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)

            BentoCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(estate.description)
                        .font(.neueSubheadline)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .lineSpacing(4)

                    Rectangle()
                        .fill(AVIATheme.surfaceBorder)
                        .frame(height: 1)

                    HStack(spacing: 12) {
                        detailPill(icon: "mappin", text: estate.suburb)
                        detailPill(icon: "calendar", text: estate.expectedCompletion)
                    }
                }
                .padding(16)
            }
        }
    }

    private func detailPill(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(AVIATheme.timelessBrown)
            Text(text)
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AVIATheme.timelessBrown.opacity(0.06))
        .clipShape(Capsule())
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ESTATE FEATURES")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)

            BentoCard(cornerRadius: 16) {
                VStack(spacing: 0) {
                    ForEach(Array(estate.features.enumerated()), id: \.offset) { index, feature in
                        HStack(spacing: 12) {
                            Image(systemName: featureIcon(for: feature))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AVIATheme.timelessBrown)
                                .frame(width: 28, height: 28)
                                .background(AVIATheme.timelessBrown.opacity(0.08))
                                .clipShape(Circle())
                            Text(feature)
                                .font(.neueSubheadline)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)

                        if index < estate.features.count - 1 {
                            Rectangle()
                                .fill(AVIATheme.surfaceBorder)
                                .frame(height: 1)
                                .padding(.leading, 56)
                        }
                    }
                }
            }
        }
    }

    private func featureIcon(for feature: String) -> String {
        let lower = feature.lowercased()
        if lower.contains("park") || lower.contains("playground") || lower.contains("recreation") { return "leaf.fill" }
        if lower.contains("school") { return "graduationcap.fill" }
        if lower.contains("shop") || lower.contains("café") || lower.contains("town centre") { return "cart.fill" }
        if lower.contains("walk") || lower.contains("trail") || lower.contains("cycling") { return "figure.walk" }
        if lower.contains("community") || lower.contains("established") { return "person.3.fill" }
        if lower.contains("transport") || lower.contains("train") || lower.contains("highway") { return "bus.fill" }
        if lower.contains("beach") || lower.contains("lake") { return "water.waves" }
        if lower.contains("sport") { return "sportscourt.fill" }
        if lower.contains("landscap") || lower.contains("streetscape") { return "tree.fill" }
        if lower.contains("lot") || lower.contains("new release") || lower.contains("variety") { return "square.grid.2x2.fill" }
        if lower.contains("affordable") { return "tag.fill" }
        if lower.contains("central") || lower.contains("location") { return "location.fill" }
        if lower.contains("complete") || lower.contains("operational") || lower.contains("fully") { return "checkmark.seal.fill" }
        if lower.contains("future") || lower.contains("planned") { return "hammer.fill" }
        if lower.contains("boutique") { return "sparkles" }
        return "star.fill"
    }

    // MARK: - Availability

    private var availabilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AVAILABILITY")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)

            BentoCard(cornerRadius: 16) {
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(estate.availableLots > 0 ? "\(estate.availableLots) lots available" : "Sold Out")
                                .font(.neueCorpMedium(20))
                                .foregroundStyle(AVIATheme.textPrimary)
                            Text("of \(estate.totalLots) total lots")
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)
                        }
                        Spacer()
                        if estate.availableLots > 0 {
                            Text(estate.priceFrom)
                                .font(.neueCorpMedium(20))
                                .foregroundStyle(AVIATheme.timelessBrown)
                        }
                    }
                    .padding(16)

                    if estate.totalLots > 0 {
                        Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                        VStack(spacing: 8) {
                            let progress = Double(estate.totalLots - estate.availableLots) / Double(estate.totalLots)
                            HStack {
                                Text("\(Int(progress * 100))% sold")
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.textSecondary)
                                Spacer()
                                Text(estate.expectedCompletion)
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(AVIATheme.surfaceElevated)
                                        .frame(height: 8)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(AVIATheme.timelessBrown)
                                        .frame(width: geo.size.width * progress, height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                        .padding(16)
                    }
                }
            }
        }
    }

    // MARK: - Packages

    private var packagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(viewModel.currentRole == .client ? "YOUR PACKAGES" : "AVAILABLE PACKAGES")
                    .font(.neueCaption2Medium)
                    .kerning(1.0)
                    .foregroundStyle(AVIATheme.textTertiary)
                Spacer()
                if availablePackageCount > 0 {
                    Text("\(availablePackageCount) available")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }

            ForEach(estatePackages) { pkg in
                NavigationLink(value: pkg) {
                    packageRow(package: pkg)
                }
            }
        }
    }

    private func packageRow(package: HouseLandPackage) -> some View {
        BentoCard(cornerRadius: 16) {
            HStack(spacing: 14) {
                Color(AVIATheme.surfaceElevated)
                    .frame(width: 80, height: 80)
                    .overlay {
                        AsyncImage(url: URL(string: package.imageURL)) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(package.title)
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        packageStatusBadge(package.status)
                    }

                    HStack(spacing: 10) {
                        Label("\(package.bedrooms)", systemImage: "bed.double.fill")
                        Label("\(package.bathrooms)", systemImage: "shower.fill")
                        Label(package.lotSize, systemImage: "ruler")
                    }
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)

                    HStack {
                        Text(package.price)
                            .font(.neueCorpMedium(16))
                            .foregroundStyle(AVIATheme.timelessBrown)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                }
            }
            .padding(12)
        }
    }

    private func packageStatusBadge(_ status: PackageStatus) -> some View {
        let color = packageStatusColor(status)
        return Text(status.rawValue)
            .font(.neueCorpMedium(8))
            .kerning(0.4)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(Capsule().stroke(color, lineWidth: 1))
    }

    private func packageStatusColor(_ status: PackageStatus) -> Color {
        switch status {
        case .available: AVIATheme.success
        case .underOffer: AVIATheme.warning
        case .sold: AVIATheme.destructive
        }
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: 10) {
            if let phoneURL = URL(string: "tel:0756545123") {
                Link(destination: phoneURL) {
                    HStack(spacing: 8) {
                        Image(systemName: "phone.fill")
                            .font(.neueSubheadlineMedium)
                        Text("Enquire About \(estate.name)")
                            .font(.neueSubheadlineMedium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .background(AVIATheme.primaryGradient)
                    .clipShape(.rect(cornerRadius: 14))
                }
            }

            if let emailURL = URL(string: "mailto:sales@aviahomes.com.au?subject=Estate Enquiry: \(estate.name)") {
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

// MARK: - Brochure Web Preview

struct BrochureWebPreviewSheet: View {
    let url: URL
    let estateName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            BrochureWebView(url: url)
                .navigationTitle("\(estateName) Brochure")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .fontWeight(.semibold)
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}

struct BrochureWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

import WebKit
