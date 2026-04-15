import SwiftUI

struct PopularDesignsView: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryHeader

                if viewModel.popularDesigns.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(viewModel.popularDesigns.enumerated()), id: \.element.design.id) { index, entry in
                            popularDesignRow(rank: index + 1, design: entry.design, count: entry.count)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(AVIATheme.background)
        .navigationTitle("Popular Designs")
        .navigationBarTitleDisplayMode(.large)
    }

    private var summaryHeader: some View {
        BentoCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("SALES INTELLIGENCE")
                    .font(.neueCaption2Medium)
                    .kerning(0.5)
                    .foregroundStyle(AVIATheme.textTertiary)

                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("\(viewModel.allDesignFavourites.count)")
                            .font(.neueCorpMedium(28))
                            .foregroundStyle(AVIATheme.teal)
                        Text("Total Favourites")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(AVIATheme.surfaceBorder)
                        .frame(width: 1, height: 40)

                    VStack(spacing: 4) {
                        Text("\(uniqueUsersCount)")
                            .font(.neueCorpMedium(28))
                            .foregroundStyle(AVIATheme.teal)
                        Text("Users Engaged")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(AVIATheme.surfaceBorder)
                        .frame(width: 1, height: 40)

                    VStack(spacing: 4) {
                        Text("\(viewModel.popularDesigns.count)")
                            .font(.neueCorpMedium(28))
                            .foregroundStyle(AVIATheme.teal)
                        Text("Designs Liked")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
        }
    }

    private var uniqueUsersCount: Int {
        Set(viewModel.allDesignFavourites.map(\.userId)).count
    }

    private func popularDesignRow(rank: Int, design: HomeDesign, count: Int) -> some View {
        HStack(spacing: 14) {
            Text("#\(rank)")
                .font(.neueCorpMedium(16))
                .foregroundStyle(rank <= 3 ? AVIATheme.teal : AVIATheme.textTertiary)
                .frame(width: 32)

            AsyncImage(url: URL(string: design.imageURL)) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color(AVIATheme.surfaceElevated)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(design.name)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                HStack(spacing: 8) {
                    Label("\(design.bedrooms)", systemImage: "bed.double.fill")
                    Label("\(design.bathrooms)", systemImage: "shower.fill")
                    Text(String(format: "%.0fm\u{00B2}", design.squareMeters))
                }
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textSecondary)
            }

            Spacer()

            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                    Text("\(count)")
                        .font(.neueCorpMedium(16))
                        .foregroundStyle(AVIATheme.textPrimary)
                }
                Text(count == 1 ? "favourite" : "favourites")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
        }
        .padding(12)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            if rank <= 3 {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AVIATheme.teal.opacity(0.3), lineWidth: 1)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart.slash")
                .font(.system(size: 40))
                .foregroundStyle(AVIATheme.textTertiary)
            Text("No favourites yet")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textSecondary)
            Text("When users favourite designs, they'll appear here ranked by popularity.")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 40)
    }
}
