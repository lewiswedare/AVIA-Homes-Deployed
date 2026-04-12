import SwiftUI

struct FacadeDetailView: View {
    let facade: Facade
    @State private var selectedImageIndex: Int = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection

                VStack(spacing: 28) {
                    pricingSection
                    descriptionSection
                    featuresSection
                    gallerySection
                    enquirySection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(AVIATheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(facade.name)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
            }
        }
    }

    private var heroSection: some View {
        Color(AVIATheme.surfaceElevated)
            .frame(height: 380)
            .overlay {
                AsyncImage(url: URL(string: facade.heroImageURL)) { phase in
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
                HStack(alignment: .firstTextBaseline) {
                    Text(facade.name)
                        .font(.neueCorpMedium(34))
                        .foregroundStyle(AVIATheme.textPrimary)
                    Spacer()
                    if facade.storeys == 2 {
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
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .clipped()
    }

    private var pricingSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(facade.pricing.isIncluded ? "Included in All Packages" : "Upgrade Facade")
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Text(facade.pricing.isIncluded ? "This facade is available at no extra cost" : facade.pricing.displayText)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
            }

            Spacer(minLength: 0)

            Text(facade.pricing.isIncluded ? "Included" : facade.pricing.displayText)
                .font(.neueCorpMedium(14))
                .foregroundStyle(AVIATheme.timelessBrown)
        }
        .padding(14)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About This Facade")
                .font(.neueCorpMedium(20))
                .foregroundStyle(AVIATheme.textPrimary)

            Text(facade.description)
                .font(.neueSubheadline)
                .foregroundStyle(AVIATheme.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Facade Features")
                .font(.neueCorpMedium(20))
                .foregroundStyle(AVIATheme.textPrimary)

            VStack(spacing: 0) {
                ForEach(Array(facade.features.enumerated()), id: \.offset) { index, feature in
                    HStack(spacing: 14) {
                        Image(systemName: "checkmark")
                            .font(.neueCaption2Medium)
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(AVIATheme.teal)
                            .clipShape(Circle())

                        Text(feature)
                            .font(.neueSubheadline)
                            .foregroundStyle(AVIATheme.textPrimary)

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)

                    if index < facade.features.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .background(AVIATheme.cardBackground)
            .clipShape(.rect(cornerRadius: 16))
        }
    }

    private var gallerySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gallery")
                .font(.neueCorpMedium(20))
                .foregroundStyle(AVIATheme.textPrimary)

            TabView(selection: $selectedImageIndex) {
                ForEach(Array(facade.galleryImageURLs.enumerated()), id: \.offset) { index, imageURL in
                    Color(AVIATheme.surfaceElevated)
                        .frame(height: 220)
                        .overlay {
                            AsyncImage(url: URL(string: imageURL)) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else if phase.error != nil {
                                    Image(systemName: "photo")
                                        .font(.neueCorpMedium(28))
                                        .foregroundStyle(AVIATheme.teal.opacity(0.2))
                                } else {
                                    ProgressView()
                                }
                            }
                            .allowsHitTesting(false)
                        }
                        .clipShape(.rect(cornerRadius: 16))
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: 220)

            HStack {
                Spacer()
                Text("\(selectedImageIndex + 1) / \(facade.galleryImageURLs.count)")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
        }
    }

    private var enquirySection: some View {
        VStack(spacing: 12) {
            BentoCard(cornerRadius: 16) {
                HStack(spacing: 14) {
                    Image(systemName: "questionmark.bubble")
                        .font(.neueCorpMedium(22))
                        .foregroundStyle(AVIATheme.teal)
                        .frame(width: 48, height: 48)
                        .background(AVIATheme.teal.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Interested in this facade?")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("Speak to our team about adding the \(facade.name) facade to your build")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
            }

            if let phoneURL = URL(string: "tel:0756545123") {
                Link(destination: phoneURL) {
                    HStack(spacing: 8) {
                        Image(systemName: "phone.fill")
                            .font(.neueSubheadlineMedium)
                        Text("Contact Us")
                            .font(.neueSubheadlineMedium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundStyle(.white)
                    .background(AVIATheme.tealGradient)
                    .clipShape(.rect(cornerRadius: 14))
                }
            }
        }
    }
}
