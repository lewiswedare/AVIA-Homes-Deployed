import SwiftUI

struct SpecRangeDetailView: View {
    let tier: SpecTier
    @State private var showingInclusions: Bool = false
    @State private var showCompareRanges: Bool = false
    @State private var selectedRoomIndex: Int = 0
    @State private var highlightDetail: SpecRangeHighlight?

    private var specData: SpecRangeData {
        CatalogDataManager.shared.specRangeData(for: tier)
    }

    private var roomGallery: [(name: String, imageURL: String)] {
        CatalogDataManager.shared.specRangeRoomImages(for: tier)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                VStack(spacing: 28) {
                    summarySection
                    compareRangesButton
                    highlightsSection
                    roomGallerySection
                    brandPartnersSection
                    downloadSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea(edges: [.top, .horizontal])
        .background(AVIATheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(tier.displayName)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
            }
        }
        .navigationDestination(isPresented: $showingInclusions) {
            SpecRangeInclusionsView(tier: tier)
        }
        .navigationDestination(isPresented: $showCompareRanges) {
            SpecRangeComparisonOverviewView()
        }
        .sheet(item: $highlightDetail) { highlight in
            SpecHighlightDetailSheet(tier: tier, highlight: highlight)
        }
    }

    @ViewBuilder
    private var brandPartnersSection: some View {
        let logos = specData.partnerLogos
        if !logos.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Trusted Brand Partners")
                    .font(.neueCorpMedium(20))
                    .foregroundStyle(AVIATheme.textPrimary)

                Text("Products from the brands you trust are included in the \(tier.displayName) range.")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 16) {
                    ForEach(logos, id: \.self) { logo in
                        Color(AVIATheme.surfaceElevated)
                            .frame(height: 64)
                            .overlay {
                                AsyncImage(url: URL(string: logo.imageURL)) { phase in
                                    if let image = phase.image {
                                        image.resizable().aspectRatio(contentMode: .fit).padding(8)
                                    } else if phase.error != nil {
                                        Image(systemName: "building.2.crop.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(AVIATheme.timelessBrown.opacity(0.5))
                                    } else {
                                        ProgressView().controlSize(.small)
                                    }
                                }
                                .allowsHitTesting(false)
                            }
                            .clipShape(.rect(cornerRadius: 8))
                            .accessibilityLabel(logo.name)
                    }
                }

                Text("Logos shown are representative. Actual branded products included vary by plan and availability.")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
        }
    }

    private var heroSection: some View {
        Color(AVIATheme.surfaceElevated)
            .frame(height: 380)
            .overlay {
                AsyncImage(url: URL(string: specData.heroImageURL)) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    }
                }
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: AVIATheme.background.opacity(0.3), location: 0.35),
                        .init(color: AVIATheme.background.opacity(0.7), location: 0.6),
                        .init(color: AVIATheme.background, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tier.tagline.uppercased())
                        .font(.neueCorpMedium(10))
                        .kerning(1.2)
                        .foregroundStyle(AVIATheme.textSecondary)
                    Text(tier.displayName)
                        .font(.neueCorpMedium(34))
                        .foregroundStyle(AVIATheme.textPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .clipped()
    }

    private var compareRangesButton: some View {
        Button {
            showCompareRanges = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.split.3x1.fill")
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .frame(width: 40, height: 40)
                    .background(AVIATheme.timelessBrown.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Compare All Spec Ranges")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Side-by-side comparison with images")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(14)
            .background(AVIATheme.cardBackground)
            .clipShape(.rect(cornerRadius: 13))
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About This Range")
                .font(.neueCorpMedium(20))
                .foregroundStyle(AVIATheme.textPrimary)

            Text(specData.summary)
                .font(.neueSubheadline)
                .foregroundStyle(AVIATheme.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var highlightsSectionTitle: String {
        switch tier {
        case .volos:
            return "Range Highlights"
        case .messina:
            return "Key Upgrades from Volos"
        case .portobello:
            return "Key Upgrades from Messina"
        }
    }

    @ViewBuilder
    private func highlightIcon(for highlight: SpecRangeHighlight) -> some View {
        if let urlString = highlight.iconImageURL, !urlString.isEmpty, let url = URL(string: urlString) {
            Color(AVIATheme.timelessBrown.opacity(0.1))
                .frame(width: 36, height: 36)
                .overlay {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: highlight.icon)
                                .font(.neueCorpMedium(14))
                                .foregroundStyle(AVIATheme.timelessBrown)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .clipShape(Circle())
        } else {
            Image(systemName: highlight.icon)
                .font(.neueCorpMedium(14))
                .foregroundStyle(AVIATheme.timelessBrown)
                .frame(width: 36, height: 36)
                .background(AVIATheme.timelessBrown.opacity(0.1))
                .clipShape(Circle())
        }
    }

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(highlightsSectionTitle)
                .font(.neueCorpMedium(20))
                .foregroundStyle(AVIATheme.textPrimary)

            VStack(spacing: 0) {
                ForEach(Array(specData.highlights.enumerated()), id: \.offset) { index, highlight in
                    Button {
                        highlightDetail = highlight
                    } label: {
                        HStack(alignment: .top, spacing: 14) {
                            highlightIcon(for: highlight)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(highlight.title)
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text(highlight.subtitle)
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textTertiary)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "chevron.right")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable(.subtle))

                    if index < specData.highlights.count - 1 {
                        Divider()
                            .padding(.leading, 64)
                    }
                }
            }
            .background(AVIATheme.cardBackground)
            .clipShape(.rect(cornerRadius: 13))
        }
    }

    private var roomGallerySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Room Gallery")
                .font(.neueCorpMedium(20))
                .foregroundStyle(AVIATheme.textPrimary)

            TabView(selection: $selectedRoomIndex) {
                ForEach(Array(roomGallery.enumerated()), id: \.offset) { index, room in
                    VStack(spacing: 0) {
                        Color(AVIATheme.surfaceElevated)
                            .frame(height: 220)
                            .overlay {
                                AsyncImage(url: URL(string: room.imageURL)) { phase in
                                    if let image = phase.image {
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } else if phase.error != nil {
                                        Image(systemName: "photo")
                                            .font(.neueCorpMedium(28))
                                            .foregroundStyle(AVIATheme.timelessBrown.opacity(0.2))
                                    } else {
                                        ProgressView()
                                    }
                                }
                                .allowsHitTesting(false)
                            }
                            .clipShape(.rect(cornerRadii: .init(topLeading: 16, topTrailing: 16)))

                        HStack {
                            Text(room.name)
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Spacer()
                            Text("\(index + 1) / \(roomGallery.count)")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .background(AVIATheme.cardBackground)
                    .clipShape(.rect(cornerRadius: 13))
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: 274)
        }
    }

    private var inclusionsPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inclusions Preview")
                .font(.neueCorpMedium(20))
                .foregroundStyle(AVIATheme.textPrimary)

            VStack(spacing: 0) {
                ForEach(Array(CatalogDataManager.shared.allSpecCategories.prefix(4).enumerated()), id: \.element.id) { index, category in
                    HStack(spacing: 12) {
                        Image(systemName: category.icon)
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.timelessBrown)
                            .frame(width: 32, height: 32)
                            .background(AVIATheme.timelessBrown.opacity(0.08))
                            .clipShape(.rect(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.name)
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Text("\(category.items.count) items included")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)

                    if index < 3 {
                        Divider()
                            .padding(.leading, 58)
                    }
                }
            }
            .background(AVIATheme.cardBackground)
            .clipShape(.rect(cornerRadius: 13))

            Button {
                showingInclusions = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.neueSubheadlineMedium)
                    Text("View All Inclusions")
                        .font(.neueSubheadlineMedium)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(AVIATheme.aviaWhite)
                .background(AVIATheme.primaryGradient)
                .clipShape(.rect(cornerRadius: 11))
            }
        }
    }

    @ViewBuilder
    private var downloadSection: some View {
        if let pdfString = specData.pdfURL, !pdfString.isEmpty, let pdfURL = pdfString.urlWithConfiguredSupabaseHost {
            let previewURL = (specData.pdfPreviewImageURL).flatMap { $0.isEmpty ? nil : $0.urlWithConfiguredSupabaseHost }
            Color(AVIATheme.surfaceElevated)
                .frame(height: 420)
                .overlay {
                    if let previewURL {
                        AsyncImage(url: previewURL) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Image(systemName: "doc.richtext")
                                    .font(.system(size: 56))
                                    .foregroundStyle(AVIATheme.timelessBrown.opacity(0.4))
                            }
                        }
                        .allowsHitTesting(false)
                    } else {
                        Image(systemName: "doc.richtext")
                            .font(.system(size: 56))
                            .foregroundStyle(AVIATheme.timelessBrown.opacity(0.4))
                    }
                }
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.black.opacity(0), .black.opacity(0.35), .black.opacity(0.78)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 240)
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    Text("SPEC RANGE PDF")
                        .font(.neueCaption)
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .environment(\.colorScheme, .dark)
                        .padding(16)
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(tier.displayName)")
                                .font(.neueCorpMedium(28))
                                .foregroundStyle(.white)
                            Text("Download the full specification document")
                                .font(.neueSubheadline)
                                .foregroundStyle(.white.opacity(0.85))
                        }

                        Link(destination: pdfURL) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.doc.fill")
                                    .font(.neueSubheadlineMedium)
                                Text("Download PDF")
                                    .font(.neueSubheadlineMedium)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .background(AVIATheme.primaryGradient)
                            .clipShape(.rect(cornerRadius: 11))
                        }
                    }
                    .padding(20)
                }
                .clipShape(.rect(cornerRadius: 16))
        }
    }
}
