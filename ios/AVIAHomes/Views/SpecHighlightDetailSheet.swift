import SwiftUI

struct SpecHighlightDetailSheet: View {
    let tier: SpecTier
    let highlight: SpecRangeHighlight
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroImage

                VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            iconView

                            VStack(alignment: .leading, spacing: 2) {
                                Text(tier.displayName.uppercased())
                                    .font(.neueCorpMedium(9))
                                    .kerning(1.0)
                                    .foregroundStyle(AVIATheme.timelessBrown)
                                Text(highlight.title)
                                    .font(.neueCorpMedium(22))
                                    .foregroundStyle(AVIATheme.textPrimary)
                            }
                        }

                        Text(highlight.subtitle)
                            .font(.neueSubheadline)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .lineSpacing(4)

                        Divider()
                            .padding(.vertical, 4)

                        Text("Why it matters")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)

                        Text(extendedDescription)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .lineSpacing(4)

                        Text("Included in")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                            .padding(.top, 4)

                    HStack(spacing: 8) {
                        Text(tier.displayName)
                            .font(.neueCorpMedium(10))
                            .kerning(0.8)
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(AVIATheme.timelessBrown)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(AVIATheme.background)
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().fill(Color.black.opacity(0.25)))
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
        .presentationDetents([.large])
        .presentationContentInteraction(.scrolls)
    }

    private var heroImage: some View {
        Color(AVIATheme.surfaceElevated)
            .frame(height: 320)
            .overlay {
                AsyncImage(url: URL(string: imageURL)) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: highlight.icon)
                            .font(.system(size: 48))
                            .foregroundStyle(AVIATheme.timelessBrown.opacity(0.25))
                    }
                }
                .allowsHitTesting(false)
            }
            .clipped()
    }

    @ViewBuilder
    private var iconView: some View {
        if let urlString = highlight.iconImageURL, !urlString.isEmpty, let url = URL(string: urlString) {
            Color(AVIATheme.timelessBrown.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: highlight.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AVIATheme.timelessBrown)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .clipShape(Circle())
        } else {
            Image(systemName: highlight.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AVIATheme.timelessBrown)
                .frame(width: 44, height: 44)
                .background(AVIATheme.timelessBrown.opacity(0.12))
                .clipShape(Circle())
        }
    }

    private var imageURL: String {
        if let detail = highlight.detailImageURL, !detail.isEmpty {
            return detail
        }
        let rooms = CatalogDataManager.shared.specRangeRoomImages(for: tier)
        return rooms.first?.imageURL ?? CatalogDataManager.shared.specRangeData(for: tier).heroImageURL
    }

    private var extendedDescription: String {
        "\(highlight.title) is one of the defining features of the \(tier.displayName) spec range. \(highlight.subtitle). This upgrade has been carefully chosen to deliver long-lasting quality, refined aesthetics and the day-to-day performance AVIA homeowners expect."
    }
}

extension SpecRangeHighlight: Identifiable {
    public var id: String { title }
}
