import SwiftUI

struct HomeDesignDetailView: View {
    let design: HomeDesign
    @State private var showingFloorplan: Bool = false
    @State private var showingEnquiryForm: Bool = false

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
                Text(design.name)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let url = URL(string: "https://www.aviahomes.com.au/homes/\(design.slug)") {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.neueSubheadline)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingFloorplan) {
            FloorplanFullscreenView(design: design)
        }
    }

    private var heroSection: some View {
        GeometryReader { geo in
            Color(AVIATheme.surfaceElevated)
                .overlay {
                    AsyncImage(url: URL(string: design.imageURL)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else if phase.error != nil {
                            VStack(spacing: 12) {
                                Image(systemName: "house.fill")
                                    .font(.neueCorpMedium(56))
                                    .foregroundStyle(AVIATheme.teal.opacity(0.2))
                                Text(design.name)
                                    .font(.neueCorpMedium(24))
                                    .foregroundStyle(AVIATheme.teal.opacity(0.15))
                            }
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
                .clipped()
        }
        .frame(height: 440)
    }

    private var contentSection: some View {
        VStack(spacing: 32) {
            titleBlock
            descriptionBlock
            quickStats
            dimensionsBar
            if !design.floorplanImageURL.isEmpty {
                floorplanSection
            }
            roomHighlightsSection
            specificationGrid
            if !design.inclusions.isEmpty {
                inclusionsSection
            }
            featuresGrid
            ctaSection
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 48)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(design.name)
                    .font(.neueCorpMedium(32))
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
                if design.storeys == 2 {
                    Text("DOUBLE STOREY")
                        .font(.neueCorpMedium(9))
                        .kerning(0.8)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AVIATheme.teal)
                        .clipShape(Capsule())
                } else {
                    Text("SINGLE STOREY")
                        .font(.neueCorpMedium(9))
                        .kerning(0.8)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AVIATheme.surfaceElevated)
                        .clipShape(Capsule())
                }
            }

            Text(String(format: "%.0f m² of thoughtfully designed living", design.squareMeters))
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
        }
    }

    private var quickStats: some View {
        HStack(spacing: 0) {
            statPill(value: "\(design.bedrooms)", label: "Bed", icon: "bed.double.fill")
            statDivider
            statPill(value: "\(design.bathrooms)", label: "Bath", icon: "shower.fill")
            statDivider
            statPill(value: "\(design.garages)", label: "Car", icon: "car.fill")
            statDivider
            statPill(value: "\(design.livingAreas)", label: "Living", icon: "sofa.fill")
        }
        .padding(.vertical, 16)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }

    private func statPill(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.neueCorpMedium(14))
                .foregroundStyle(AVIATheme.teal)
            Text(value)
                .font(.neueCorpMedium(22))
                .foregroundStyle(AVIATheme.textPrimary)
            Text(label)
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(AVIATheme.surfaceBorder)
            .frame(width: 1, height: 50)
    }

    private var dimensionsBar: some View {
        HStack(spacing: 12) {
            dimensionChip(icon: "arrow.left.and.right", label: "Width", value: String(format: "%.1fm", design.houseWidth))
            dimensionChip(icon: "arrow.up.and.down", label: "Length", value: String(format: "%.1fm", design.houseLength))
            dimensionChip(icon: "square.dashed", label: "Total", value: String(format: "%.0fm²", design.squareMeters))
            dimensionChip(icon: "ruler", label: "Lot Min", value: String(format: "%.1fm", design.lotWidth))
        }
    }

    private func dimensionChip(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AVIATheme.teal)
            Text(value)
                .font(.neueCorpMedium(13))
                .foregroundStyle(AVIATheme.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AVIATheme.teal.opacity(0.06))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var descriptionBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ABOUT THIS DESIGN")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)

            BentoCard(cornerRadius: 16) {
                Text(design.description)
                    .font(.neueSubheadline)
                    .foregroundStyle(AVIATheme.textSecondary)
                    .lineSpacing(5)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var floorplanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FLOOR PLAN")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)

            Button {
                showingFloorplan = true
            } label: {
                VStack(spacing: 0) {
                    Color(red: 0.22, green: 0.21, blue: 0.20)
                        .frame(height: 360)
                        .overlay {
                            AsyncImage(url: URL(string: design.floorplanImageURL)) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else if phase.error != nil {
                                    Image(systemName: "rectangle.split.2x2")
                                        .font(.system(size: 36))
                                        .foregroundStyle(.white.opacity(0.3))
                                } else {
                                    ProgressView()
                                        .tint(.white.opacity(0.5))
                                }
                            }
                            .allowsHitTesting(false)
                        }

                    HStack {
                        Text("\(design.name) Floor Plan")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 10, weight: .medium))
                            Text("Tap to expand")
                                .font(.neueCaption2)
                        }
                        .foregroundStyle(AVIATheme.teal)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AVIATheme.cardBackground)
                }
                .clipShape(.rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func compactStatChip(value: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AVIATheme.teal)
            Text(value)
                .font(.neueCorpMedium(16))
                .foregroundStyle(AVIATheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AVIATheme.surfaceElevated)
        .clipShape(.rect(cornerRadius: 10))
    }

    private func compactSpecRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
            Spacer()
            Text(value)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.textPrimary)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AVIATheme.surfaceBorder)
                .frame(height: 1)
        }
    }

    private var roomHighlightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ROOM HIGHLIGHTS")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)

            BentoCard(cornerRadius: 16) {
                VStack(spacing: 0) {
                    ForEach(Array(design.roomHighlights.enumerated()), id: \.offset) { index, highlight in
                        HStack(spacing: 12) {
                            Image(systemName: iconForHighlight(highlight))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AVIATheme.teal)
                                .frame(width: 28, height: 28)
                                .background(AVIATheme.teal.opacity(0.08))
                                .clipShape(Circle())
                            Text(highlight)
                                .font(.neueSubheadline)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)

                        if index < design.roomHighlights.count - 1 {
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

    private var specificationGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SPECIFICATIONS")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)

            BentoCard(cornerRadius: 16) {
                VStack(spacing: 0) {
                    specRow(label: "Total Area", value: String(format: "%.2f m²", design.squareMeters), icon: "square.dashed")
                    specDivider
                    specRow(label: "House Width", value: String(format: "%.2f m", design.houseWidth), icon: "arrow.left.and.right")
                    specDivider
                    specRow(label: "House Length", value: String(format: "%.2f m", design.houseLength), icon: "arrow.up.and.down")
                    specDivider
                    specRow(label: "Bedrooms", value: "\(design.bedrooms)", icon: "bed.double")
                    specDivider
                    specRow(label: "Bathrooms", value: "\(design.bathrooms)", icon: "shower")
                    specDivider
                    specRow(label: "Living Areas", value: "\(design.livingAreas)", icon: "sofa")
                    specDivider
                    specRow(label: "Garage", value: "\(design.garages)-car", icon: "car")
                    specDivider
                    specRow(label: "Storeys", value: design.storeys == 1 ? "Single" : "Double", icon: "building.2")
                    specDivider
                    specRow(label: "Min. Lot Width", value: String(format: "%.1f m", design.lotWidth), icon: "ruler")
                }
            }
        }
    }

    private func specRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.neueCorp(14))
                .foregroundStyle(AVIATheme.teal)
                .frame(width: 24)
            Text(label)
                .font(.neueSubheadline)
                .foregroundStyle(AVIATheme.textSecondary)
            Spacer()
            Text(value)
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var specDivider: some View {
        Rectangle()
            .fill(AVIATheme.surfaceBorder)
            .frame(height: 1)
            .padding(.leading, 52)
    }

    private var inclusionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STANDARD INCLUSIONS")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)

            BentoCard(cornerRadius: 16) {
                VStack(spacing: 0) {
                    ForEach(Array(design.inclusions.enumerated()), id: \.offset) { index, inclusion in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(AVIATheme.teal)
                            Text(inclusion)
                                .font(.neueSubheadline)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)

                        if index < design.inclusions.count - 1 {
                            Rectangle()
                                .fill(AVIATheme.surfaceBorder)
                                .frame(height: 1)
                                .padding(.leading, 42)
                        }
                    }
                }
            }
        }
    }

    private var featuresGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KEY FEATURES")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)

            HStack(spacing: 12) {
                featureCard(icon: "paintpalette.fill", title: "Multiple Facades", subtitle: "Choose your style")
                featureCard(icon: "slider.horizontal.3", title: "3 Spec Levels", subtitle: "Volos to Portobello")
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                featureCard(icon: "leaf.fill", title: "Energy Efficient", subtitle: "Sustainable design")
                featureCard(icon: "checkmark.shield.fill", title: "HIA Warranty", subtitle: "Full structural cover")
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func featureCard(icon: String, title: String, subtitle: String) -> some View {
        BentoCard(cornerRadius: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.neueCorpMedium(14))
                    .foregroundStyle(AVIATheme.teal)
                    .frame(width: 32, height: 32)
                    .background(AVIATheme.teal.opacity(0.1))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text(subtitle)
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
        }
    }

    private var ctaSection: some View {
        VStack(spacing: 10) {
            Button {
                showingEnquiryForm = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .font(.neueSubheadlineMedium)
                    Text("Enquire for Pricing")
                        .font(.neueSubheadlineMedium)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundStyle(.white)
                .background(AVIATheme.tealGradient)
                .clipShape(.rect(cornerRadius: 14))
            }
            .sheet(isPresented: $showingEnquiryForm) {
                DesignEnquiryFormView(designName: design.name)
            }

            if let phoneURL = URL(string: "tel:0756545123") {
                Link(destination: phoneURL) {
                    HStack(spacing: 8) {
                        Image(systemName: "phone.fill")
                            .font(.neueSubheadlineMedium)
                        Text("Call Us About This Design")
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

    private func iconForHighlight(_ highlight: String) -> String {
        let lower = highlight.lowercased()
        if lower.contains("master") { return "bed.double.fill" }
        if lower.contains("kitchen") || lower.contains("pantry") { return "fork.knife" }
        if lower.contains("theatre") || lower.contains("media") || lower.contains("lounge") || lower.contains("multi-purpose") { return "tv.fill" }
        if lower.contains("alfresco") || lower.contains("outdoor") { return "sun.max.fill" }
        if lower.contains("garage") { return "car.fill" }
        if lower.contains("laundry") || lower.contains("linen") { return "washer.fill" }
        if lower.contains("bedroom") { return "bed.double" }
        if lower.contains("rumpus") || lower.contains("sitting") || lower.contains("retreat") || lower.contains("activity") { return "figure.play" }
        if lower.contains("study") || lower.contains("office") { return "desktopcomputer" }
        if lower.contains("bathroom") || lower.contains("powder") { return "shower.fill" }
        if lower.contains("narrow") || lower.contains("compact") { return "arrow.left.and.right" }
        if lower.contains("living") { return "sofa.fill" }
        return "checkmark"
    }
}

struct FloorplanFullscreenView: View {
    let design: HomeDesign
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var loadedImage: Image?

    private let floorplanBackground = Color(red: 0.22, green: 0.21, blue: 0.20)

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    floorplanBackground.ignoresSafeArea()

                    AsyncImage(url: URL(string: design.floorplanImageURL)) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(16)
                                .scaleEffect(scale)
                                .offset(offset)
                                .gesture(
                                    MagnifyGesture()
                                        .onChanged { value in
                                            let newScale = lastScale * value.magnification
                                            scale = min(max(newScale, 1.0), 5.0)
                                        }
                                        .onEnded { _ in
                                            lastScale = scale
                                            if scale <= 1.0 {
                                                withAnimation(.spring(response: 0.3)) {
                                                    offset = .zero
                                                    lastOffset = .zero
                                                }
                                            }
                                        }
                                        .simultaneously(with:
                                            DragGesture()
                                                .onChanged { value in
                                                    offset = CGSize(
                                                        width: lastOffset.width + value.translation.width,
                                                        height: lastOffset.height + value.translation.height
                                                    )
                                                }
                                                .onEnded { _ in
                                                    lastOffset = offset
                                                }
                                        )
                                )
                                .onTapGesture(count: 2) {
                                    withAnimation(.spring(response: 0.35)) {
                                        if scale > 1.0 {
                                            scale = 1.0
                                            lastScale = 1.0
                                            offset = .zero
                                            lastOffset = .zero
                                        } else {
                                            scale = 2.5
                                            lastScale = 2.5
                                        }
                                    }
                                }
                                .frame(width: geo.size.width, height: geo.size.height)
                        } else if phase.error != nil {
                            VStack(spacing: 12) {
                                Image(systemName: "rectangle.split.2x2")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.white.opacity(0.3))
                                Text("Unable to load floorplan")
                                    .font(.neueSubheadline)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        } else {
                            ProgressView()
                                .tint(.white.opacity(0.6))
                                .scaleEffect(1.2)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(floorplanBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("\(design.name) Floorplan")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(.white)
                        Text(String(format: "%.0f m²", design.squareMeters))
                            .font(.neueCaption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
    }
}
