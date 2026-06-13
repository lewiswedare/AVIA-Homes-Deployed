import SwiftUI

/// Detail sheet for a single fitting/fixture within a spec range. Shows the
/// hero image (zoomable), inclusion status, brand/model/SKU specs, description,
/// and the available colour/finish variants — all read-only.
struct SpecRangeFittingDetailSheet: View {
    let tier: SpecTier
    let fitting: RangeFitting
    @Environment(\.dismiss) private var dismiss
    @State private var previewImageURL: IdentifiedURL?

    private var product: SpecProductRow { fitting.product }
    private var colours: [SpecProductColourRow] {
        CatalogDataManager.shared.productColours(for: product.id)
    }
    private var heroImageURL: String? {
        CatalogDataManager.shared.displayImageURL(forProduct: product)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroImage

                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let description = product.description, !description.isEmpty {
                        Text(description)
                            .font(.neueSubheadline)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    specsCard
                    if !colours.isEmpty {
                        coloursSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(AVIATheme.background)
        .ignoresSafeArea(edges: [.top, .horizontal])
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.black.opacity(0.45), in: Circle())
            }
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
        .presentationDetents([.large])
        .presentationContentInteraction(.scrolls)
        .fullScreenCover(item: $previewImageURL) { item in
            ZoomableImageViewer(urlString: item.urlString)
        }
    }

    private var heroImage: some View {
        Color(AVIATheme.surfaceElevated)
            .frame(height: 320)
            .overlay {
                if let urlStr = heroImageURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else if phase.error != nil {
                            placeholderIcon
                        } else {
                            ProgressView()
                        }
                    }
                    .allowsHitTesting(false)
                } else {
                    placeholderIcon
                }
            }
            .overlay(alignment: .topTrailing) {
                if let urlStr = heroImageURL, !urlStr.isEmpty {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.neueCorpMedium(11))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.45), in: Circle())
                        .padding(12)
                        .padding(.trailing, 44)
                }
            }
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture {
                if let urlStr = heroImageURL, !urlStr.isEmpty {
                    AVIAHaptic.lightTap.trigger()
                    previewImageURL = IdentifiedURL(urlString: urlStr)
                }
            }
    }

    private var placeholderIcon: some View {
        Image(systemName: "shippingbox")
            .font(.system(size: 44))
            .foregroundStyle(AVIATheme.timelessBrown.opacity(0.25))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(fitting.categoryName.uppercased())
                    .font(.neueCorpMedium(9))
                    .kerning(1.0)
                    .foregroundStyle(AVIATheme.timelessBrown)
                Text("·")
                    .font(.neueCorpMedium(9))
                    .foregroundStyle(AVIATheme.textTertiary)
                Text("\(tier.displayName.uppercased()) RANGE")
                    .font(.neueCorpMedium(9))
                    .kerning(1.0)
                    .foregroundStyle(AVIATheme.textTertiary)
            }

            Text(product.name)
                .font(.neueCorpMedium(24))
                .foregroundStyle(AVIATheme.textPrimary)

            inclusionBadge
        }
    }

    @ViewBuilder
    private var inclusionBadge: some View {
        switch fitting.inclusion {
        case .included:
            Label("Included in \(tier.displayName)", systemImage: "checkmark.seal.fill")
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.heritageBlue)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(AVIATheme.heritageBlue.opacity(0.12), in: Capsule())
        case .upgrade:
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill")
                Text(fitting.upgradeCost > 0 ? "Upgrade · +\(AVIATheme.formatCost(fitting.upgradeCost))" : "Available as Upgrade")
            }
            .font(.neueCaptionMedium)
            .foregroundStyle(AVIATheme.timelessBrown)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(AVIATheme.timelessBrown.opacity(0.12), in: Capsule())
        case .unavailable:
            EmptyView()
        }
    }

    @ViewBuilder
    private var specsCard: some View {
        let rows: [(String, String)] = [
            ("Brand", product.brand),
            ("Model", product.model),
            ("Product Code", product.sku),
            ("Dimensions", product.dimensions)
        ].compactMap { label, value in
            guard let value, !value.isEmpty else { return nil }
            return (label, value)
        }
        if !rows.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(alignment: .top) {
                        Text(row.0)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textTertiary)
                        Spacer(minLength: 16)
                        Text(row.1)
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.vertical, 11)
                    .padding(.horizontal, 14)

                    if index < rows.count - 1 {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .background(AVIATheme.cardBackground)
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    private var coloursSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(colours.count == 1 ? "Finish" : "Available Finishes")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)

            LazyVGrid(columns: AdaptiveLayout.swatchColumns(spacing: 10), spacing: 12) {
                ForEach(colours) { colour in
                    colourSwatch(colour)
                }
            }
        }
    }

    private func colourSwatch(_ colour: SpecProductColourRow) -> some View {
        let imageURL = colour.image_url
        let hasImage = !(imageURL ?? "").isEmpty
        return VStack(spacing: 6) {
            Group {
                if hasImage, let urlStr = imageURL, let url = URL(string: urlStr) {
                    Color(AVIATheme.surfaceElevated)
                        .frame(width: 52, height: 52)
                        .overlay {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Image(systemName: "photo")
                                        .font(.neueCorp(12))
                                        .foregroundStyle(AVIATheme.textTertiary)
                                }
                            }
                            .allowsHitTesting(false)
                        }
                        .clipShape(Circle())
                        .overlay { Circle().stroke(AVIATheme.surfaceBorder, lineWidth: 1) }
                } else {
                    Circle()
                        .fill(Color(hex: colour.hex ?? "CCCCCC"))
                        .frame(width: 52, height: 52)
                        .overlay { Circle().stroke(AVIATheme.surfaceBorder, lineWidth: 1) }
                }
            }
            Text(colour.name)
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if (colour.extra_cost ?? 0) > 0 {
                Text("+\(AVIATheme.formatCost(colour.extra_cost ?? 0))")
                    .font(.neueCorpMedium(8))
                    .foregroundStyle(AVIATheme.timelessBrown)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            if hasImage, let urlStr = imageURL {
                AVIAHaptic.lightTap.trigger()
                previewImageURL = IdentifiedURL(urlString: urlStr)
            }
        }
    }
}
